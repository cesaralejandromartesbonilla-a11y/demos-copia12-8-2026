extends CharacterBody3D

# ==========================================
# 🧩 MÓDULOS CONECTADOS
# ==========================================
@onready var camera_controller: CameraController = $CameraPivot
@onready var locomotion: LocomotionController = $LocomotionController
@onready var health: HealthComponent = $HealthComponent
@onready var form_controller: FormController = $FormController
@onready var mass_manager: MassManager = $MassManager
@onready var matter_controller: MatterController = $MatterController

# ==========================================
# 📦 REFERENCIAS A NODOS INTERNOS
# ==========================================
@onready var form_label = $HUD/PanelContainer/Label
@onready var visuals = $MassManager/LiquidMassMesh
@onready var collision_shape = $CollisionShape3D
@onready var anim_player = $AnimationPlayer
@onready var consumer = $ConsumerComponent
@onready var transformation_module = $TransformationModule
@onready var aim_ik_coordinator = $AimIKCoordinator
@onready var modular_hands_inventory = $InternalInventory
@onready var hold_position = $HoldPosition
@onready var magic_inventory = $MagicInventory
@onready var liquid_volume_area = $MassManager/LiquidVolumeArea
@onready var projectile_manager = $ProjectileManager
@onready var hud_label = $HUD/PanelContainer/Label

# ==========================================
# 📊 VARIABLES DE ESTADO PROPIAS DEL CUERPO
# ==========================================
var core_scale: Vector3 = Vector3.ONE # NUNCA cambia de tamaño
var current_liquid_scale: float = 1.0 # Dicta el tamaño visual y de inercia
var base_visual_scale: Vector3 = Vector3.ONE
var default_col_radius: float = 0.5
var default_col_height: float = 1.0
var current_element: String = "BASE"
var current_custom_material: Material = null
var current_form: int = 0
var is_build_mode: bool = false
var step_cycle: float = 0.0
var visual_base_y: float = 0.0
var base_speed: float = 5.0
var base_accel: float = 10.0
var is_grabbing: bool = false
var slingshot_charge: float = 0.0
var launch_momentum_time: float = 0.0
var cancel_lock: bool = false

# ==========================================
# FÍSICAS DEL PÉNDULO
# ==========================================
@export_group("Físicas del Péndulo")
@export var spring_stiffness: float = 80.0 ## Fuerza que lo empuja a estar recto
@export var damping: float = 6.0 ## Fricción para que no oscile infinitamente
@export var gravity_influence: float = 25.0 ## Cuánto le afecta la inclinación del suelo
@export var inertia_influence: float = 0.8 ## Cuánto le afecta tu propio movimiento

var tilt_velocity: Vector2 = Vector2.ZERO

@export_group("Andamio Físico Activo")
@export var base_straighten_force: float = 45.0 # Fuerza base para enderezarse
@export var base_twist_force: float = 20.0      # Evita rotaciones extrañas
@export var scaffold_angular_damp: float = 7.0  # Freno para evitar temblores rápidos

# Control interno de la estructura física
var scaffold_segments: Array[RigidBody3D] = []
var scaffold_joints: Array[ConeTwistJoint3D] = []
var scaffold_base_static: StaticBody3D = null
var is_scaffold_active: bool = false

@export_group("Imán del Andamio")
@export var magnet_stiffness: float = 35.0   # Qué tan rápido intenta volver al centro
@export var magnet_damping: float = 4.0      # Freno del imán para que no se balancee infinitamente
@export var magnet_inertia_pull: float = 1.5 # Qué tanto le afecta tu movimiento (WASD)
@export var max_muscle_torque: float = 120.0

var magnet_tilt: Vector2 = Vector2.ZERO
var magnet_velocity: Vector2 = Vector2.ZERO

# ==========================================
# VARIABLES DEL ANDAMIO
# ==========================================
@export_group("")
@export var ascending_nodes: Array[Node3D] 
@export var main_collision_shape: CollisionShape3D 
@export var scaffold_growth_speed: float = 6.0  ## Qué tan rápido se estira el tallo hacia arriba
@export var max_scaffold_length: float = 20.0  ## Altura máxima del tentáculo
var active_scaffold_rope: Rope3D = null  ## Instancia activa de tu sistema de cuerda
var original_node_y_positions: Dictionary = {}
var is_stretched: bool = false
var stretch_ratio: float = 0.0
var current_stretch_height: float = 0.0
# ==========================================

