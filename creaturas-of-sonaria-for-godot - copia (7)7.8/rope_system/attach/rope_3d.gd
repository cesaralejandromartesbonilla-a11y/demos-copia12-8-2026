class_name Rope3D
extends Node3D
## Simulación Verlet + constraints de distancia + colisión contra el mundo
## (por segmento, con cápsulas orientadas) + colisión continua (CCD) +
## FASE 4: envolvimiento real en aristas, insertando anclas temporales
## pinneadas exactamente en el punto de contacto sostenido, y liberándolas
## cuando vuelve a haber línea de visión limpia. Todavía sin catenaria
## analítica para cuerdas en reposo (Fase 7, opcional) ni autocolisión
## (Fase 9, futura). El traspaso residual en casos extremos queda para
## pulido en Fase 10.
##
## Incluye un dibujo de DEBUG con ImmediateMesh, independiente del tubo
## real que genera RopeMeshRenderer3D (Fase 2).

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

@export_group("Tensión y estabilidad")
@export var max_stretch_factor: float = 1.05 # tope DURO: ningún segmento supera rest_length * este valor, sin importar las iteraciones blandas
@export_range(0.0, 1.0) var collision_velocity_damping: float = 0.8 # cuánta "velocidad falsa" generada por correcciones de colisión se cancela (0 = nada, más jitter; 1 = se cancela toda, más "pegajoso")

@export_group("Colisión contra el mundo (Fase 3)")
@export var enable_world_collision: bool = true
@export var collision_mask: int = 1
@export var rope_radius: float = 0.03 # idealmente igual al radius del RopeMeshRenderer3D
@export var exclude_anchor_bodies: bool = true # evita que la cuerda choque contra el cuerpo del que cuelga
@export var collision_reaction_strength: float = 1.0 # cuánto empuja la cuerda a los RigidBody3D que toca (0 = no reacciona)
@export var enable_ccd: bool = true # colisión continua: evita traspasos a alta velocidad (movimiento brusco, "fuerza infinita")
@export var enable_particle_overlap_fix: bool = true # corrección individual por partícula, ayuda cuando el objeto mide ~1-2 segmentos

@export_group("Envolvimiento en aristas (Fase 4)")
@export var enable_edge_wrapping: bool = true
@export var wrap_insert_frames: int = 12 # frames consecutivos de contacto sostenido antes de insertar un ancla real
@export var max_wrap_anchors: int = 8 # tope de anclas temporales simultáneas por cuerda
@export var min_wrap_spacing: float = 0.05 # distancia mínima a un wrap-anchor vecino para permitir insertar otro
@export var release_check_interval: int = 15 # cada cuántos frames se intenta liberar anclas existentes
@export var contact_streak_decay: int = 2 # en vez de resetear a 0 al perder contacto un frame, resta esto (tolera que el contacto "salte" de índice)

@export_group("Debug")
@export var debug_draw: bool = true
@export var debug_color: Color = Color(0.9, 0.7, 0.2)

var anchor_start: RopeAnchor
var anchor_end: RopeAnchor

## Puntos en espacio LOCAL a este nodo, listos para que el render (Fase 2)
## o cualquier otro sistema los consuma sin saber nada de la simulación.
## El tamaño de este array ahora es DINÁMICO: crece y encoge cuando se
## insertan o liberan anclas de envolvimiento (Fase 4).
var points: PackedVector3Array = PackedVector3Array()

var _pos: PackedVector3Array      # posiciones actuales, en espacio GLOBAL
var _pos_old: PackedVector3Array  # posiciones del frame anterior, para Verlet
var _pinned: Array[bool] = []     # true = extremo real o wrap-anchor: no se mueve libremente
var _rest_lengths: PackedFloat32Array = [] # largo de reposo POR SEGMENTO (tamaño = _pos.size() - 1)

var _segment_length: float = 0.0  # largo de reposo uniforme usado solo al inicializar
var _initialized: bool = false
var _has_initialized_once: bool = false # true para siempre tras la primera vez, evita que auto_segment_scaling "reevalúe" el segment_count en re-inicializaciones

