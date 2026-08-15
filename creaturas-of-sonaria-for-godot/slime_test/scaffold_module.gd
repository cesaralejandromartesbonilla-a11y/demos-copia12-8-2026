extends Node3D
class_name ScaffoldModule

signal spring_jump_triggered(jump_velocity: Vector3)

# ==========================================
# SELECTOR DE MÉTODOS DE FUERZA (FINALISTAS)
# ==========================================
enum ForceMethod {
	BEZIER_CURVE,        # Opción  3: Forma Matemática Pura, finalista 1
	PUPPET_TRACTION,     # Opción  5: Tirón Lineal (Actua como tentáculo o cuerda), finalista 2
	PD_TORQUE_SPRING,    # Opción  7: Músculo Activo (Máxima estabilidad y fuerza), finalista 3
	PARABOLIC_PD_CURVE,  # Opción  8: Parábola Física por Puntos de Control (Peso y Gravedad), finalista 4
	VERTEBRAL_KINEMATICS,# Opción  9: Sistema Vertebral (Látigo de abajo hacia arriba), finalista 5
	AERODYNAMIC_DRAG,    # Opción 10: Concepto B (Fricción de Viento) este es muy exagerado tanto como si lo empujara un huracan
	PURE_ANGULAR_SPRING  # Opción 11: Concepto C (Muelle Angular Puro sin tirones), finalista 6
}

@export_group("Sistema de Propagación")
@export var current_method: ForceMethod = ForceMethod.PD_TORQUE_SPRING

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

@export_group("Ajustes de Parábola (Método 4)")
@export var parabola_manual_control: Vector3 = Vector3(0.0, -0.2, -0.1)  # Sesgo local (ej: encorvar la columna hacia atrás/abajo por defecto)
@export var parabola_inertia_influence: float = 0.08                     # Cuánto se deforma la "panza" al moverte rápido (retraso físico)
@export var parabola_gravity_influence: float = 0.6                      # Fuerza con la que cuelga la columna hacia abajo (sensación de peso)

@export_group("Ajustes Vertebrales (Método 9)")
## Dibuja aquí la fuerza: X=0 (Recto), X=1 (Suelo). Y=0 (Mínima fuerza), Y=1 (Máxima fuerza)
@export var vertebral_force_curve: Curve
@export var vertebral_max_multiplier: float = 10.0 # Cuánta fuerza es el Y=1 de tu curva

@export_group("Visuales del Andamio")
@export var scaffold_material: Material

@export_group("Control del Núcleo")
@export var core_jump_bonus: float = 1.5 # Hasta 150% de fuerza extra si bajas el núcleo al máximo
var core_target_index: int = 0
var base_masses: Array[float] = [] # Memoria para guardar el peso original

@export_group("Sistema de Impacto y Estrés")
## Cuánta aceleración/frenazo se considera un impacto brusco. Ajusta según la velocidad de tu slime.
@export var impact_threshold: float = 15.0 
## Cuánta fuerza muscular pierde al recibir el primer impacto (0.0 = nada, 1.0 = flacidez total).
@export var flaccidity_per_impact: float = 0.8
var stress_level: float = 0.0
var last_parent_velocity: Vector3 = Vector3.ZERO
var target_flaccidity: float = 0.0   # La flacidez que el impacto ordenó
var current_flaccidity: float = 0.0  # La flacidez REAL suavizada
var target_stress: float = 0.0       # El estrés que el impacto ordenó
var current_stress: float = 0.0      # El estrés REAL suavizado
var segment_force_memory: Array[float] = [] # Memoria muscular individual por hueso

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
		var original_mass = (1.0 - (float(i) * 0.05)) * mass_scale
		rb.mass = original_mass
		base_masses.append(original_mass)
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
		if scaffold_material != null:mesh.material = scaffold_material
		else:
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
	core_target_index = scaffold_segments.size() - 1
	_update_core_mass()

