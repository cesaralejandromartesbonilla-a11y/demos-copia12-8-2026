extends Node3D
class_name ScaffoldModule

signal spring_jump_triggered(jump_velocity: Vector3)

# ==========================================
# 🎛️ SELECTOR DE MÉTODOS DE FUERZA
# ==========================================
enum ForceMethod {
	PROXIMITY_EFFECTOR, # Opción 1: Fuerza reactiva espacial
	WAVE_PROPAGATION,   # Opción 2: Efecto Látigo por tiempo
	BEZIER_CURVE        # Opción 3: Curva de Bézier
}

@export_group("Sistema de Propagación")
@export var current_method: ForceMethod = ForceMethod.WAVE_PROPAGATION

@export_subgroup("Ajustes de Onda (Método 2)")
@export var wave_delay_frames: int = 4 # Cuántos frames de retraso hay por cada eslabón
var magnet_history: Array[Vector2] = []
var max_history_size: int = 60 # Límite de memoria (60 frames = 1 segundo a 60fps)

@export_group("Andamio Físico Activo")
@export var base_straighten_force: float = 20.0 
@export var base_twist_force: float = 20.0      
@export var scaffold_angular_damp: float = 7.0  

@export_group("Imán del Andamio (Inercia)")
@export var magnet_stiffness: float = 35.0   
@export var magnet_damping: float = 4.0      
@export var magnet_inertia_pull: float = 1.5 

@export_group("Seguridad del Motor Físico")
@export var max_muscle_torque: float = 120.0 

@export_group("Salto de Resorte")
@export var spring_jump_multiplier: float = 15.0 
@export var max_jump_force: float = 30.0         

# Control interno
var scaffold_segments: Array[RigidBody3D] = []
var scaffold_joints: Array[ConeTwistJoint3D] = []
var scaffold_base_static: StaticBody3D = null
var is_active: bool = false

var magnet_tilt: Vector2 = Vector2.ZERO
var magnet_velocity: Vector2 = Vector2.ZERO

var parent_body: CharacterBody3D = null
var tracked_camera = null
var tracked_visuals: Array = []
var visual_y_offsets: Dictionary = {}

func _ready():
	parent_body = get_parent() as CharacterBody3D

func activate_scaffold(mass_scale: float, camera_node, visuals: Array, offsets: Dictionary) -> void:
	if is_active: return
	
	tracked_camera = camera_node
	tracked_visuals = visuals
	visual_y_offsets = offsets
	magnet_history.clear() # Limpiamos la memoria al nacer
	
	var dynamic_segments = int(clamp(5 + (mass_scale * 1.5), 4, 12)) 
	var dynamic_height = 0.6 * (1.0 + (mass_scale * 0.3))
	var dynamic_radius = 0.15 * mass_scale
	
	scaffold_base_static = StaticBody3D.new()
	add_child(scaffold_base_static)
	scaffold_base_static.position = Vector3.ZERO 
	
	var organic_physics_mat = PhysicsMaterial.new()
	organic_physics_mat.friction = 1.0 
	organic_physics_mat.rough = true   
	organic_physics_mat.bounce = 0.1   
	
	for i in range(dynamic_segments):
		var rb = RigidBody3D.new()
		rb.physics_material_override = organic_physics_mat
		rb.position = Vector3(0, (i * dynamic_height) + (dynamic_height / 2.0), 0)
		rb.mass = (1.0 - (float(i) * 0.05)) * mass_scale
		rb.sleeping = false
		rb.add_collision_exception_with(parent_body)
		
		var col = CollisionShape3D.new()
		var cyl = CylinderShape3D.new()
		cyl.height = dynamic_height
		cyl.radius = dynamic_radius
		col.shape = cyl
		rb.add_child(col)
		
		var mesh_inst = MeshInstance3D.new()
		var mesh = CylinderMesh.new()
		mesh.height = dynamic_height
		mesh.top_radius = dynamic_radius
		mesh.bottom_radius = dynamic_radius
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.5, 0.9, 0.6)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material = mat
		mesh_inst.mesh = mesh
		rb.add_child(mesh_inst)
		
		add_child(rb)
		scaffold_segments.append(rb)
		
		var joint = ConeTwistJoint3D.new()
		add_child(joint)
		scaffold_joints.append(joint)
		joint.rotation_degrees = Vector3(0, 0, 90) 
		joint.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(65))
		joint.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(30)) 
		
		if i == 0:
			joint.position = Vector3.ZERO
			joint.node_a = scaffold_base_static.get_path()
		else:
			var prev_rb = scaffold_segments[i-1]
			rb.add_collision_exception_with(prev_rb) 
			joint.position = Vector3(0, i * dynamic_height, 0)
			joint.node_a = prev_rb.get_path()
			
		joint.node_b = rb.get_path()
		
	is_active = true

