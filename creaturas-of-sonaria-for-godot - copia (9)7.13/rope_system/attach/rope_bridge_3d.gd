class_name RopeBridge3D
extends Node3D
## Genera un puente colgante completo. Dos formas de usarlo:
##   A) Ya tenés un Rope3D armado como cable principal: apuntá
##      root_rope_path ahí, se usa tal cual.
##   B) No tenés nada armado todavía: apuntá start_anchor_path y
##      end_anchor_path a dos nodos cualquiera (pueden ser dos
##      RopeAttachMarker3D, dos torres, lo que sea con posición) y el
##      cable raíz se genera solo entre ellos.
##
## En cualquiera de los dos casos, genera strut_count tirantes
## distribuidos a lo largo del cable raíz (vía RopeAttachedAnchor). Cada
## tirante puede ir "suelto" (largo fijo hacia abajo) o "conectado al
## suelo" (raycast hacia abajo hasta la primera superficie que encuentre)
## — configurable global o individualmente por tirante.
##
## FASE 6, versión simple y unidireccional: el cable raíz nunca se entera
## de que sus tirantes existen, no le devuelven fuerza.

@export_group("Cable raíz")
@export var root_rope_path: NodePath # si ya tenés un Rope3D armado, apuntá acá y se usa tal cual
@export var start_anchor_path: NodePath # si root_rope_path está vacío, el cable raíz se genera entre este...
@export var end_anchor_path: NodePath # ...y este nodo (puede ser un RopeAttachMarker3D o cualquier Node3D)
@export var root_rope_scene: PackedScene # opcional, para el cable raíz auto-generado (caso B)

@export_group("Tirantes")
@export var strut_count: int = 6
@export var strut_length: float = 2.0 # largo fijo para tirantes "sueltos"
@export var margin_fraction: float = 0.08 # no generar tirantes pegados a las puntas del cable raíz
@export var strut_scene: PackedScene # opcional, para clonar configuración de un Rope3D de referencia

@export_group("Conexión al suelo")
@export var ground_connected_by_default: bool = false # true = todos buscan el suelo por raycast; false = todos "sueltos" (largo fijo)
@export var ground_collision_mask: int = 1
@export var max_ground_search_distance: float = 50.0
@export var strut_ground_override: Array[bool] = [] # opcional: personalizar tirante por tirante. Índice i controla el tirante i; los que falten usan ground_connected_by_default.

var _root_rope: Rope3D
var _struts: Array = [] # Array de Rope3D (sin tipar Array[Rope3D] a propósito, ver nota abajo)
var _generated: bool = false

func _ready() -> void:
	if root_rope_path != NodePath():
		var found: Node = get_node_or_null(root_rope_path)
		if found is Rope3D:
			_root_rope = found
		else:
			push_warning("RopeBridge3D: root_rope_path no apunta a un Rope3D válido.")
	elif start_anchor_path != NodePath() and end_anchor_path != NodePath():
		_generate_root_rope()
	else:
		push_warning("RopeBridge3D: asigná root_rope_path, o start_anchor_path + end_anchor_path.")

func _generate_root_rope() -> void:
	var start_node: Node = get_node_or_null(start_anchor_path)
	var end_node: Node = get_node_or_null(end_anchor_path)
	if start_node == null or end_node == null:
		push_warning("RopeBridge3D: start_anchor_path/end_anchor_path no resolvieron a nodos válidos.")
		return
	if not (start_node is Node3D) or not (end_node is Node3D):
		push_warning("RopeBridge3D: las anclas del cable raíz tienen que ser Node3D (o algo que herede de él, como RopeAttachMarker3D).")
		return

	var rope: Rope3D
	if root_rope_scene != null:
		var instanced_root: Node = root_rope_scene.instantiate()
		rope = instanced_root as Rope3D
		if rope == null:
			push_warning("RopeBridge3D: root_rope_scene no instancia un Rope3D; usando uno básico.")
			rope = Rope3D.new()
	else:
		rope = Rope3D.new()

	get_tree().current_scene.add_child(rope)
	rope.set_anchor_start(NodeAnchor.new(start_node as Node3D))
	rope.set_anchor_end(NodeAnchor.new(end_node as Node3D))
	_root_rope = rope

## Esperamos a que el cable raíz haya corrido su primera simulación antes
## de generar los tirantes (aplica tanto al caso A como al B) — si
## generáramos antes, _initialize_particles() del padre todavía no corrió
## y todos los tirantes nacerían apilados en el origen.
func _physics_process(_delta: float) -> void:
	if _generated or _root_rope == null:
		return
	if _root_rope.get_points_global().size() < 2:
		return
	_generate_struts()
	_generated = true

func _generate_struts() -> void:
	var divisions: int = max(strut_count - 1, 1)
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	for i in range(strut_count):
		var t: float = margin_fraction + (1.0 - margin_fraction * 2.0) * (float(i) / float(divisions))
		var top_anchor: RopeAttachedAnchor = RopeAttachedAnchor.new(_root_rope, t)
		var top_pos: Vector3 = top_anchor.get_anchor_position()

		var use_ground: bool = ground_connected_by_default
		if i < strut_ground_override.size():
			use_ground = strut_ground_override[i]

		var bottom_anchor: RopeAnchor = _make_bottom_anchor(top_pos, use_ground, space_state)
		if bottom_anchor == null:
			continue # modo "conectado al suelo" sin superficie encontrada: se saltea este tirante

		var strut: Rope3D
		if strut_scene != null:
			var instanced_strut: Node = strut_scene.instantiate()
			strut = instanced_strut as Rope3D
			if strut == null:
				push_warning("RopeBridge3D: strut_scene no instancia un Rope3D; usando uno básico.")
				strut = Rope3D.new()
		else:
			strut = Rope3D.new()

		get_tree().current_scene.add_child(strut)
		strut.set_anchor_start(top_anchor)
		strut.set_anchor_end(bottom_anchor)
		_struts.append(strut)

## Devuelve null si el modo es "conectado al suelo" pero el raycast no
## encontró nada dentro de max_ground_search_distance.
func _make_bottom_anchor(top_pos: Vector3, use_ground: bool, space_state: PhysicsDirectSpaceState3D) -> RopeAnchor:
	if not use_ground:
		return StaticAnchor.new(top_pos + Vector3.DOWN * strut_length)

	var ray_end: Vector3 = top_pos + Vector3.DOWN * max_ground_search_distance
	var query := PhysicsRayQueryParameters3D.create(top_pos, ray_end)
	query.collision_mask = ground_collision_mask
	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		push_warning("RopeBridge3D: un tirante en modo 'conectado al suelo' no encontró superficie, se saltea.")
		return null

	var hit_point: Vector3 = result.get("position", top_pos)
	return StaticAnchor.new(hit_point)

## Para ajustar algo después de generados.
func get_struts() -> Array:
	return _struts