func _input(event: InputEvent) -> void:
	if not is_active or scaffold_segments.is_empty(): return
	
	var changed = false
	# Detectamos si se pulsa una tecla de forma limpia (sin spam)
	if event is InputEventKey and event.pressed and not event.echo:
		# Tecla Numpad "-" o el guión normal
		if event.keycode == KEY_KP_SUBTRACT or event.keycode == KEY_MINUS:
			core_target_index -= 1
			changed = true
		# Tecla Numpad "+" o el Más normal
		elif event.keycode == KEY_KP_ADD or event.keycode == KEY_PLUS:
			core_target_index += 1
			changed = true
			
	if changed:
		# Evitamos que el núcleo se salga del andamio
		core_target_index = clamp(core_target_index, 0, scaffold_segments.size() - 1)
		_update_core_mass()

func _update_core_mass() -> void:
	for i in range(scaffold_segments.size()):
		var rb = scaffold_segments[i]
		if is_instance_valid(rb):
			if i == core_target_index:
				rb.mass = base_masses[i] * 1.30 # Le añadimos un 30% extra de peso al eslabón actual
			else:
				rb.mass = base_masses[i]

func deactivate_scaffold() -> void:
	if not is_active: return
	if scaffold_segments.size() > 0:
		# 1. Identificamos el eslabón donde está el núcleo y guardamos su posición 3D
		var core_segment = scaffold_segments[core_target_index]
		var target_global_pos = core_segment.global_position
		
		# 2. DESTRUIMOS las colisiones de todo el andamio ANTES de mover al slime
		# Esto evita que el motor de físicas explote por superposición
		for rb in scaffold_segments:
			if is_instance_valid(rb):
				rb.collision_layer = 0 # Apagamos colisiones
				rb.collision_mask = 0
				rb.queue_free()
		
		scaffold_segments.clear()
		base_masses.clear()
		
		# 3. Teletransportamos al slime de forma segura (si no está en la base)
		if core_target_index > 0:
			parent_body.global_position = target_global_pos
			# Forzamos la velocidad a 0 para que no herede impulsos fantasmas
			parent_body.velocity = Vector3.ZERO
			
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
	base_masses.clear()