var _debug_mesh_instance: MeshInstance3D
var _immediate_mesh: ImmediateMesh

var _capsule_shape: CapsuleShape3D
var _ccd_sphere_shape: SphereShape3D
var _exclude_rids: Array[RID] = []

# --- Estado del sistema de envolvimiento (Fase 4) ---
var _had_contact_this_frame: PackedByteArray = []
var _contact_streak: PackedInt32Array = []
var _last_contact_point: PackedVector3Array = []
var _last_contact_normal: PackedVector3Array = []
var _release_check_counter: int = 0

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

	for i in range(_had_contact_this_frame.size()):
		_had_contact_this_frame[i] = 0

	_integrate(delta)
	if enable_ccd:
		_resolve_continuous_collision()
	for i in range(constraint_iterations):
		_solve_distance_constraints()
		if enable_world_collision:
			_resolve_world_collisions()
			if enable_particle_overlap_fix:
				_resolve_particle_overlaps()
	_enforce_hard_length_limit()
	_pin_ends()

	if enable_edge_wrapping:
		_update_wrap_anchor_streaks()
		_try_insert_wrap_anchor()
		_try_release_wrap_anchors()

	_update_public_points()

	if debug_draw:
		_update_debug_mesh()

func _initialize_particles() -> void:
	var start_pos := anchor_start.get_anchor_position()
	var end_pos := anchor_end.get_anchor_position()
	var natural_length := rope_length if rope_length > 0.0 else start_pos.distance_to(end_pos) * slack_factor

	# auto_segment_scaling solo decide el segment_count LA PRIMERA VEZ que
	# esta cuerda se inicializa. Si algo dispara una re-inicialización más
	# adelante (por ejemplo, set_anchor_start/end llamado de nuevo), NO
	# queremos que la cantidad de segmentos cambie sola según la distancia
	# del momento — eso es lo que causaba la "evolución" de 8 a 3 segmentos.
	if auto_segment_scaling and not _has_initialized_once:
		var computed_count := int(round(natural_length * segments_per_meter))
		segment_count = clampi(computed_count, min_segments, max_segments)
	_has_initialized_once = true

	var count := segment_count + 1
	_pos.resize(count)
	_pos_old.resize(count)
	_pinned.resize(count)
	for i in range(count):
		var t := float(i) / float(count - 1)
		var p := start_pos.lerp(end_pos, t)
		_pos[i] = p
		_pos_old[i] = p
		_pinned[i] = (i == 0 or i == count - 1)

	_segment_length = natural_length / float(segment_count)
	_rest_lengths.resize(segment_count)
	for i in range(segment_count):
		_rest_lengths[i] = _segment_length

	_had_contact_this_frame.resize(segment_count)
	_contact_streak.resize(segment_count)
	_last_contact_point.resize(segment_count)
	_last_contact_normal.resize(segment_count)
	for i in range(segment_count):
		_had_contact_this_frame[i] = 0
		_contact_streak[i] = 0
		_last_contact_point[i] = Vector3.ZERO
		_last_contact_normal[i] = Vector3.ZERO

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
		if _pinned[i]:
			continue
		var current := _pos[i]
		var velocity := (current - _pos_old[i]) * damping
		var next := current + velocity + gravity * delta * delta
		_pos_old[i] = current
		_pos[i] = next