# Gestión de Input (Salto vs Estirar)
var space_held_time: float = 0.0
var scaffold_cooldown: float = 0.0

# Físicas de Péndulo (Desequilibrio)
var scaffold_tilt: Vector2 = Vector2.ZERO
var scaffold_angular_velocity: Vector2 = Vector2.ZERO
var max_tilt_threshold: float = 1.0 # Si la inclinación supera 1.0, el andamio colapsa

@onready var default_hold_parent = hold_position.get_parent()
@onready var default_hold_transform = hold_position.transform

# ==========================================
# 🚀 INICIALIZACIÓN
# ==========================================
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	visual_base_y = visuals.position.y
	
	if collision_shape.shape is CapsuleShape3D:
		default_col_radius = collision_shape.shape.radius
		default_col_height = collision_shape.shape.height
	elif collision_shape.shape is SphereShape3D:
		default_col_radius = collision_shape.shape.radius

	# Conexiones de HP (Núcleo)
	if health:
		health.died.connect(_on_player_died)
	
	# Conexiones de Masa (Líquida)
	if mass_manager:
		mass_manager.mass_scale_changed.connect(_on_mass_scale_changed)
		mass_manager.liquid_mass_depleted.connect(_on_liquid_mass_depleted)
		
	if locomotion:
		base_speed = locomotion.speed
		base_accel = locomotion.acceleration
	for node in ascending_nodes:
		if node != null:
			original_node_y_positions[node] = node.position.y
	await get_tree().process_frame # Esperamos un frame para que todo cargue
	if mass_manager:
		_on_mass_scale_changed(mass_manager.current_mass_level)
		
	# Restauramos la cápsula a su estado puro
	if main_collision_shape and main_collision_shape.shape is CapsuleShape3D:
		var capsule = main_collision_shape.shape as CapsuleShape3D
		capsule.height = default_col_height
		main_collision_shape.position.y = 0.0

# ==========================================
# 🎮 INPUT Y CONTROL
# ==========================================
func _input(event):
	if camera_controller: camera_controller.handle_input(event, is_build_mode)
	if event.is_action_pressed("press_r"):
		if consumer and consumer.held_item != null: consumer.cycle_held_item(1)
		elif form_controller: form_controller.cycle_form(1)

	elif event.is_action_pressed("press_q"):
		if consumer and consumer.held_item != null: consumer.cycle_held_item(-1)
		elif form_controller: form_controller.cycle_form(-1)
	if event.is_action_pressed("press_c"): 
		if projectile_manager: 
			projectile_manager.fire()

	if event.is_action_pressed("press_g"):
		if projectile_manager: 
			projectile_manager.cycle_next_projectile()
			
			# Opcional: Actualizar tu UI
			if hud_label: hud_label.text = "Munición: " + str(ProjectileManager.ProjType.keys()[projectile_manager.current_projectile_type])
			
	if event.is_action_pressed("null"): 
		if matter_controller: matter_controller.shed_shell_as_item()

	if event.is_action_pressed("press_clickDE"): 
		_try_grapple_to_node()

# ==========================================
# ⚙️ FÍSICAS Y MOVIMIENTO
# ==========================================