# ==========================================
# 🧠 BUCLE FÍSICO PRINCIPAL
# ==========================================
func _physics_process(delta: float) -> void:
	if not is_active or not is_instance_valid(parent_body):
		magnet_tilt = magnet_tilt.lerp(Vector2.ZERO, delta * 10.0)
		magnet_velocity = Vector2.ZERO
		return
		
	# 🧲 1. PROCESAR EL IMÁN (PUNTA)
	var parent_vel = parent_body.velocity
	var movement_inertia = Vector2(-parent_vel.x, -parent_vel.z) * magnet_inertia_pull
	
	var spring_force = -magnet_stiffness * magnet_tilt
	var damping_force = -magnet_damping * magnet_velocity
	var total_accel = spring_force + damping_force + movement_inertia
	
	magnet_velocity += total_accel * delta
	magnet_tilt += magnet_velocity * delta
	magnet_velocity = magnet_velocity.limit_length(20.0) 
	magnet_tilt = magnet_tilt.limit_length(1.2)
	
	var base_up = parent_body.global_transform.basis.y.normalized()
	var target_forward = parent_body.global_transform.basis.x.normalized()
	var total_segments = scaffold_segments.size()
	
	var current_vel = parent_body.velocity
	var acceleration = (current_vel - last_parent_velocity).length() / delta
	last_parent_velocity = current_vel
	
	if acceleration > impact_threshold:
		# El impacto sube el objetivo de estrés instantáneamente
		target_stress = min(target_stress + 0.35, 1.0)
		# La flacidez se calcula basada en el estrés ACTUAL (el cual va con retardo)
		var applied_flaccidity = flaccidity_per_impact * (1.0 - current_stress)
		target_flaccidity = max(target_flaccidity, applied_flaccidity)
		
	# Drenado natural de los objetivos (El estrés tarda 5s en ir de 1.0 a 0.0)
	target_stress = move_toward(target_stress, 0.0, delta * 0.2)
	target_flaccidity = move_toward(target_flaccidity, 0.0, delta * 0.6)
	
	# ⏳ SUAVIZADO 1: ESTRÉS (Sube con retardo, baja al ritmo del objetivo)
	if current_stress < target_stress:
		current_stress = move_toward(current_stress, target_stress, delta * 3.0) # Tarda ~0.3s en hacer efecto
	else:
		current_stress = target_stress
		
	# ⏳ SUAVIZADO 2: FLACIDEZ (Tarda exactamente 0.5s en "derretirse")
	if current_flaccidity < target_flaccidity:
		current_flaccidity = move_toward(current_flaccidity, target_flaccidity, delta * 2.0) # (1.0 / 0.5s = 2.0)
	else:
		current_flaccidity = target_flaccidity
	
	# 🦾 2. DISTRIBUIR FUERZAS A TRAVÉS DE LOS MÉTODOS MODULARES
	for i in range(total_segments):
		var rb = scaffold_segments[i]
		if not is_instance_valid(rb): continue
		
		rb.sleeping = false 
		
		match current_method:
			ForceMethod.BEZIER_CURVE:
				_apply_bezier_curve(rb, i, total_segments, base_up, target_forward)
			ForceMethod.PUPPET_TRACTION:
				_apply_puppet_traction(rb, i, total_segments, base_up, target_forward)
			ForceMethod.PD_TORQUE_SPRING:
				_apply_pd_torque_spring(rb, i, total_segments, base_up, target_forward)
			ForceMethod.PARABOLIC_PD_CURVE:
				_apply_parabolic_pd_curve(rb, i, total_segments, base_up, target_forward)
			ForceMethod.VERTEBRAL_KINEMATICS:
				_apply_vertebral_kinematics(rb, i, total_segments, base_up, target_forward, delta)
			ForceMethod.AERODYNAMIC_DRAG:
				_apply_aerodynamic_drag(rb, i, total_segments, base_up, target_forward)
			ForceMethod.PURE_ANGULAR_SPRING:
				_apply_pure_angular_spring(rb, i, total_segments, base_up, target_forward)
	
	# 🎥 3. ACOPLE INDEPENDIENTE DE VISUALES
	if total_segments > 0:
		var top_segment = scaffold_segments.back()
		if tracked_camera and "tracking_target" in tracked_camera:
			tracked_camera.tracking_target = top_segment
			
		for node in tracked_visuals:
			if node != null and node != tracked_camera and visual_y_offsets.has(node):
				var base_y = visual_y_offsets[node]
				var local_target = parent_body.to_local(top_segment.global_position)
				node.position.x = local_target.x
				node.position.z = local_target.z
				node.position.y = local_target.y + base_y

# ==========================================
# ⚙️ MÓDULOS DE FÍSICA ESPECÍFICOS
# ==========================================

func _apply_bezier_curve(rb: RigidBody3D, index: int, total: int, base_up: Vector3, target_forward: Vector3) -> void:
	var total_height = total * 0.6
	var p0 = global_position 
	var p1 = global_position + (base_up * (total_height * 0.5)) 
	var p2 = global_position + (base_up * total_height) + Vector3(magnet_tilt.x, 0, magnet_tilt.y) 
	
	var t = float(index + 1) / float(total)
	var tangent = (2.0 * (1.0 - t) * (p1 - p0)) + (2.0 * t * (p2 - p1))
	var target_up = tangent.normalized()
	
	var current_up = rb.global_transform.basis.y.normalized()
	var current_forward = rb.global_transform.basis.x.normalized()
	var root_focus = lerp(0.2, 1.0, float(total - index) / float(total))
	
	var alignment_axis = current_up.cross(target_up)
	var angle_deg = rad_to_deg(current_up.angle_to(target_up))
	var panic_weight = clamp((angle_deg - 10.0) / 15.0, 0.0, 1.0)
	var force_multiplier = lerp(8.0, 80.0, panic_weight)
	
	rb.angular_damp = lerp(scaffold_angular_damp, 18.0, panic_weight)
	
	var err_len = alignment_axis.length()
	if err_len > 0.001:
		var raw_torque = alignment_axis.normalized() * (err_len * base_straighten_force * root_focus * force_multiplier)
		rb.apply_torque(raw_torque.limit_length(max_muscle_torque))
		
	var twist_axis = current_forward.cross(target_forward)
	var twist_error = twist_axis.dot(target_up) 
	if abs(twist_error) > 0.001:
		var raw_twist = target_up * (twist_error * base_twist_force * root_focus)
		rb.apply_torque(raw_twist.limit_length(max_muscle_torque / 2.0))

