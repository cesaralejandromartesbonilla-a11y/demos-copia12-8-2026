class_name Rope3D
extends Node3D
## FASE 4 COMPLETA (inserción + liberación de wrap-anchors), sobre la
## base de Fase 3 dividida en componentes. Orquestador DELGADO: dueño de
## las anclas, dueño del orden de ejecución por frame, expone `points`
## para el render. La lógica real vive en:
##   - RopeState: los datos (posiciones, pinneo, largos de reposo)
##   - RopeVerletSolver: integración + constraints
##   - RopeWorldCollision: todo lo que habla con PhysicsDirectSpaceState3D
##   - RopeEdgeWrapping: inserción Y liberación de wrap-anchors
##
## El fix del reinicio al cambiar de ancla sigue pendiente: agarrar la
## cuerda todavía borra los wrap-anchors acumulados (set_anchor_start/end
## resetean _initialized). Con liberación ya implementada el impacto es
## menor que antes (no había forma de que se acumularan huérfanos para
## empezar), pero sigue siendo la próxima mejora obvia para Fase 4.

@export_group("Segmentación")
@export var auto_segment_scaling: bool = true: # si es true, segment_count se recalcula según el largo real
	set(value):
		auto_segment_scaling = value
		_initialized = false
@export var segments_per_meter: float = 4.0 # densidad: más = menos tunneling en geometría compleja, más costo
@export var min_segments: int = 4
@export var max_segments: int = 64

@export var segment_count: int = 10:
	set(value):
		segment_count = max(1, value)
		_initialized = false

@export var gravity: Vector3 = Vector3(0, -9.8, 0)
@export var damping: float = 0.98 # 1.0 = sin pérdida de energía, más bajo = se frena más rápido
@export var constraint_iterations: int = 8 # más iteraciones = cuerda más "rígida" y estable
@export var rope_length: float = 0.0: # 0 = usar la distancia inicial entre anclas + slack_factor. Editable en vivo: cambiarlo recalcula la cuerda.
	set(value):
		rope_length = max(0.0, value)
		_initialized = false
@export var slack_factor: float = 1.25: # solo aplica cuando rope_length == 0. 1.0 = sin holgura (rayo de luz)
	set(value):
		slack_factor = max(0.01, value) # evita segmentos de largo negativo/cero ("agujero negro")

@export var anchor_start_node_path: NodePath
@export var anchor_end_node_path: NodePath

@export_group("Colisión contra el mundo (Fase 3)")
@export var enable_world_collision: bool = true
@export var collision_mask: int = 1
@export var rope_radius: float = 0.03 # idealmente igual al radius del RopeMeshRenderer3D
@export var exclude_anchor_bodies: bool = true # evita que la cuerda choque contra el cuerpo del que cuelga
@export var collision_reaction_strength: float = 1.0 # cuánto empuja la cuerda a los RigidBody3D que toca (0 = no reacciona)
@export var enable_ccd: bool = true # colisión continua: evita traspasos a alta velocidad (movimiento brusco, "fuerza infinita")

@export_group("Envolvimiento en aristas (Fase 4 completa: inserción + liberación)")
@export var enable_edge_wrapping: bool = true # reactivado: con liberación (Paso 2) ya no acumula anclas huérfanas
@export var wrap_insert_frames: int = 12 # frames consecutivos de contacto sostenido antes de insertar un ancla real
@export var max_wrap_anchors: int = 8 # tope de anclas temporales simultáneas por cuerda
@export var min_wrap_spacing: float = 0.05 # distancia mínima a un wrap-anchor vecino para permitir insertar otro
@export var min_bend_distance: float = 0.02 # cuánto tiene que desviarse el contacto de la línea recta del segmento para contar como doblez real (evita pinnear tramos apoyados planos)
@export var release_check_interval: int = 15 # cada cuántos frames se intenta liberar anclas existentes