## Ahora usa un largo de reposo POR SEGMENTO (_rest_lengths[i]) en vez de
## un único valor global, porque desde Fase 4 los segmentos ya no son
## todos iguales (los que nacen de dividir un segmento en un wrap-anchor
## tienen su propio largo). También respeta partículas pinneadas: si una
## punta no se puede mover, la otra recibe la corrección completa en vez
## de la mitad.
func _solve_distance_constraints() -> void:
	for i in range(_pos.size() - 1):
		var a := _pos[i]
		var b := _pos[i + 1]
		var delta_vec := b - a
		var dist := delta_vec.length()
		if dist < 0.00001:
			continue
		var rest: float = _rest_lengths[i]
		var diff := (dist - rest) / dist
		var correction := delta_vec * 0.5 * diff

		var pin_a: bool = _pinned[i]
		var pin_b: bool = _pinned[i + 1]
		if pin_a and pin_b:
			continue
		elif pin_a:
			_pos[i + 1] -= correction * 2.0
		elif pin_b:
			_pos[i] += correction * 2.0
		else:
			_pos[i] += correction
			_pos[i + 1] -= correction

## Trata cada TRAMO (no cada partícula suelta) como una cápsula orientada
## según la dirección real del segmento, y la testea contra el mundo
## estático usando el servidor de físicas directamente. Además registra
## contacto sostenido por segmento, insumo del sistema de envolvimiento.
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

		var depth := rope_radius - (mid - point).dot(normal)
		if depth <= 0.0:
			continue

		_had_contact_this_frame[i] = 1
		_last_contact_point[i] = point
		_last_contact_normal[i] = normal

		var correction := normal * depth
		if not _pinned[i]:
			_pos[i] += correction
			_pos_old[i] += correction * collision_velocity_damping
		if not _pinned[i + 1]:
			_pos[i + 1] += correction
			_pos_old[i + 1] += correction * collision_velocity_damping

		if collision_reaction_strength > 0.0:
			var collider_id: int = result.get("collider_id", 0)
			if collider_id != 0:
				var collider := instance_from_id(collider_id)
				if collider is RigidBody3D:
					var reaction := -normal * depth * collision_reaction_strength
					collider.apply_impulse(reaction, point - collider.global_position)

## Complemento a _resolve_world_collisions(): cada partícula (si no está
## pinneada) consigue su propia corrección independiente además de la
## que recibe como parte de su segmento.
func _resolve_particle_overlaps() -> void:
	var space_state := get_world_3d().direct_space_state
	_ccd_sphere_shape.radius = rope_radius

	for i in range(_pos.size()):
		if _pinned[i]:
			continue

		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = _ccd_sphere_shape
		query.transform = Transform3D(Basis(), _pos[i])
		query.collision_mask = collision_mask
		query.exclude = _exclude_rids
		query.margin = 0.01

		var result := space_state.get_rest_info(query)
		if result.is_empty():
			continue

		var normal: Vector3 = result.get("normal", Vector3.ZERO)
		var point: Vector3 = result.get("point", _pos[i])
		if normal == Vector3.ZERO:
			continue

		var depth := rope_radius - (_pos[i] - point).dot(normal)
		if depth <= 0.0:
			continue

		var correction := normal * depth
		_pos[i] += correction
		_pos_old[i] += correction * collision_velocity_damping

## CCD (colisión continua) POR PARTÍCULA: pregunta si el camino que
## recorrió esta partícula en este frame cruzó algo en el medio, no solo
## si la posición final está metida en algo. Evita el traspaso a alta
## velocidad. Las partículas pinneadas no se mueven, así que se saltean.
func _resolve_continuous_collision() -> void:
	var space_state := get_world_3d().direct_space_state
	_ccd_sphere_shape.radius = rope_radius

	for i in range(_pos.size()):
		if _pinned[i]:
			continue

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
			_pos_old[i] = _pos[i]

## Mueve una partícula de from_pos a to_pos, pero si ese camino cruza
## geometría del mundo en el medio, la clampea al punto seguro — igual
## que _resolve_continuous_collision(), pero reutilizable para cualquier
## corrección que pueda producir un salto grande en un solo frame.
func _move_particle_with_sweep(idx: int, from_pos: Vector3, to_pos: Vector3) -> void:
	if not enable_ccd:
		_pos[idx] = to_pos
		return
	var motion := to_pos - from_pos
	if motion.length() < 0.0005:
		_pos[idx] = to_pos
		return

	_ccd_sphere_shape.radius = rope_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _ccd_sphere_shape
	query.transform = Transform3D(Basis(), from_pos)
	query.motion = motion
	query.collision_mask = collision_mask
	query.exclude = _exclude_rids
	query.margin = 0.01

	var space_state := get_world_3d().direct_space_state
	var result := space_state.cast_motion(query)
	if result.size() < 2:
		_pos[idx] = to_pos
		return

	var safe_fraction: float = result[0]
	_pos[idx] = from_pos + motion * safe_fraction