func _physics_process(delta):
	if not locomotion: return

	var input_dir = Input.get_vector("press_a", "press_d", "press_w", "press_s")
	
	var space_pressed = Input.is_action_pressed("press_space")
	var space_released = Input.is_action_just_released("press_space")
	var shift_pressed = Input.is_action_pressed("press_shift")
	var shift_released = Input.is_action_just_released("press_shift")
	
	if launch_momentum_time > 0.0:
		launch_momentum_time -= delta
		
	if scaffold_cooldown > 0.0:
		scaffold_cooldown -= delta

	# ==========================================
	# 1. 🕷️ EL AGARRE Y LA RESORTERA (Invertida)
	# ==========================================
	var is_touching_surface = is_on_floor() or is_on_wall() or is_on_ceiling()
	
	# Si estamos saliendo disparados, desactivamos el agarre por la fuerza
	if launch_momentum_time > 0.0:
		is_grabbing = false 
	else:
		is_grabbing = shift_pressed and is_touching_surface

	if is_grabbing:
		is_stretched = false 
		stretch_ratio = 0.0 
		current_stretch_height = 0.0
		
		# Anclaje de resortera
		velocity = velocity.lerp(Vector3.ZERO, delta * 15.0) 
		
		# CARGA:
		if space_pressed:
			slingshot_charge = move_toward(slingshot_charge, 1.0, delta * 1.0)
			if visuals:
				visuals.scale.y = lerp(visuals.scale.y, base_visual_scale.y * 0.4, delta * 5.0)
				visuals.position.x = randf_range(-0.05, 0.05) * slingshot_charge
		else:
			slingshot_charge = move_toward(slingshot_charge, 0.0, delta * 5.0)

	# 🚀 DISPARO (Soltar Shift)
	if shift_released and slingshot_charge > 0.1:
		var launch_dir = Vector3.UP 
		if camera_controller and camera_controller.has_method("get_aim_direction"):
			launch_dir = (camera_controller.get_aim_direction() + Vector3(0, 1.0, 0)).normalized()
		
		var base_power = 20.0 
		var launch_force = base_power * (0.8 + (slingshot_charge * 1.5))
		
		global_position.y += 0.2 
		velocity = launch_dir * launch_force
		launch_momentum_time = 0.5 
		
		if slingshot_charge > 0.8:
			_leave_puddle_under_feet(1.0) 
			
		slingshot_charge = 0.0
		is_grabbing = false
		
	elif not is_grabbing:
		slingshot_charge = move_toward(slingshot_charge, 0.0, delta * 5.0)

	# ==========================================
	# 2. ⏱️ GESTIÓN DEL ANDAMIO CLÁSICO
	# ==========================================
	if space_pressed and is_on_floor() and scaffold_cooldown <= 0.0 and not is_grabbing and slingshot_charge <= 0.01:
		is_stretched = true
	else:
		is_stretched = false

	# ==========================================
	# 3. 💥 COLAPSO POR IMPACTO (Solo base)
	# ==========================================
	if is_stretched and (is_on_wall() or is_on_ceiling()):
		is_stretched = false
		scaffold_cooldown = 1.0

	# ==========================================
	# 4. 🚀 SALTO DESDE LA CIMA (Catapulta Slime)
	# ==========================================
	if space_released and current_stretch_height > 0.1:
		# Calculamos dónde estaba la cabeza meciéndose
		var top_offset_x = scaffold_tilt.x * (current_stretch_height * 0.4)
		var top_offset_z = scaffold_tilt.y * (current_stretch_height * 0.4)
		
		# Teletransportamos la base hasta ahí arriba para saltar orgánicamente
		global_position += Vector3(top_offset_x, current_stretch_height, top_offset_z)
		
		if locomotion and "jump_velocity" in locomotion:
			var jump_power = locomotion.jump_velocity * (0.5 + (stretch_ratio * 0.8))
			velocity.y = jump_power
			
		stretch_ratio = 0.0
		current_stretch_height = 0.0
		scaffold_tilt = Vector2.ZERO
		tilt_velocity = Vector2.ZERO
		
		# Evitamos que la cámara salte bruscamente reseteando sus nodos
		for node in ascending_nodes:
			if node != null and original_node_y_positions.has(node):
				node.position = Vector3(0, original_node_y_positions[node], 0)

	# ==========================================
	# 5. 📈 CRECIMIENTO DEL TALLO (Escalado Real)
	# ==========================================
	if is_stretched:
		stretch_ratio = move_toward(stretch_ratio, 1.0, delta * 3.0)
	else:
		stretch_ratio = move_toward(stretch_ratio, 0.0, delta * 5.0)

	# 🌟 NUEVA FÓRMULA DE ALTURA: Escala agresivamente con la masa.
	# Con 1 de masa = ~6 metros. Con 5 de masa = ~25 metros.
	var max_height_capacity = 3.0 + (current_liquid_scale * 4.5) 
	current_stretch_height = max_height_capacity * stretch_ratio

	# ==========================================
	# 6. ⚖️ PÉNDULO INVERTIDO (La Bandera de Látigo Real)
	# ==========================================
	if is_stretched:
		if not is_scaffold_active:
			_spawn_physics_scaffold()
			base_straighten_force = 20.0 
			
		# ========================================================
		# 🧲 EL IMÁN VIRTUAL (Péndulo Matemático)
		# ========================================================
		var movement_inertia = Vector2(-velocity.x, -velocity.z) * magnet_inertia_pull
		
		var spring_force = -magnet_stiffness * magnet_tilt
		var damping_force = -magnet_damping * magnet_velocity
		var total_accel = spring_force + damping_force + movement_inertia
		
		magnet_velocity += total_accel * delta
		magnet_tilt += magnet_velocity * delta
		
		# 🌟 EL ARREGLO: La Correa del Imán
		# Evitamos la "Explosión de Euler". Limitamos el imán a un valor de 1.2
		# Esto garantiza que el andamio nunca intentará doblarse más allá del límite de sus Joints.
		magnet_velocity = magnet_velocity.limit_length(20.0) # Evita que gane velocidad infinita
		magnet_tilt = magnet_tilt.limit_length(1.2)          # Evita que pida ángulos imposibles
		
		# ========================================================
		# 🦾 MUSCULATURA FÍSICA (Persiguiendo al Imán)
		# ========================================================
		var base_up = global_transform.basis.y.normalized()
		# Inclinamos el concepto de "Arriba" basándonos en dónde está el imán
		var sway_offset = Vector3(magnet_tilt.x, 0, magnet_tilt.y)
		var target_up = (base_up + sway_offset).normalized()
		var target_forward = global_transform.basis.x.normalized()
		
		for i in range(scaffold_segments.size()):
			var rb = scaffold_segments[i]
			if is_instance_valid(rb):
				rb.sleeping = false 
				
				var height_factor = float(scaffold_segments.size() - i) / float(scaffold_segments.size())
				var root_focus = lerp(0.2, 1.0, height_factor) 
				
				# --- 1. FUERZA VERTICAL HACIA EL IMÁN ---
				var current_up = rb.global_transform.basis.y.normalized()
				var alignment_axis = current_up.cross(target_up)
				var angle_error = current_up.angle_to(target_up) 
				
				# Convertimos a grados para que sea más fácil pensar en los límites
				var angle_deg = rad_to_deg(angle_error)
				
				# 1. Definimos el Peso del Pánico (0.0 es relajado, 1.0 es pánico total)
				# Empieza a tensarse a los 10 grados, y llega a máxima fuerza a los 25 grados.
				var panic_weight = clamp((angle_deg - 10.0) / (25.0 - 10.0), 0.0, 1.0)
				
				# 2. Transición suave (Lerp) de Fuerza y Amortiguación
				# Si weight es 0.5 (mitad del camino), multiplicará por ~44
				var force_multiplier = lerp(8.0, 80.0, panic_weight)
				
				# La amortiguación también sube poco a poco para ir frenando antes del límite
				rb.angular_damp = lerp(scaffold_angular_damp, 18.0, panic_weight)
				
				# --- Aplicamos el torque con la limitación de seguridad ---
				var alignment_error_len = alignment_axis.length()
				if alignment_error_len > 0.001:
					var raw_torque = alignment_axis.normalized() * (alignment_error_len * base_straighten_force * root_focus * force_multiplier)
					var safe_torque = raw_torque.limit_length(max_muscle_torque)
					rb.apply_torque(safe_torque)
				
				# --- 2. FUERZA ANTITORSIÓN (También Limitada) ---
				var current_forward = rb.global_transform.basis.x.normalized()
				var twist_axis = current_forward.cross(target_forward)
				var twist_error = twist_axis.dot(target_up) 
				
				if abs(twist_error) > 0.001:
					var raw_twist = target_up * (twist_error * base_twist_force * root_focus)
					# Frenamos también la torsión para que no desgarre el hueso
					var safe_twist = raw_twist.limit_length(max_muscle_torque / 2.0) 
					rb.apply_torque(safe_twist)
		
		# ==========================================
		# 🎥 ACOPLE INDEPENDIENTE DE LA CÁMARA
		# ==========================================
		if scaffold_segments.size() > 0:
			var top_segment = scaffold_segments.back()
			
			if camera_controller and "tracking_target" in camera_controller:
				camera_controller.tracking_target = top_segment
				
			for node in ascending_nodes:
				if node != null and node != camera_controller:
					if original_node_y_positions.has(node):
						var base_y = original_node_y_positions[node]
						var local_target = to_local(top_segment.global_position)
						node.position.x = local_target.x
						node.position.z = local_target.z
						node.position.y = local_target.y + base_y
	else:
		if is_scaffold_active:
			_clear_physics_scaffold()
			
		# Si soltamos el andamio, reseteamos el imán suavemente para la próxima vez
		magnet_tilt = magnet_tilt.lerp(Vector2.ZERO, delta * 10.0)
		magnet_velocity = Vector2.ZERO
	
	# 7. 🧅 DESPLAZAMIENTO DE LA CABEZA (Visuales y Cámara)
	# ==========================================
	# 🌟 EXAGERACIÓN VISUAL: Hacemos que la cámara siga el balanceo extremo
	var current_sway_x = scaffold_tilt.x * (current_stretch_height * 0.6)
	var current_sway_z = scaffold_tilt.y * (current_stretch_height * 0.6)
	
	for node in ascending_nodes:
		if node != null and original_node_y_positions.has(node):
			var base_y = original_node_y_positions[node]
			node.position.y = base_y + (current_stretch_height * 0.8)
			node.position.x = current_sway_x
			node.position.z = current_sway_z

	if main_collision_shape and main_collision_shape.shape is CapsuleShape3D:
		var capsule = main_collision_shape.shape as CapsuleShape3D
		var base_height = default_col_height * current_liquid_scale 
		
		if current_stretch_height > 0.01:
			capsule.height = base_height + current_stretch_height
			main_collision_shape.position.y = current_stretch_height / 2.0
		else:
			capsule.height = base_height
			main_collision_shape.position.y = 0.0

	# ==========================================
	# 8. 🏃 MODIFICADORES DE LOCOMOCIÓN Y VUELO
	# ==========================================
	if launch_momentum_time > 0.0:
		# Secuestro de físicas para vuelo puro
		var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
		velocity.y -= gravity * delta
		move_and_slide() 
	else:
		# Movimiento de suelo controlado por inercia
		locomotion.speed = base_speed * current_liquid_scale
		if stretch_ratio > 0.0:
			locomotion.speed *= lerp(1.0, 0.25, stretch_ratio)
		
		var inertia_factor = 1.0 / current_liquid_scale
		locomotion.acceleration = base_accel * inertia_factor
		if stretch_ratio > 0.0:
			locomotion.acceleration *= lerp(1.0, 0.15, stretch_ratio)
			
		var final_input_dir = Vector2.ZERO if is_grabbing else input_dir
		locomotion.process_movement(self, final_input_dir, false, is_build_mode, delta)

	# ==========================================
	# 9. 🎮 OTROS INPUTS Y VISUALES
	# ==========================================
	if Input.is_action_pressed("press_+"):
		if projectile_manager: projectile_manager.adjust_mass(2.0 * delta)
	elif Input.is_action_pressed("press_-"):
		if projectile_manager: projectile_manager.adjust_mass(-2.0 * delta)
	
	if camera_controller:
		camera_controller.process_camera(delta)

	if not is_grabbing: 
		_apply_procedural_animation(delta)

