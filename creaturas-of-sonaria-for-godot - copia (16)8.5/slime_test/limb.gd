class_name Limb
extends Node3D

# ==========================================
# 🦴 LIMB — bloque de construcción reutilizable para Comprender
# ==========================================
# Generalización directa de tu tentacle_builder.gd. Misma idea exacta:
# una cadena de RigidBody3D + ConeTwistJoint3D, una sola fuerza de
# alineación graduada por altura, sin memoria entre frames.
#
# Lo que cambia: en vez de crecer siempre desde el origen del propio
# nodo hacia arriba (Vector3.UP fijo), crece a lo largo del eje Y del
# "ancla" que le pases — así un brazo, una pierna o una columna son
# la MISMA clase, solo con anclas en distinta posición/orientación.
#
# Una criatura se arma poniendo varios Limb uno al lado del otro — ver
# el ejemplo de uso al final del archivo.

@export_group("Dimensiones")
@export var segment_count: int = 6
@export var segment_height: float = 0.6
@export var segment_radius: float = 0.15

@export_group("Músculo (Fuerzas)")
@export var straighten_force: float = 40.0
@export var twist_correction_force: float = 15.0
@export var custom_angular_damp: float = 6.0

@export_group("Anclaje")
@export var anchor_override: Node3D = null # vacío = este mismo nodo es su propia ancla (para probarlo aislado, como tu original)
@export var collision_exempt_body: Node3D = null # cuerpo del que colgar sin chocar contra él (ej. el torso en HumanoidBody)

var segments: Array[RigidBody3D] = []
var root_anchor: Node3D

func _ready() -> void:
	build(anchor_override if anchor_override != null else self)

func _physics_process(_delta: float) -> void:
	apply_forces()

# ==========================================
# 🏗️ CONSTRUCCIÓN
# ==========================================
func build(anchor: Node3D) -> void:
	root_anchor = anchor

	# El primer segmento necesita un CUERPO FÍSICO real de qué sostenerse
	# (Joint3D no puede anclarse a un Node3D común). Si root_anchor no es
	# ya un RigidBody3D/StaticBody3D — el caso normal: es el propio Limb,
	# o un Marker3D — se crea un StaticBody3D dedicado en ese transform.
	# Sin esto, el joint del primer segmento queda sin nada real que lo
	# sostenga y toda la cadena cae — esto es justo lo que viste.
	var physical_anchor: Node3D = root_anchor
	if not (root_anchor is RigidBody3D or root_anchor is StaticBody3D):
		var static_base = StaticBody3D.new()
		add_child(static_base)
		static_base.global_transform = root_anchor.global_transform
		physical_anchor = static_base

	# Si el ancla ES un cuerpo físico de verdad (ej. el torso de
	# HumanoidBody, un CharacterBody3D), cada segmento necesita excepción
	# de colisión con él — si no, el primer segmento (que nace pegado al
	# ancla) empuja contra el propio cuerpo todo el tiempo, entorpeciendo
	# cualquier acción o movimiento.
	var body_to_exempt: PhysicsBody3D = root_anchor if root_anchor is PhysicsBody3D else null

	for i in range(segment_count):
		var rb = RigidBody3D.new()
		add_child(rb) # primero se une al árbol...

		# Crece a lo largo del eje Y LOCAL del ancla — un brazo rotado 90°
		# crece al costado, una pierna rotada 180° crece hacia abajo, sin
		# tocar nada de esta función.
		var local_offset = Vector3(0, (i * segment_height) + (segment_height / 2.0), 0)
		rb.global_transform = root_anchor.global_transform.translated_local(local_offset) # ...solo entonces se posiciona

		rb.mass = 1.0 - (float(i) * 0.08)
		rb.angular_damp = custom_angular_damp

		# Evita que la extremidad pelee contra el cuerpo del que cuelga —
		# sin esto, cada segmento choca con el torso/ancla física y
		# entorpece cualquier movimiento.
		if collision_exempt_body and collision_exempt_body is CollisionObject3D:
			rb.add_collision_exception_with(collision_exempt_body)

		if body_to_exempt:
			rb.add_collision_exception_with(body_to_exempt)

		var col = CollisionShape3D.new()
		var cyl = CylinderShape3D.new()
		cyl.height = segment_height
		cyl.radius = segment_radius
		col.shape = cyl
		rb.add_child(col)

		var mesh_inst = MeshInstance3D.new()
		var mesh = CylinderMesh.new()
		mesh.height = segment_height
		mesh.top_radius = segment_radius
		mesh.bottom_radius = segment_radius
		mesh_inst.mesh = mesh
		rb.add_child(mesh_inst)

		segments.append(rb)

		if i == 0:
			_create_joint(physical_anchor, rb, 0)
		else:
			var prev_rb = segments[i - 1]
			rb.add_collision_exception_with(prev_rb) # evita explosión por solapamiento
			_create_joint(prev_rb, rb, i)