## Tope DURO de elongación: a diferencia de _solve_distance_constraints
## (corrección suave e iterativa, con algo de "dar" según
## constraint_iterations), esta pasada corre UNA sola vez por frame y
## jamás permite que un segmento termine más largo que
## rest_length * max_stretch_factor — sin importar qué tan fuerte o
## rápido se haya tirado de un extremo en ese frame. Como esta corrección
## puede ser grande (a diferencia de las demás, que son chicas por
## diseño), usa _move_particle_with_sweep en vez de mover directamente:
## sin esto, un tirón fuerte contra el límite podía atravesar geometría
## de un solo salto — el bug que reportaste de "traspasa si me muevo rápido".
func _enforce_hard_length_limit() -> void:
	for i in range(_pos.size() - 1):
		var a := _pos[i]
		var b := _pos[i + 1]
		var delta_vec := b - a
		var dist := delta_vec.length()
		if dist < 0.00001:
			continue
		var max_dist: float = _rest_lengths[i] * max_stretch_factor
		if dist <= max_dist:
			continue
		var diff := (dist - max_dist) / dist
		var correction := delta_vec * diff

		var pin_a: bool = _pinned[i]
		var pin_b: bool = _pinned[i + 1]
		if pin_a and pin_b:
			continue
		elif pin_a:
			_move_particle_with_sweep(i + 1, b, b - correction)
		elif pin_b:
			_move_particle_with_sweep(i, a, a + correction)
		else:
			_move_particle_with_sweep(i, a, a + correction * 0.5)
			_move_particle_with_sweep(i + 1, b, b - correction * 0.5)


func _pin_ends() -> void:
	var last := _pos.size() - 1
	_pos[0] = anchor_start.get_anchor_position()
	_pos[last] = anchor_end.get_anchor_position()
	_pos_old[0] = _pos[0]
	_pos_old[last] = _pos[last]
	# Los wrap-anchors intermedios NO se tocan acá: quedan fijos porque
	# ninguna otra función (integrate, constraints, colisión) los mueve
	# mientras _pinned[i] sea true. No necesitan un valor "objetivo"
	# separado — su posición congelada ES el punto de contacto real.

## Lleva la cuenta de cuántos frames SEGUIDOS lleva cada segmento en
## contacto sostenido. Un contacto que dura muchos frames en el mismo
## segmento es la señal de que la cuerda está apoyada/pivotando en un
## borde, no solo rozando de pasada.
func _update_wrap_anchor_streaks() -> void:
	for i in range(_contact_streak.size()):
		if _had_contact_this_frame[i]:
			_contact_streak[i] += 1
		else:
			_contact_streak[i] = max(0, _contact_streak[i] - contact_streak_decay)

