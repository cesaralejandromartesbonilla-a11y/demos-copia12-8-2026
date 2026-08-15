class_name RopeCatenaryPreview3D
extends Node3D
## Herramienta de prueba visual para RopeCatenarySolver y
## RopeRestCaseClassifier — DESCARTABLE, no es parte del sistema de
## cuerdas en sí. Sirve para ver la curva en el viewport, compararla a
## ojo contra una cuerda real, y ahora también ver de un vistazo qué caso
## detectó el clasificador (Paso 2 de Fase 7/8).
##
## Uso más simple (cero configuración): poné este nodo en cualquier
## escena y corré — dibuja una curva desde su propia posición hasta un
## punto fijo relativo (fallback_offset).
##
## Colores:
##   AZUL (straight_color)         = el solver dio "recto" (poca holgura relativa)
##   CELESTE (hanging_color)       = el solver dio una curva real, y no toca nada
##   NARANJA (excess_slack_color)  = la curva ideal SÍ toca algo — holgura de sobra apoyada
##
## Cada vez que el estado CAMBIA (no cada frame, para no saturar la
## consola), imprime los números exactos: largo de arco pedido,
## distancia recta entre los puntos, y la relación entre ambos — son los
## datos concretos que necesitamos si algo se clasifica distinto a lo
## esperado.

@export var start_point_path: NodePath
@export var end_point_path: NodePath
@export var fallback_offset: Vector3 = Vector3(5, -2, 0)
@export var arc_length: float = 8.0
@export var sample_count: int = 30
@export var auto_update: bool = true

@export_group("Clasificador (Paso 2)")
@export var use_rest_classifier: bool = true # si true, usa RopeRestCaseClassifier en vez de solve() directo
@export var classifier_collision_mask: int = 1

@export_group("Colores por estado")
@export var straight_color: Color = Color(0.5, 0.5, 0.9)
@export var hanging_color: Color = Color(0.2, 0.8, 0.9)
@export var excess_slack_color: Color = Color(1.0, 0.5, 0.1)

var _solver: RopeCatenarySolver
var _classifier: RopeRestCaseClassifier
var _immediate_mesh: ImmediateMesh
var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D
var _last_logged_state: String = ""

func _ready() -> void:
	_solver = RopeCatenarySolver.new()
	_classifier = RopeRestCaseClassifier.new()
	_immediate_mesh = ImmediateMesh.new()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _immediate_mesh
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh_instance.material_override = _material
	add_child(_mesh_instance)
	_update_curve()

func _process(_delta: float) -> void:
	if auto_update:
		_update_curve()

func _get_point(path: NodePath, fallback: Vector3) -> Vector3:
	if path != NodePath():
		var n: Node = get_node_or_null(path)
		if n is Node3D:
			return (n as Node3D).global_position
	return fallback

func _update_curve() -> void:
	var p1: Vector3 = _get_point(start_point_path, global_position)
	var p2: Vector3 = _get_point(end_point_path, global_position + fallback_offset)

	var state_label: String
	var current_color: Color

	if use_rest_classifier:
		_classifier.collision_mask = classifier_collision_mask
		var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var rest_case: RopeRestCaseClassifier.RestCase = _classifier.classify(p1, p2, arc_length, space_state)
		_solver = _classifier.get_solver()

		if rest_case == RopeRestCaseClassifier.RestCase.EXCESS_SLACK_ON_SURFACE:
			current_color = excess_slack_color
			state_label = "EXCESS_SLACK_ON_SURFACE (holgura de sobra apoyada)"
		elif _solver.is_straight():
			current_color = straight_color
			state_label = "HANGING_OR_TAUT - recto"
		else:
			current_color = hanging_color
			state_label = "HANGING_OR_TAUT - curva real"
	else:
		_solver.solve(p1, p2, arc_length)
		if _solver.is_straight():
			current_color = straight_color
			state_label = "recto (solver directo, sin clasificador)"
		else:
			current_color = hanging_color
			state_label = "curva (solver directo, sin clasificador)"

	_material.albedo_color = current_color

	if state_label != _last_logged_state:
		var straight_dist: float = p1.distance_to(p2)
		var requested_ratio: float = arc_length / straight_dist if straight_dist > 0.001 else -1.0
		var was_clamped: bool = arc_length < straight_dist
		var clamp_note: String = "  [AVISO: arc_length pedido < distancia recta — se usó la distancia recta como largo real, la cuerda está 'estirada' más de lo posible]" if was_clamped else ""
		print("[RopeCatenaryPreview3D] estado=%s | arc_length_pedido=%.4f | dist_recta=%.4f | ratio_pedido=%.5f%s" % [
			state_label, arc_length, straight_dist, requested_ratio, clamp_note
		])
		_last_logged_state = state_label

	_immediate_mesh.clear_surfaces()
	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(sample_count + 1):
		var t: float = float(i) / float(sample_count)
		var world_p: Vector3 = _solver.evaluate(t)
		_immediate_mesh.surface_add_vertex(to_local(world_p))
	_immediate_mesh.surface_end()

func get_solver() -> RopeCatenarySolver:
	return _solver

func get_classifier() -> RopeRestCaseClassifier:
	return _classifier