func _leave_puddle_under_feet(mass_to_lose: float):
	if projectile_manager == null or mass_manager == null: return
	
	if mass_manager.current_mass_level - mass_to_lose < 1.0:
		print("No hay masa suficiente para dejar charco. Núcleo en riesgo.")
		return

	print("💦 ¡Fuerza máxima! Dejando charco de resortera...")
	
	# 1. ¡CORREGIDO! Llamamos al ProjectileManager, que es el verdadero dueño de esta función
	projectile_manager._consume_mass(mass_to_lose) 
	
	# 2. Raycast hacia abajo
	var space_state = get_world_3d().direct_space_state
	var start = global_position + Vector3(0, 0.5, 0) 
	var end = start + (Vector3.DOWN * 2.0) 
	
	var query = PhysicsRayQueryParameters3D.create(start, end)
	query.exclude = [get_rid()] 
	var result = space_state.intersect_ray(query)
	
	if result:
		var splat = SplatNode.new()
		splat.add_to_group("slime_projectiles")
		
		splat.stored_mass = mass_to_lose
		if matter_controller and "current_element" in matter_controller:
			splat.stored_element = matter_controller.current_element
		
		var paint_color = Color(0.2, 0.8, 0.2)
		var custom_mat = matter_controller.current_custom_material if matter_controller and "current_custom_material" in matter_controller else null
		var base_mat = matter_controller.cached_base_liquid_mat if matter_controller and "cached_base_liquid_mat" in matter_controller else null
		
		if custom_mat != null and custom_mat is StandardMaterial3D:
			paint_color = custom_mat.albedo_color
		elif base_mat is StandardMaterial3D:
			paint_color = base_mat.albedo_color
			
		get_tree().current_scene.add_child(splat)
		splat.setup(result.position, result.normal, paint_color)