## Si algún segmento acumuló suficiente contacto sostenido, inserta una
## partícula PINNEADA exactamente en el punto de contacto real, partiendo
## ese segmento en dos con sus propios largos de reposo. Esto es lo que
## resuelve de fondo el caso "mitad adentro, mitad afuera": ahora hay un
## punto real en el contacto, no una corrección aproximada compartida
## entre dos puntas que podían estar lejos del borde real.
func _try_insert_wrap_anchor() -> void:
	var current_wrap_count := 0
	for p in _pinned:
		if p:
			current_wrap_count += 1
	current_wrap_count -= 2 # descontamos los dos extremos reales (siempre pinneados)
	if current_wrap_count >= max_wrap_anchors:
		return

	for i in range(_contact_streak.size()):
		if _contact_streak[i] < wrap_insert_frames:
			continue

		var contact_point: Vector3 = _last_contact_point[i]
		var contact_normal: Vector3 = _last_contact_normal[i]

		# CLAVE: el punto que devuelve la colisión está SOBRE la superficie
		# del objeto — es la posición de la CÁSCARA de la cuerda, no de su
		# centro. Si pinneamos ahí directamente, la mitad del tubo visual
		# queda incrustada en la superficie para siempre (nada vuelve a
		# corregir un punto pinneado). Desplazamos rope_radius a lo largo
		# de la normal para pinnear el CENTRO en el lugar correcto.
		var insertion_point := contact_point + contact_normal * rope_radius

		# No insertamos pegado a un wrap-anchor vecino ya existente: evita
		# generar micro-segmentos inestables uno al lado del otro.
		if _pinned[i] and insertion_point.distance_to(_pos[i]) < min_wrap_spacing:
			continue
		if _pinned[i + 1] and insertion_point.distance_to(_pos[i + 1]) < min_wrap_spacing:
			continue

		var new_rest_a := _pos[i].distance_to(insertion_point)
		var new_rest_b := insertion_point.distance_to(_pos[i + 1])

		_pos.insert(i + 1, insertion_point)
		_pos_old.insert(i + 1, insertion_point)
		_pinned.insert(i + 1, true)

		_rest_lengths[i] = new_rest_a
		_rest_lengths.insert(i + 1, new_rest_b)

		_had_contact_this_frame.insert(i + 1, 0)
		_contact_streak.insert(i + 1, 0)
		_last_contact_point.insert(i + 1, Vector3.ZERO)
		_last_contact_normal.insert(i + 1, Vector3.ZERO)
		_contact_streak[i] = 0

		return # una inserción por frame alcanza; el resto espera al próximo

## Cada release_check_interval frames, revisa si algún wrap-anchor ya
## puede soltarse: si hay línea de visión limpia entre sus dos vecinos, el
## punto se elimina y los dos segmentos que lo rodeaban vuelven a ser uno
## solo (fusionando sus largos de reposo para no generar tensión de golpe).
## Simplificación consciente para esta etapa: el raycast no tiene en
## cuenta el grosor real de la cuerda (rope_radius), así que en bordes muy
## ajustados puede liberar un poco antes de lo ideal — queda anotado para
## Fase 10 (pulido) si hace falta más precisión ahí.
func _try_release_wrap_anchors() -> void:
	_release_check_counter += 1
	if _release_check_counter < release_check_interval:
		return
	_release_check_counter = 0

	var space_state := get_world_3d().direct_space_state

	for i in range(1, _pos.size() - 1):
		if not _pinned[i]:
			continue

		var prev_pos := _pos[i - 1]
		var next_pos := _pos[i + 1]

		var query := PhysicsRayQueryParameters3D.create(prev_pos, next_pos)
		query.collision_mask = collision_mask
		query.exclude = _exclude_rids

		var result := space_state.intersect_ray(query)
		if not result.is_empty():
			continue # todavía hay algo en el medio, no se libera

		var merged_rest: float = _rest_lengths[i - 1] + _rest_lengths[i]
		_rest_lengths[i - 1] = merged_rest
		_rest_lengths.remove_at(i)

		_pos.remove_at(i)
		_pos_old.remove_at(i)
		_pinned.remove_at(i)
		_had_contact_this_frame.remove_at(i)
		_contact_streak.remove_at(i)
		_last_contact_point.remove_at(i)
		_last_contact_normal.remove_at(i)

		return # un solo cambio estructural por chequeo, por las dudas

func _update_public_points() -> void:
	if points.size() != _pos.size():
		points.resize(_pos.size())
	for i in range(_pos.size()):
		points[i] = to_local(_pos[i])

## Útil para debug externo o para otros sistemas que necesiten las
## posiciones reales en el mundo, no relativas a este nodo.
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