func _create_joint(node_a: Node3D, node_b: RigidBody3D, index: int) -> void:
	var joint = ConeTwistJoint3D.new()
	add_child(joint)

	var pivot_transform = root_anchor.global_transform.translated_local(Vector3(0, index * segment_height, 0))
	# Corrección de eje del hueso — la misma que tu rotation_degrees=(0,0,90)
	# original, pero compuesta explícitamente sobre la orientación del
	# ancla en vez de asumir que el ancla siempre está sin rotar.
	pivot_transform.basis = pivot_transform.basis * Basis(Vector3(0, 0, 1), deg_to_rad(90))
	joint.global_transform = pivot_transform

	joint.node_a = node_a.get_path()
	joint.node_b = node_b.get_path()

	joint.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(60))
	joint.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(45))

# ==========================================
# ⚙️ FUERZA — la misma idea de tu original, generalizada al eje del ancla
# ==========================================
func apply_forces() -> void:
	if root_anchor == null: return
	# Antes: target_up = Vector3.UP fijo (world-space). Ahora: la dirección
	# "recta" de ESTA rama es la orientación de su propia ancla.
	var target_up = root_anchor.global_transform.basis.y.normalized()
	var target_forward = root_anchor.global_transform.basis.x.normalized()

	for i in range(segments.size()):
		var rb = segments[i]
		if not is_instance_valid(rb): continue

		# 🌟 Mismo truco que tu original: los eslabones cerca de la base
		# reciben más fuerza que los de la punta.
		var height_factor = float(segments.size() - i) / float(segments.size())
		var current_straighten_force = straighten_force * height_factor

		var current_up = rb.global_transform.basis.y.normalized()
		var alignment_axis = current_up.cross(target_up)
		var alignment_error = alignment_axis.length()

		if alignment_error > 0.001:
			var pull_torque = alignment_axis.normalized() * (alignment_error * current_straighten_force)
			rb.apply_torque(pull_torque)

		var current_forward = rb.global_transform.basis.x.normalized()
		var twist_axis = current_forward.cross(target_forward)
		# Antes: twist_error = twist_axis.y (asume que "arriba" siempre es
		# el eje Y del mundo). Ahora se proyecta sobre target_up de ESTA
		# rama, para que funcione igual de bien en una pierna horizontal.
		var twist_error = twist_axis.dot(target_up)

		if abs(twist_error) > 0.001:
			var twist_torque = target_up * (twist_error * twist_correction_force * height_factor)
			rb.apply_torque(twist_torque)

func destroy() -> void:
	for rb in segments:
		if is_instance_valid(rb): rb.queue_free()
	segments.clear()
	queue_free()


# ==========================================
# 🧍 EJEMPLO DE USO — una criatura simple, columna + brazos
# ==========================================
# Con anchor_override vacío, cada Limb ya es su propia ancla — armar una
# criatura es tan simple como poner varios nodos Limb como hijos del
# cuerpo, cada uno posicionado/rotado donde nace esa extremidad, todo
# desde el editor, sin código ni Marker3D aparte:
#
#   Cuerpo (Node3D)
#     ├─ Columna   (Limb, position=(0,0,0))
#     ├─ BrazoIzq  (Limb, position=(-0.4,1.2,0), rotation.z=-90°)
#     ├─ BrazoDer  (Limb, position=(0.4,1.2,0),  rotation.z=90°)
#     ├─ PiernaIzq (Limb, position=(-0.2,0,0),   rotation.z=180°)
#     └─ PiernaDer (Limb, position=(0.2,0,0),    rotation.z=180°)
#
# Cada uno se construye y se anima solo — nada coordinándolos desde
# afuera. anchor_override queda disponible por si más adelante quieres
# que una rama nazca apuntando a un nodo que no es ella misma.