func _apply_puppet_traction(rb: RigidBody3D, index: int, total: int, base_up: Vector3, target_forward: Vector3) -> void:
	var current_up = rb.global_transform.basis.y.normalized()
	var current_forward = rb.global_transform.basis.x.normalized()
	var root_focus = lerp(0.2, 1.0, float(total - index) / float(total))
	
	var total_height = total * 0.6
	var target_tip_pos = global_position + (base_up * total_height) + Vector3(magnet_tilt.x, 0, magnet_tilt.y)
	
	# Fuerza Central lineal en la punta
	if index == total - 1:
		var pull_vector = target_tip_pos - rb.global_position
		var distance = pull_vector.length()
		if distance > 0.01:
			var traction_force = pull_vector.normalized() * (distance * base_straighten_force * 25.0)
			rb.apply_central_force(traction_force.limit_length(max_muscle_torque * 2.0))
	
	rb.angular_damp = 2.0 
	
	# Antitorsión mínima para permitir colgar
	var twist_axis = current_forward.cross(target_forward)
	var twist_error = twist_axis.dot(current_up) # Comparamos con su propio UP para no forzar rectitud
	if abs(twist_error) > 0.001:
		var raw_twist = current_up * (twist_error * (base_twist_force * 0.1) * root_focus)
		rb.apply_torque(raw_twist.limit_length(max_muscle_torque / 2.0))

func _apply_pd_torque_spring(rb: RigidBody3D, index: int, total: int, base_up: Vector3, target_forward: Vector3) -> void:
	var sway_offset = Vector3(magnet_tilt.x, 0, magnet_tilt.y)
	var target_up = (base_up + sway_offset).normalized()
	
	var current_up = rb.global_transform.basis.y.normalized()
	var current_forward = rb.global_transform.basis.x.normalized()
	var root_focus = lerp(0.2, 1.0, float(total - index) / float(total))
	
	# Desactivamos el damp de Godot. PD asume el control del freno.
	rb.angular_damp = 0.2 
	
	var alignment_axis = current_up.cross(target_up)
	var err_len = alignment_axis.length()
	
	if err_len > 0.001:
		var p_term = alignment_axis.normalized() * (err_len * base_straighten_force * 4.0 * root_focus)
		var d_term = rb.angular_velocity * (scaffold_angular_damp * 0.8 * root_focus)
		var raw_torque = p_term - d_term
		rb.apply_torque(raw_torque.limit_length(max_muscle_torque))
		
	var twist_axis = current_forward.cross(target_forward)
	var twist_error = twist_axis.dot(target_up) 
	
	if abs(twist_error) > 0.001:
		var p_twist = target_up * (twist_error * base_twist_force * 3.0 * root_focus)
		var d_twist = rb.angular_velocity.project(target_up) * (scaffold_angular_damp * 0.5 * root_focus)
		var raw_twist = p_twist - d_twist
		rb.apply_torque(raw_twist.limit_length(max_muscle_torque / 2.0))