# ==========================================
# 📡 REACCIONES A MASA Y DAÑO
# ==========================================
func _on_mass_scale_changed(new_scale: float):
	current_liquid_scale = new_scale
	
	# El núcleo NO CRECE
	collision_shape.scale = core_scale 
	
	if liquid_volume_area:
		liquid_volume_area.scale = Vector3.ONE * current_liquid_scale
	
	if camera_controller:
		camera_controller.force_min_safe_zoom(5.0 + ((current_liquid_scale - 1.0) * 3.0))

func _on_liquid_mass_depleted():
	print("¡Masa líquida agotada! El núcleo está expuesto.")
	# Aquí podrías poner una animación de vulnerabilidad o deshabilitar transformaciones

func _on_player_died():
	print("El jugador ha muerto.")

func _on_form_changed(new_form: FormController.Form):
	await get_tree().create_timer(0.1).timeout
	
	if magic_inventory:
		if transformation_module and not transformation_module.allows_internal_inventory(int(new_form)):
			magic_inventory._expel_internal_inventory()
		else:
			magic_inventory._enforce_capacity_limit(int(new_form))
	
	if transformation_module: transformation_module.apply_transformation(self, new_form)
		
	collision_shape.scale = base_visual_scale
	visuals.scale = base_visual_scale
	visuals.rotation = Vector3.ZERO
	
	if form_label: form_label.text = "Forma: " + form_controller.get_form_name(new_form)
	if camera_controller:
		camera_controller.force_min_safe_zoom(5.0 + ((base_visual_scale.x - 1.0) * 6.0))

