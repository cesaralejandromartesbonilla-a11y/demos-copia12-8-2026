extends Node3D

@export_group("Dimensiones")
@export var segment_count: int = 6
@export var segment_height: float = 0.6
@export var segment_radius: float = 0.15

@export_group("Músculo (Fuerzas)")
@export var straighten_force: float = 40.0 # Qué tan fuerte intenta quedarse recta (Sube para más rigidez)
@export var twist_correction_force: float = 15.0 # Fuerza para evitar que los bloques giren sobre sí mismos
@export var custom_angular_damp: float = 6.0 # Amortiguación: evita que la torre tiemble o rebote infinitamente

var segments: Array[RigidBody3D] = []

func _ready():
	build_active_rope()

func build_active_rope():
	for i in range(segment_count):
		var rb = RigidBody3D.new()
		
		# Posición e inercias iniciales
		rb.position = Vector3(0, (i * segment_height) + (segment_height / 2.0), 0)
		
		# La punta debe ser más ligera para facilitar que la base la levante
		rb.mass = 1.0 - (float(i) * 0.08) 
		rb.angular_damp = custom_angular_damp 
		
		# Colisión
		var col = CollisionShape3D.new()
		var cyl = CylinderShape3D.new()
		cyl.height = segment_height
		cyl.radius = segment_radius
		col.shape = cyl
		rb.add_child(col)
		
		# Visual de Debug
		var mesh_inst = MeshInstance3D.new()
		var mesh = CylinderMesh.new()
		mesh.height = segment_height
		mesh.top_radius = segment_radius
		mesh.bottom_radius = segment_radius
		mesh_inst.mesh = mesh
		rb.add_child(mesh_inst)
		
		add_child(rb)
		segments.append(rb)
		
		# Conexión de Joints con las correcciones de posición y colisión que funcionaron
		if i == 0:
			_create_joint(self, rb, Vector3(0, 0, 0))
		else:
			var prev_rb = segments[i-1]
			rb.add_collision_exception_with(prev_rb) # Evita explosión por solapamiento
			
			var joint_local_pos = Vector3(0, i * segment_height, 0)
			_create_joint(prev_rb, rb, joint_local_pos)

func _create_joint(node_A: Node, node_B: Node, anchor_pos: Vector3):
	var joint = ConeTwistJoint3D.new()
	add_child(joint)
	
	joint.position = anchor_pos
	joint.rotation_degrees = Vector3(0, 0, 90) # Orientación correcta del hueso
	
	if node_A is RigidBody3D:
		joint.node_a = node_A.get_path()
	else:
		var static_base = StaticBody3D.new()
		add_child(static_base)
		static_base.position = anchor_pos
		joint.node_a = static_base.get_path()
		
	joint.node_b = node_B.get_path()
	
	# Límites mecánicos del cono (60 grados de flexión máxima)
	joint.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(60))
	joint.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(45))

# =========================================================
# ⚙️ CONTROLADOR DE FUERZAS GRADUADO (Propagación desde la Base)
# =========================================================
func _physics_process(_delta):
	# Recorremos al revés (desde la punta hacia la base) o normal, 
	# pero aplicando un multiplicador de fuerza basado en el índice.
	for i in range(segments.size()):
		var rb = segments[i]
		if is_instance_valid(rb):
			
			# 🌟 TRUCO: Los eslabones más cercanos a la base (i bajo) 
			# reciben mucha más fuerza que los de la punta (i alto).
			var height_factor = float(segments.size() - i) / float(segments.size())
			var current_straighten_force = straighten_force * height_factor
			
			# --- 1. FUERZA DE ALINEACIÓN ---
			var current_up = rb.global_transform.basis.y.normalized()
			var target_up = Vector3.UP
			
			var alignment_axis = current_up.cross(target_up)
			var alignment_error = alignment_axis.length()
			
			if alignment_error > 0.001:
				# Usamos la fuerza graduada por altura
				var pull_torque = alignment_axis.normalized() * (alignment_error * current_straighten_force)
				rb.apply_torque(pull_torque)
			
			# --- 2. ANTITORSÍON ---
			var current_forward = rb.global_transform.basis.x.normalized()
			var target_forward = Vector3.RIGHT
			
			var twist_axis = current_forward.cross(target_forward)
			var twist_error = twist_axis.y 
			
			if abs(twist_error) > 0.001:
				var twist_torque = Vector3(0, twist_error * (twist_correction_force * height_factor), 0)
				rb.apply_torque(twist_torque)