@export_group("Debug")
@export var debug_draw: bool = true
@export var debug_color: Color = Color(0.9, 0.7, 0.2)
@export var debug_draw_wrap_anchors: bool = true # marca cada wrap-anchor con una crucecita en el dibujo de debug, para distinguirlo de una partícula libre a simple vista
@export var debug_wrap_anchor_marker_size: float = 0.05
@export var debug_log_insertions: bool = false # imprime en consola cada inserción de wrap-anchor con sus datos exactos (punto de contacto, normal, resultado)

var anchor_start: RopeAnchor
var anchor_end: RopeAnchor

## Puntos en espacio LOCAL a este nodo, listos para que el render (Fase 2)
## o cualquier otro sistema los consuma sin saber nada de la simulación.
var points: PackedVector3Array = PackedVector3Array()

var _state: RopeState
var _solver: RopeVerletSolver
var _collision: RopeWorldCollision
var _wrapping: RopeEdgeWrapping

var _initialized: bool = false
var _exclude_rids: Array[RID] = []

var _debug_mesh_instance: MeshInstance3D
var _immediate_mesh: ImmediateMesh

func _ready() -> void:
	_state = RopeState.new()
	_solver = RopeVerletSolver.new()
	_collision = RopeWorldCollision.new()
	_wrapping = RopeEdgeWrapping.new()

	if anchor_start == null and anchor_start_node_path != NodePath():
		var n := get_node_or_null(anchor_start_node_path)
		if n:
			anchor_start = NodeAnchor.new(n)
	if anchor_end == null and anchor_end_node_path != NodePath():
		var n := get_node_or_null(anchor_end_node_path)
		if n:
			anchor_end = NodeAnchor.new(n)
	if debug_draw:
		_setup_debug_mesh()

func set_anchor_start(anchor: RopeAnchor) -> void:
	anchor_start = anchor
	_initialized = false

func set_anchor_end(anchor: RopeAnchor) -> void:
	anchor_end = anchor
	_initialized = false

func _physics_process(delta: float) -> void:
	if anchor_start == null or anchor_end == null:
		return
	if not anchor_start.is_valid() or not anchor_end.is_valid():
		return
	if not _initialized:
		_initialize_particles()

	_sync_config_to_components()

	var space_state := get_world_3d().direct_space_state

	_state.clear_contact_flags()

	_solver.integrate(_state, delta)
	if enable_ccd:
		_collision.resolve_continuous_collision(_state, space_state)
	for i in range(constraint_iterations):
		_solver.solve_distance_constraints(_state, i % 2 == 1)
		if enable_world_collision:
			_collision.resolve_world_collisions(_state, space_state)
	_pin_ends()

	if enable_edge_wrapping:
		_wrapping.update_streaks(_state)
		_wrapping.try_insert_wrap_anchor(_state)
		_wrapping.try_release_wrap_anchors(_state, space_state)

	_update_public_points()

	if debug_draw:
		_update_debug_mesh()

## Copia los @export relevantes hacia los componentes, cada frame — así
## un cambio en vivo desde el Inspector se refleja sin exponer setters
## individuales por cada propiedad.
func _sync_config_to_components() -> void:
	_solver.gravity = gravity
	_solver.damping = damping

	_collision.rope_radius = rope_radius
	_collision.collision_mask = collision_mask
	_collision.exclude_rids = _exclude_rids
	_collision.collision_reaction_strength = collision_reaction_strength

	_wrapping.wrap_insert_frames = wrap_insert_frames
	_wrapping.max_wrap_anchors = max_wrap_anchors
	_wrapping.min_wrap_spacing = min_wrap_spacing
	_wrapping.min_bend_distance = min_bend_distance
	_wrapping.rope_radius = rope_radius
	_wrapping.collision_mask = collision_mask
	_wrapping.exclude_rids = _exclude_rids
	_wrapping.release_check_interval = release_check_interval
	_wrapping.debug_log_insertions = debug_log_insertions

