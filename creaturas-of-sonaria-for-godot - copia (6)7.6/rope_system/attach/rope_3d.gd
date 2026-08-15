class_name Rope3D
extends Node3D
## FASE 3: simulación Verlet + constraints de distancia + colisión contra
## el mundo estático, resuelta POR SEGMENTO con cápsulas orientadas (no
## por partícula suelta como una bolsa de esferas). Todavía sin el
## "envolvimiento" en aristas con anclas temporales (Fase 4) ni catenaria
## analítica para cuerdas en reposo (Fase 7, opcional).
##
## Incluye un dibujo de DEBUG con ImmediateMesh, independiente del tubo
## real que genera RopeMeshRenderer3D (Fase 2). Podés apagarlo con
## debug_draw = false una vez que confirmes que el renderer anda bien.

@export_group("Segmentación")
@export var auto_segment_scaling: bool = true # si es true, segment_count se recalcula según el largo real
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
@export var rope_length: float = 0.0: # 0 = usar la distancia inicial entre anclas + slack_factor
	set(value):
		rope_length = max(0.0, value)
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

@export_group("Debug")
@export var debug_draw: bool = true
@export var debug_color: Color = Color(0.9, 0.7, 0.2)

var anchor_start: RopeAnchor
var anchor_end: RopeAnchor

## Puntos en espacio LOCAL a este nodo, listos para que el render (Fase 2)
## o cualquier otro sistema los consuma sin saber nada de la simulación.
var points: PackedVector3Array = PackedVector3Array()

var _pos: PackedVector3Array      # posiciones actuales, en espacio GLOBAL
var _pos_old: PackedVector3Array  # posiciones del frame anterior, para Verlet
var _segment_length: float = 0.0
var _initialized: bool = false

var _debug_mesh_instance: MeshInstance3D
var _immediate_mesh: ImmediateMesh

var _capsule_shape: CapsuleShape3D
var _ccd_sphere_shape: SphereShape3D
var _exclude_rids: Array[RID] = []

func _ready() -> void:
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
	_capsule_shape = CapsuleShape3D.new()
	_ccd_sphere_shape = SphereShape3D.new()

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

	_integrate(delta)
	if enable_ccd:
		_resolve_continuous_collision()
	for i in range(constraint_iterations):
		_solve_distance_constraints()
		if enable_world_collision:
			_resolve_world_collisions()
	_pin_ends()
	_update_public_points()

	if debug_draw:
		_update_debug_mesh()

func _initialize_particles() -> void:
	var start_pos := anchor_start.get_anchor_position()
	var end_pos := anchor_end.get_anchor_position()
	var natural_length := rope_length if rope_length > 0.0 else start_pos.distance_to(end_pos) * slack_factor

	if auto_segment_scaling:
		var computed_count := int(round(natural_length * segments_per_meter))
		segment_count = clampi(computed_count, min_segments, max_segments)

	var count := segment_count + 1
	_pos.resize(count)
	_pos_old.resize(count)
	for i in range(count):
		var t := float(i) / float(count - 1)
		var p := start_pos.lerp(end_pos, t)
		_pos[i] = p
		_pos_old[i] = p

	_segment_length = natural_length / float(segment_count)
	_initialized = true

	_exclude_rids.clear()
	if exclude_anchor_bodies:
		var rid_start := anchor_start.get_body_rid()
		var rid_end := anchor_end.get_body_rid()
		if rid_start.is_valid():
			_exclude_rids.append(rid_start)
		if rid_end.is_valid():
			_exclude_rids.append(rid_end)

func _integrate(delta: float) -> void:
	for i in range(_pos.size()):
		var current := _pos[i]
		var velocity := (current - _pos_old[i]) * damping
		var next := current + velocity + gravity * delta * delta
		_pos_old[i] = current
		_pos[i] = next

func _solve_distance_constraints() -> void:
	for i in range(_pos.size() - 1):
		var a := _pos[i]
		var b := _pos[i + 1]
		var delta_vec := b - a
		var dist := delta_vec.length()
		if dist < 0.00001:
			continue
		var diff := (dist - _segment_length) / dist
		var correction := delta_vec * 0.5 * diff
		_pos[i] += correction
		_pos[i + 1] -= correction