func _apply_parabolic_pd_curve(rb: RigidBody3D, index: int, total: int, base_up: Vector3, target_forward: Vector3) -> void:
	var total_height = total * 0.6
	
	# PUNTOS GUÍA EN EL ESPACIO
	var p0 = global_position # Base
	var p2 = global_position + (base_up * total_height) + Vector3(magnet_tilt.x, 0, magnet_tilt.y) # Imán
	
	# PUNTO DE CONTROL (P1) DINÁMICO
	var p_mid = (p0 + p2) * 0.5
	var dynamic_offset = Vector3.ZERO
	if is_instance_valid(parent_body):
		dynamic_offset -= parent_body.velocity * parabola_inertia_influence
		dynamic_offset += parent_body.global_transform.basis * parabola_manual_control
	dynamic_offset += Vector3.DOWN * parabola_gravity_influence
	var p1 = p_mid + dynamic_offset
	
	# IDENTIFICAMOS LOS ESLABONES CLAVE
	var mid_index = int(total / 2.0) # Eslabón central (Ej: Si hay 6, es el 3)
	var tip_index = total - 1        # Eslabón final (Ej: Si hay 6, es el 5)
	
	var root_focus = lerp(0.2, 1.0, float(total - index) / float(total))
	
	# ------------------------------------------------------------------
	# 🧲 1. EFECTORES ESPACIALES (Tracción Lineal SOLO en Puntos Clave)
	# ------------------------------------------------------------------
	# En lugar de obligar a todos a seguir la línea, solo jalamos 2 huesos.
	# Los demás colgarán físicamente entre ellos.
	if index == mid_index:
		# El centro es jalado hacia P1 (La Panza)
		var pull_vector = p1 - rb.global_position
		rb.apply_central_force(pull_vector * (base_straighten_force * 25.0 * root_focus))
	elif index == tip_index:
		# La punta es jalada hacia P2 (El Imán)
		var pull_vector = p2 - rb.global_position
		rb.apply_central_force(pull_vector * (base_straighten_force * 15.0 * root_focus))
	
	# ------------------------------------------------------------------
	# 🦾 2. MUSCULATURA ROTACIONAL (Torque PD para mantener la forma)
	# ------------------------------------------------------------------
	# Calculamos hacia dónde debería "mirar" este hueso usando la derivada de la curva
	var t = float(index + 1) / float(total)
	var tangent = (2.0 * (1.0 - t) * (p1 - p0)) + (2.0 * t * (p2 - p1))
	var target_up = tangent.normalized()
	
	var current_up = rb.global_transform.basis.y.normalized()
	var current_forward = rb.global_transform.basis.x.normalized()
	
	var active_force_multiplier: float = 1.0
	rb.angular_damp = 0.2
	
	# Relajación de la mitad superior (si no se dobla demasiado, se apaga)
	if index > mid_index:
		var angle_to_slime = current_up.angle_to(base_up)
		var tip_angle_limit = deg_to_rad(35.0)
		
		if angle_to_slime < tip_angle_limit:
			target_up = current_up # Modo relajado (no intenta rotar)
			active_force_multiplier = 0.0
			rb.angular_damp = 1.5  # Amortiguación de cuerda suelta
		else:
			target_up = base_up # Modo corrección
			active_force_multiplier = clamp((angle_to_slime - tip_angle_limit) * 4.0, 0.5, 2.0)
	
	# --- APLICACIÓN DE FUERZAS PD ---
	var alignment_axis = current_up.cross(target_up)
	var err_len = alignment_axis.length()
	
	if err_len > 0.001 and active_force_multiplier > 0.0:
		var p_term = alignment_axis.normalized() * (err_len * base_straighten_force * 4.0 * root_focus * active_force_multiplier)
		var d_term = rb.angular_velocity * (scaffold_angular_damp * 0.8 * root_focus)
		var raw_torque = p_term - d_term
		rb.apply_torque(raw_torque.limit_length(max_muscle_torque))
		
	var twist_axis = current_forward.cross(target_forward)
	var twist_error = twist_axis.dot(target_up) 
	
	if abs(twist_error) > 0.001 and active_force_multiplier > 0.0:
		var p_twist = target_up * (twist_error * base_twist_force * 3.0 * root_focus * active_force_multiplier)
		var d_twist = rb.angular_velocity.project(target_up) * (scaffold_angular_damp * 0.5 * root_focus)
		var raw_twist = p_twist - d_twist
		rb.apply_torque(raw_twist.limit_length(max_muscle_torque / 2.0))