func deactivate_scaffold() -> void:
	if not is_active: return
	
	var tension_length = magnet_tilt.length()
	if tension_length > 0.1:
		var jump_dir = Vector3(-magnet_tilt.x, 1.5, -magnet_tilt.y).normalized()
		var applied_force = clamp(tension_length * spring_jump_multiplier, 0.0, max_jump_force)
		emit_signal("spring_jump_triggered", jump_dir * applied_force)

	is_active = false
	if tracked_camera and "tracking_target" in tracked_camera:
		tracked_camera.tracking_target = null
		
	for joint in scaffold_joints:
		if is_instance_valid(joint): joint.queue_free()
	for rb in scaffold_segments:
		if is_instance_valid(rb): rb.queue_free()
	if is_instance_valid(scaffold_base_static): 
		scaffold_base_static.queue_free()
		
	scaffold_segments.clear()
	scaffold_joints.clear()
	scaffold_base_static = null
	tracked_visuals.clear()
	magnet_history.clear()

# ==========================================
# 🧠 BUCLE FÍSICO INTERNO
# ==========================================
# ==========================================
# 🧠 BUCLE FÍSICO INTERNO
# ==========================================
func _physics_process(delta: float) -> void:
	if not is_active or not is_instance_valid(parent_body):
		magnet_tilt = magnet_tilt.lerp(Vector2.ZERO, delta * 10.0)
		magnet_velocity = Vector2.ZERO
		return
		
	# 🧲 1. PROCESAR EL IMÁN
	var parent_vel = parent_body.velocity
	var movement_inertia = Vector2(-parent_vel.x, -parent_vel.z) * magnet_inertia_pull
	
	var spring_force = -magnet_stiffness * magnet_tilt
	var damping_force = -magnet_damping * magnet_velocity
	var total_accel = spring_force + damping_force + movement_inertia
	
	magnet_velocity += total_accel * delta
	magnet_tilt += magnet_velocity * delta
	magnet_velocity = magnet_velocity.limit_length(20.0) 
	magnet_tilt = magnet_tilt.limit_length(1.2)
	
	# GUARDAR HISTORIA (Para el Método 2)
	magnet_history.append(magnet_tilt)
	if magnet_history.size() > max_history_size:
		magnet_history.pop_front()
	
	var base_up = parent_body.global_transform.basis.y.normalized()
	var target_forward = parent_body.global_transform.basis.x.normalized()
	
	# 🦾 2. PROPAGAR FUERZAS A LOS ESLABONES
	for i in range(scaffold_segments.size()):
		var rb = scaffold_segments[i]
		if is_instance_valid(rb):
			rb.sleeping = false 
			
			var target_up: Vector3
			var proximity_boost: float = 1.0
			
			# ----------------------------------------------------
			# 🔀 SWITCH DE MÉTODOS DE DISEÑO
			# ----------------------------------------------------
			match current_method:
				
				ForceMethod.PROXIMITY_EFFECTOR:
					var sway_offset = Vector3(magnet_tilt.x, 0, magnet_tilt.y)
					target_up = (base_up + sway_offset).normalized()
					var ideal_distance = (i + 1) * 0.6 
					var ideal_pos = global_position + (target_up * ideal_distance)
					var spatial_error = rb.global_position.distance_to(ideal_pos)
					proximity_boost = 1.0 + (clamp(spatial_error, 0.0, 3.0) * 4.0)
					
				ForceMethod.WAVE_PROPAGATION:
					var history_index = magnet_history.size() - 1 - (i * wave_delay_frames)
					history_index = clamp(history_index, 0, magnet_history.size() - 1)
					var delayed_tilt = magnet_history[history_index]
					var sway_offset = Vector3(delayed_tilt.x, 0, delayed_tilt.y)
					target_up = (base_up + sway_offset).normalized()
					
				ForceMethod.BEZIER_CURVE:
					# Método 3: La Columna Matemática
					var total_height = scaffold_segments.size() * 0.6
					
					# Puntos de control de la Curva Cuadrática
					var p0 = global_position # Base
					var p1 = global_position + (base_up * (total_height * 0.5)) # Control: tira hacia arriba para mantener la base recta
					var p2 = global_position + (base_up * total_height) + Vector3(magnet_tilt.x, 0, magnet_tilt.y) # Punta imantada
					
					# Encontramos la posición de este eslabón en la curva (t va de 0.0 a 1.0)
					var t = float(i + 1) / float(scaffold_segments.size())
					
					# Calculamos la tangente (derivada) de Bézier para saber la inclinación exacta en 't'
					var tangent = (2.0 * (1.0 - t) * (p1 - p0)) + (2.0 * t * (p2 - p1))
					target_up = tangent.normalized()
					
			# ----------------------------------------------------
			
			var height_factor = float(scaffold_segments.size() - i) / float(scaffold_segments.size())
			var root_focus = lerp(0.2, 1.0, height_factor) 
			
			var current_up = rb.global_transform.basis.y.normalized()
			var alignment_axis = current_up.cross(target_up)
			var angle_error = current_up.angle_to(target_up) 
			var angle_deg = rad_to_deg(angle_error)
			
			var panic_weight = clamp((angle_deg - 10.0) / (25.0 - 10.0), 0.0, 1.0)
			var force_multiplier = lerp(8.0, 80.0, panic_weight)
			rb.angular_damp = lerp(scaffold_angular_damp, 18.0, panic_weight)
			
			var alignment_error_len = alignment_axis.length()
			if alignment_error_len > 0.001:
				var raw_torque = alignment_axis.normalized() * (alignment_error_len * base_straighten_force * root_focus * force_multiplier * proximity_boost)
				var safe_torque = raw_torque.limit_length(max_muscle_torque)
				rb.apply_torque(safe_torque)
			
			var current_forward = rb.global_transform.basis.x.normalized()
			var twist_axis = current_forward.cross(target_forward)
			var twist_error = twist_axis.dot(target_up) 
			
			if abs(twist_error) > 0.001:
				var raw_twist = target_up * (twist_error * base_twist_force * root_focus * proximity_boost)
				var safe_twist = raw_twist.limit_length(max_muscle_torque / 2.0) 
				rb.apply_torque(safe_twist)
	
	# 🎥 3. ACOPLE INDEPENDIENTE
	if scaffold_segments.size() > 0:
		var top_segment = scaffold_segments.back()
		if tracked_camera and "tracking_target" in tracked_camera:
			tracked_camera.tracking_target = top_segment
			
		for node in tracked_visuals:
			if node != null and node != tracked_camera:
				if visual_y_offsets.has(node):
					var base_y = visual_y_offsets[node]
					var local_target = parent_body.to_local(top_segment.global_position)
					node.position.x = local_target.x
					node.position.z = local_target.z
					node.position.y = local_target.y + base_y