# ==========================================
# 🎨 LÓGICA VISUAL Y DE ANIMACIÓN
# ==========================================
func _apply_procedural_animation(delta):
	if not locomotion: return

	var vertical_speed = 0.0
	if locomotion.jump_velocity > 0.0:
		vertical_speed = clamp(velocity.y / locomotion.jump_velocity, -1.0, 1.0)
		
	var anim_scale = Vector3(1.0 - (vertical_speed * 0.2), 1.0 + (abs(vertical_speed) * 0.3), 1.0 - (vertical_speed * 0.2))
	var target_scale = base_visual_scale * current_liquid_scale
	
	visuals.scale = visuals.scale.lerp(target_scale * anim_scale, delta * 10.0)
	
	var h_speed = locomotion.get_horizontal_speed()
	var move_dir = locomotion.get_movement_direction_relative()
	
	if h_speed > 0.1 and is_on_floor():
		step_cycle += h_speed * delta * 2.0
		visuals.position.y = visual_base_y + sin(step_cycle * PI) * 0.1
		visuals.rotation.x = lerp(visuals.rotation.x, move_dir.z * 0.15, delta * 8.0)
		visuals.rotation.z = lerp(visuals.rotation.z, -move_dir.x * 0.15, delta * 8.0)
	else:
		step_cycle = 0.0
		visuals.position.y = lerp(visuals.position.y, visual_base_y, delta * 10.0)
		visuals.rotation.x = lerp(visuals.rotation.x, 0.0, delta * 8.0)
		visuals.rotation.z = lerp(visuals.rotation.z, 0.0, delta * 8.0)