func _apply_vertebral_kinematics(rb: RigidBody3D, index: int, total: int, base_up: Vector3, target_forward: Vector3, delta: float) -> void:
	var target_up: Vector3
	
	if index == 0:
		var sway_offset = Vector3(magnet_tilt.x, 0, magnet_tilt.y)
		target_up = (base_up + sway_offset).normalized()
	else:
		var prev_rb = scaffold_segments[index - 1]
		target_up = prev_rb.global_transform.basis.y.normalized()
		
	var current_up = rb.global_transform.basis.y.normalized()
	var current_forward = rb.global_transform.basis.x.normalized()
	
	var angle_to_base = current_up.angle_to(base_up)
	var normalized_angle = clamp(angle_to_base / (PI * 0.5), 0.0, 1.0) 
	
	# 1. Calculamos la fuerza matemática cruda (El Objetivo)
	var target_force_mult = 1.0
	if vertebral_force_curve != null:
		var curve_y = vertebral_force_curve.sample(normalized_angle)
		target_force_mult = lerp(0.02, vertebral_max_multiplier, curve_y)
	else:
		target_force_mult = lerp(0.02, 10.0, smoothstep(0.0, 1.0, normalized_angle))
		
	# 2. Le aplicamos la flacidez (que ya viene suavizada del physics_process)
	target_force_mult *= (1.0 - current_flaccidity)
	
	# ---------------------------------------------------------
	# ⏳ SUAVIZADO 3: MEMORIA DE FUERZA (LOW-PASS FILTER)
	# ---------------------------------------------------------
	# Nos aseguramos de que el array tenga espacio para este eslabón (Autorelleno)
	while segment_force_memory.size() <= index:
		segment_force_memory.append(0.02)
		
	# Recuperamos la fuerza que tenía este hueso en el frame anterior
	var current_force_mult = segment_force_memory[index]
	
	# Transición fluida: Ni da, ni quita fuerza de golpe. (El 12.0 es la velocidad de respuesta)
	current_force_mult = lerp(current_force_mult, target_force_mult, delta * 12.0)
	
	# Guardamos la nueva fuerza suavizada para usarla en el siguiente frame
	segment_force_memory[index] = current_force_mult 
	# ---------------------------------------------------------
	
	var root_focus = lerp(0.2, 1.0, float(total - index) / float(total))
	rb.angular_damp = scaffold_angular_damp * 0.15
	
	# --- APLICACIÓN DE FUERZAS PD ---
	var alignment_axis = current_up.cross(target_up)
	var err_len = alignment_axis.length()
	
	if err_len > 0.001:
		# USAMOS current_force_mult (la suavizada), no la matemática cruda
		var p_term = alignment_axis.normalized() * (err_len * base_straighten_force * 4.0 * root_focus * current_force_mult)
		var d_term = rb.angular_velocity * (scaffold_angular_damp * 0.8 * root_focus)
		var raw_torque = p_term - d_term
		rb.apply_torque(raw_torque.limit_length(max_muscle_torque))
		
	var twist_axis = current_forward.cross(target_forward)
	var twist_error = twist_axis.dot(current_up) 
	
	if abs(twist_error) > 0.001:
		var p_twist = current_up * (twist_error * base_twist_force * 3.0 * root_focus * current_force_mult)
		var d_twist = rb.angular_velocity.project(current_up) * (scaffold_angular_damp * 0.5 * root_focus)
		var raw_twist = p_twist - d_twist
		rb.apply_torque(raw_twist.limit_length(max_muscle_torque / 2.0))