func _initialize_particles() -> void:
	var start_pos := anchor_start.get_anchor_position()
	var end_pos := anchor_end.get_anchor_position()
	var natural_length := rope_length if rope_length > 0.0 else start_pos.distance_to(end_pos) * slack_factor

	if auto_segment_scaling:
		var computed_count := int(round(natural_length * segments_per_meter))
		segment_count = clampi(computed_count, min_segments, max_segments)

	var count := segment_count + 1
	var uniform_rest_length := natural_length / float(segment_count)
	_state.setup_straight_line(start_pos, end_pos, count, uniform_rest_length)

	_initialized = true

	_exclude_rids.clear()
	if exclude_anchor_bodies:
		var rid_start := anchor_start.get_body_rid()
		var rid_end := anchor_end.get_body_rid()
		if rid_start.is_valid():
			_exclude_rids.append(rid_start)
		if rid_end.is_valid():
			_exclude_rids.append(rid_end)

func _pin_ends() -> void:
	var last := _state.pos.size() - 1
	_state.pos[0] = anchor_start.get_anchor_position()
	_state.pos[last] = anchor_end.get_anchor_position()
	# Congelamos también la posición "anterior" de los extremos para que
	# un movimiento brusco del ancla no le meta velocidad falsa a la cuerda.
	_state.pos_old[0] = _state.pos[0]
	_state.pos_old[last] = _state.pos[last]

func _update_public_points() -> void:
	if points.size() != _state.pos.size():
		points.resize(_state.pos.size())
	for i in range(_state.pos.size()):
		points[i] = to_local(_state.pos[i])

## Útil para debug externo o para un futuro sistema de colisión que
## necesite las posiciones reales en el mundo, no relativas a este nodo.
## Devuelve un array vacío (en vez de crashear) si todavía no corrió
## _ready() en este nodo — puede pasar si algo lo consulta en la misma
## ventana de un frame en que recién se instanció.
func get_points_global() -> PackedVector3Array:
	if _state == null:
		return PackedVector3Array()
	return _state.pos

func _setup_debug_mesh() -> void:
	_immediate_mesh = ImmediateMesh.new()
	_debug_mesh_instance = MeshInstance3D.new()
	_debug_mesh_instance.mesh = _immediate_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = debug_color
	_debug_mesh_instance.material_override = mat
	add_child(_debug_mesh_instance)

func _update_debug_mesh() -> void:
	_immediate_mesh.clear_surfaces()
	if _state.pos.size() < 2:
		return

	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in _state.pos:
		_immediate_mesh.surface_add_vertex(to_local(p))
	_immediate_mesh.surface_end()

	# Una crucecita en cada wrap-anchor (partícula pinneada que NO es un
	# extremo real) — sirve para distinguir a simple vista un ancla de
	# envolvimiento insertada de una partícula libre común, y para ver
	# exactamente dónde quedó posicionada respecto a la geometría real.
	# Chequeamos ANTES de abrir la superficie si hay algo para dibujar —
	# sin esto, en cualquier frame sin wrap-anchors (la mayoría del
	# tiempo), surface_end() explota porque no se agregó ni un vértice.
	if debug_draw_wrap_anchors and _state.pos.size() > 2:
		var has_wrap_anchor := false
		for i in range(1, _state.pos.size() - 1):
			if _state.pinned[i]:
				has_wrap_anchor = true
				break

		if has_wrap_anchor:
			_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
			var s := debug_wrap_anchor_marker_size
			for i in range(1, _state.pos.size() - 1):
				if not _state.pinned[i]:
					continue
				var p := to_local(_state.pos[i])
				_immediate_mesh.surface_add_vertex(p + Vector3(s, 0, 0))
				_immediate_mesh.surface_add_vertex(p - Vector3(s, 0, 0))
				_immediate_mesh.surface_add_vertex(p + Vector3(0, s, 0))
				_immediate_mesh.surface_add_vertex(p - Vector3(0, s, 0))
				_immediate_mesh.surface_add_vertex(p + Vector3(0, 0, s))
				_immediate_mesh.surface_add_vertex(p - Vector3(0, 0, s))
			_immediate_mesh.surface_end()