# Función para detectar un Nodo Pegajoso y volar hacia él
func _try_grapple_to_node():
	# Radio máximo al que el slime puede estirar sus filamentos
	var grapple_radius = 15.0 * current_liquid_scale 
	
	var all_nodes = get_tree().get_nodes_in_group("sticky_nodes")
	var valid_nodes: Array[Node3D] = []
	
	# Buscamos todos los nodos que estén pegados y dentro de rango
	for node in all_nodes:
		if node.is_anchored and global_position.distance_to(node.global_position) <= grapple_radius:
			valid_nodes.append(node)
			
	if valid_nodes.size() > 0:
		# ¡Le pasamos LA LISTA de nodos al locomotion!
		locomotion.start_multi_grapple(valid_nodes)
		
		# Efecto visual de tensión
		var tween = get_tree().create_tween()
		tween.tween_property(visuals, "scale", Vector3(base_visual_scale.x * 0.7, base_visual_scale.y * 1.5, base_visual_scale.z * 0.7), 0.2)

func attach_to_surface(attach_pos: Vector3, normal: Vector3):
	# 1. Cambiamos la "Gravedad" base del jugador a la pared/techo
	# (CharacterBody3D usa up_direction para saber qué es el suelo)
	up_direction = normal
	
	# 2. Teletransportamos al jugador exactamente a donde estaba el nodo, 
	# con un ligero margen para no atravesar la geometría
	global_position = attach_pos + (normal * 0.6) 
	velocity = Vector3.ZERO # Cancelamos la inercia del vuelo
	
	# 3. Alineamos el modelo visual del slime para que se vea pegado a la pared
	if visuals:
		var target_basis = Basis()
		target_basis.y = normal
		
		# Calculamos el eje X y Z en base a la pared
		target_basis.x = normal.cross(Vector3.FORWARD).normalized()
		if target_basis.x.length_squared() < 0.01:
			target_basis.x = normal.cross(Vector3.RIGHT).normalized()
			
		target_basis.z = target_basis.x.cross(target_basis.y).normalized()
		
		# Aplicamos la rotación
		visuals.global_transform.basis = target_basis

func _spawn_physics_scaffold() -> void:
	_clear_physics_scaffold() 
	
	var mass_scale = current_liquid_scale if "current_liquid_scale" in self else 1.0
	
	# 🌟 FIX RIGIDEZ: Máximo 12 segmentos. Si hay mucha masa, los hacemos más LARGOS, no más numerosos.
	var dynamic_segments = int(clamp(5 + (mass_scale * 1.5), 4, 12)) 
	var dynamic_height = 0.6 * (1.0 + (mass_scale * 0.3)) # Crecen en altura
	var dynamic_radius = 0.15 * mass_scale
	
	scaffold_base_static = StaticBody3D.new()
	add_child(scaffold_base_static)
	scaffold_base_static.position = Vector3.ZERO 
	
	# 🌟 FIX SHADER: Intentamos robar el material de tu slime visual
	var slime_material = null
	if visuals and visuals.get_child_count() > 0:
		var visual_mesh = visuals.get_child(0) # Asume que el primer hijo es el MeshInstance
		if visual_mesh is MeshInstance3D:
			slime_material = visual_mesh.get_active_material(0)
	
	var organic_physics_mat = PhysicsMaterial.new()
	organic_physics_mat.friction = 1.0 # Agarre máximo
	organic_physics_mat.rough = true   # Evita que resbale con facilidad
	organic_physics_mat.bounce = 0.1   # Un toque casi imperceptible de rebote orgánico
	
	for i in range(dynamic_segments):
		var rb = RigidBody3D.new()
		
		rb.physics_material_override = organic_physics_mat
		rb.position = Vector3(0, (i * dynamic_height) + (dynamic_height / 2.0), 0)
		rb.mass = (1.0 - (float(i) * 0.05)) * mass_scale
		rb.angular_damp = scaffold_angular_damp
		rb.can_sleep = false 
		rb.add_collision_exception_with(self)
		
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
		
		# Le aplicamos tu material gelatinoso si lo encontró, sino uno genérico
		if slime_material != null:
			mesh.material = slime_material
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
		joint.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(65)) # Aumentamos la flexibilidad
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
	is_scaffold_active = true

func _clear_physics_scaffold() -> void:
	is_scaffold_active = false
	for joint in scaffold_joints:
		if is_instance_valid(joint): joint.queue_free()
	for rb in scaffold_segments:
		if is_instance_valid(rb): rb.queue_free()
	if is_instance_valid(scaffold_base_static): 
		scaffold_base_static.queue_free()
	scaffold_segments.clear()
	scaffold_joints.clear()
	scaffold_base_static = null
	if camera_controller and "tracking_target" in camera_controller:
		camera_controller.tracking_target = null