func _apply_aerodynamic_drag(rb: RigidBody3D, index: int, total: int, base_up: Vector3, target_forward: Vector3) -> void:
	# 1️⃣ EL OBJETIVO: Todo el andamio intenta estar 100% recto hacia arriba siempre.
	var target_up = base_up
	
	var current_up = rb.global_transform.basis.y.normalized()
	var current_forward = rb.global_transform.basis.x.normalized()
	
	# root_focus da más fuerza muscular a la base. height_factor da más "viento" a la punta.
	var root_focus = lerp(0.2, 1.0, float(total - index) / float(total))
	var height_factor = float(index + 1) / float(total) 
	
	rb.angular_damp = 0.2 
	
	# ------------------------------------------------------------------
	# 🌪️ 2. EL VIENTO (Fricción Aerodinámica)
	# ------------------------------------------------------------------
	if is_instance_valid(parent_body):
		var slime_vel = parent_body.velocity
		# Ignoramos la velocidad Y para evitar que el andamio se aplaste al saltar/caer
		var horizontal_vel = Vector3(slime_vel.x, 0, slime_vel.z)
		
		if horizontal_vel.length() > 0.1:
			# Aplicamos una fuerza lineal exactamente opuesta a la dirección de movimiento.
			# Multiplicador 3.0 es la "densidad del aire".
			var drag_force = -horizontal_vel * (height_factor * base_straighten_force * 3.0)
			# Aplicamos el viento, limitado para no romper las físicas a velocidades extremas
			rb.apply_central_force(drag_force.limit_length(max_muscle_torque))
			
	# ------------------------------------------------------------------
	# 🦾 3. MUSCULATURA ROTACIONAL (Torque PD luchando contra el viento)
	# ------------------------------------------------------------------
	var alignment_axis = current_up.cross(target_up)
	var err_len = alignment_axis.length()
	
	if err_len > 0.001:
		var p_term = alignment_axis.normalized() * (err_len * base_straighten_force * 4.0 * root_focus)
		var d_term = rb.angular_velocity * (scaffold_angular_damp * 0.8 * root_focus)
		var raw_torque = p_term - d_term
		rb.apply_torque(raw_torque.limit_length(max_muscle_torque))
		
	var twist_axis = current_forward.cross(target_forward)
	var twist_error = twist_axis.dot(target_up) 
	
	if abs(twist_error) > 0.001:
		var p_twist = target_up * (twist_error * base_twist_force * 3.0 * root_focus)
		var d_twist = rb.angular_velocity.project(target_up) * (scaffold_angular_damp * 0.5 * root_focus)
		var raw_twist = p_twist - d_twist
		rb.apply_torque(raw_twist.limit_length(max_muscle_torque / 2.0))

func _apply_pure_angular_spring(rb: RigidBody3D, index: int, total: int, base_up: Vector3, target_forward: Vector3) -> void:
	var current_up = rb.global_transform.basis.y.normalized()
	var current_forward = rb.global_transform.basis.x.normalized()
	
	var sway_offset = Vector3.ZERO
	if is_instance_valid(parent_body):
		var vel = parent_body.velocity
		sway_offset = Vector3(-vel.x, 0, -vel.z) * 0.06 
		
	var target_up = (base_up + sway_offset).normalized()
	
	# CURVA DE FUERZA SIMPLIFICADA (2% en el centro a 1000% en el suelo)
	var angle_to_base = current_up.angle_to(base_up)
	var normalized_angle = clamp(angle_to_base / (PI * 0.5), 0.0, 1.0)
	var smooth_factor = smoothstep(0.0, 1.0, normalized_angle)
	
	# Transición ultrasuave: 0.02 (2%) hasta 10.0 (1000%)
	var force_mult = lerp(0.02, 10.0, smooth_factor)
	
	var root_focus = float(total - 1 - index) / float(total - 1)
	var stiffness_multiplier = pow(root_focus, 2.0) 
	
	# Amortiguación natural según la altura de la cadena
	rb.angular_damp = lerp(1.5, 0.2, root_focus)
	
	# --- APLICACIÓN DE FUERZAS PD ---
	var alignment_axis = current_up.cross(target_up)
	var err_len = alignment_axis.length()
	
	if err_len > 0.001 and stiffness_multiplier > 0.01:
		var p_term = alignment_axis.normalized() * (err_len * base_straighten_force * 8.0 * stiffness_multiplier * force_mult)
		var d_term = rb.angular_velocity * (scaffold_angular_damp * root_focus)
		var raw_torque = p_term - d_term
		rb.apply_torque(raw_torque.limit_length(max_muscle_torque))
		
	var twist_axis = current_forward.cross(target_forward)
	# Usamos current_up en lugar de target_up para que el hueso no gire en hélice sobre sí mismo
	var twist_error = twist_axis.dot(current_up) 
	
	if abs(twist_error) > 0.001 and stiffness_multiplier > 0.01:
		var p_twist = current_up * (twist_error * base_twist_force * 4.0 * stiffness_multiplier * force_mult)
		var d_twist = rb.angular_velocity.project(current_up) * (scaffold_angular_damp * 0.5 * root_focus)
		var raw_twist = p_twist - d_twist
		rb.apply_torque(raw_twist.limit_length(max_muscle_torque / 2.0))
