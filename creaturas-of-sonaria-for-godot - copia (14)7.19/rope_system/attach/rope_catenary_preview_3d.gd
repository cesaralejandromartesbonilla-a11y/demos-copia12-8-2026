class_name RopeCatenaryPreview3D
extends Node3D
## Herramienta de prueba visual para RopeCatenarySolver — DESCARTABLE, no
## es parte del sistema de cuerdas en sí. Sirve solo para ver la curva
## en el viewport y compararla a ojo contra una cuerda real mientras
## probamos el solver aislado (Paso 1 de Fase 7/8, "se prueba por
## separado" antes de tocar Rope3D).
##
## Uso más simple (cero configuración): poné este nodo en cualquier
## escena y corré — dibuja una curva desde su propia posición hasta un
## punto fijo relativo (fallback_offset), sin necesitar nada más.
##
## Uso comparativo: asignale start_point_path/end_point_path a los dos
## extremos de una Rope3D real (por ejemplo, dos StaticAnchor visibles o
## los propios nodos que usás como anclas), poné el mismo arc_length que
## tenga esa cuerda, y las dos formas deberían verse prácticamente
## iguales si el solver está bien.

@export var start_point_path: NodePath # opcional; vacío = usa este mismo nodo como punto 1
@export var end_point_path: NodePath # opcional; vacío = usa start + fallback_offset como punto 2
@export var fallback_offset: Vector3 = Vector3(5, -2, 0) # usado solo si end_point_path está vacío
@export var arc_length: float = 8.0
@export var sample_count: int = 30
@export var debug_color: Color = Color(0.2, 0.8, 0.9)
@export var auto_update: bool = true # si true, recalcula cada frame — movés los puntos en el editor/juego y la curva reacciona en vivo

var _solver: RopeCatenarySolver
var _immediate_mesh: ImmediateMesh
var _mesh_instance: MeshInstance3D

func _ready() -> void:
	_solver = RopeCatenarySolver.new()
	_immediate_mesh = ImmediateMesh.new()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _immediate_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = debug_color
	_mesh_instance.material_override = mat
	add_child(_mesh_instance)
	_update_curve()

## _process (no _physics_process): esto es puramente visual, no depende
## de física ni necesita el tick fijo — más liviano y más fluido para
## algo que solo se dibuja.
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

	_solver.solve(p1, p2, arc_length)

	_immediate_mesh.clear_surfaces()
	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(sample_count + 1):
		var t: float = float(i) / float(sample_count)
		var world_p: Vector3 = _solver.evaluate(t)
		_immediate_mesh.surface_add_vertex(to_local(world_p))
	_immediate_mesh.surface_end()

## Por si querés leer el resultado por código en vez de solo mirarlo
## (por ejemplo, para comparar numéricamente contra una Rope3D real).
func get_solver() -> RopeCatenarySolver:
	return _solver