## Trata cada TRAMO (no cada partícula suelta) como una cápsula orientada
## según la dirección real del segmento, y la testea contra el mundo
## estático usando el servidor de físicas directamente. Esto es lo que da
## colisión "direccional": un segmento casi horizontal se apoya distinto
## que uno casi vertical, porque la cápsula realmente tiene esa
## orientación al momento de chocar (no es una esfera por partícula).
func _resolve_world_collisions() -> void:
	var space_state := get_world_3d().direct_space_state

	for i in range(_pos.size() - 1):
		var a := _pos[i]
		var b := _pos[i + 1]
		var segment_vec := b - a
		var length := segment_vec.length()
		if length < 0.001:
			continue
		var direction := segment_vec / length
		var mid := (a + b) * 0.5

		_capsule_shape.radius = rope_radius
		_capsule_shape.height = max(length - rope_radius * 2.0, 0.001)

		var xform := Transform3D()
		# CapsuleShape3D tiene su eje largo en Y local; rotamos ese eje Y
		# para que apunte en la dirección real del segmento.
		xform.basis = Basis(Quaternion(Vector3.UP, direction))
		xform.origin = mid

		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = _capsule_shape
		query.transform = xform
		query.collision_mask = collision_mask
		query.exclude = _exclude_rids
		query.margin = 0.01

		var result := space_state.get_rest_info(query)
		if result.is_empty():
			continue

		var normal: Vector3 = result.get("normal", Vector3.ZERO)
		var point: Vector3 = result.get("point", mid)
		if normal == Vector3.ZERO:
			continue

		# Profundidad aproximada: cuánto se metió el punto medio del
		# segmento más allá de la superficie de contacto, a lo largo de
		# la normal. No es geométricamente exacto para cada extremo del
		# segmento, pero corrige bien en la práctica dado que iteramos
		# esto varias veces junto con las constraints de distancia.
		var depth := rope_radius - (mid - point).dot(normal)
		if depth <= 0.0:
			continue

		var correction := normal * depth
		_pos[i] += correction
		_pos[i + 1] += correction

		# Sin esto, la cuerda "gana" siempre la colisión: se corrige a sí
		# misma pero nunca le devuelve el empujón al objeto contra el que
		# chocó, así que un RigidBody3D liviano parece atravesarla.
		if collision_reaction_strength > 0.0:
			var collider_id: int = result.get("collider_id", 0)
			if collider_id != 0:
				var collider := instance_from_id(collider_id)
				if collider is RigidBody3D:
					var reaction := -normal * depth * collision_reaction_strength
					collider.apply_impulse(reaction, point - collider.global_position)

## CCD (colisión continua) POR PARTÍCULA: en vez de preguntar "¿está
## metida en algo la posición final?", pregunta "¿el camino que recorrió
## esta partícula en este frame cruzó algo en el medio?". Esto es lo que
## realmente evita el traspaso cuando hay velocidades muy altas — el
## chequeo de reposo (_resolve_world_collisions) no alcanza a detectarlo
## porque, tras un salto grande, la partícula puede terminar del otro
## lado de la geometría sin haber estado nunca "adentro".
func _resolve_continuous_collision() -> void:
	var space_state := get_world_3d().direct_space_state
	_ccd_sphere_shape.radius = rope_radius

	for i in range(_pos.size()):
		var from_pos := _pos_old[i]
		var to_pos := _pos[i]
		var motion := to_pos - from_pos
		if motion.length() < 0.0005:
			continue

		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = _ccd_sphere_shape
		query.transform = Transform3D(Basis(), from_pos)
		query.motion = motion
		query.collision_mask = collision_mask
		query.exclude = _exclude_rids
		query.margin = 0.01

		var result := space_state.cast_motion(query)
		if result.size() < 2:
			continue

		var safe_fraction: float = result[0]
		if safe_fraction < 1.0:
			_pos[i] = from_pos + motion * safe_fraction
			# Igualamos la posición anterior a la actual para no dejar
			# "velocidad acumulada" empujando hacia la superficie con la
			# que se acaba de chocar (si no, en el próximo frame vuelve
			# a intentar cruzar con la misma energía).
			_pos_old[i] = _pos[i]

func _pin_ends() -> void:
	var last := _pos.size() - 1
	_pos[0] = anchor_start.get_anchor_position()
	_pos[last] = anchor_end.get_anchor_position()
	# Congelamos también la posición "anterior" de los extremos para que
	# un movimiento brusco del ancla no le meta velocidad falsa a la cuerda.
	_pos_old[0] = _pos[0]
	_pos_old[last] = _pos[last]

func _update_public_points() -> void:
	if points.size() != _pos.size():
		points.resize(_pos.size())
	for i in range(_pos.size()):
		points[i] = to_local(_pos[i])

## Útil para debug externo o para un futuro sistema de colisión que
## necesite las posiciones reales en el mundo, no relativas a este nodo.
func get_points_global() -> PackedVector3Array:
	return _pos

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
	if _pos.size() < 2:
		return
	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in _pos:
		_immediate_mesh.surface_add_vertex(to_local(p))
	_immediate_mesh.surface_end()
