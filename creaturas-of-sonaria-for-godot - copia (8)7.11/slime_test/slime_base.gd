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

# ==========================================
# VARIABLES DEL ANDAMIO
# ==========================================
@export_group("")
@export var ascending_nodes: Array[Node3D] 
@export var main_collision_shape: CollisionShape3D 

var original_node_y_positions: Dictionary = {}
var is_stretched: bool = false
var stretch_ratio: float = 0.0
var current_stretch_height: float = 0.0

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
	
	# 🔓 Liberamos el seguro en el momento exacto en que el jugador suelta el espacio
	if space_released:
		cancel_lock = false
	
	# ==========================================
	# 1. 🕷️ EL AGARRE Y LA RESORTERA (Slingshot)
	# ==========================================
	var is_touching_surface = is_on_floor() or is_on_wall() or is_on_ceiling()
	
	if launch_momentum_time > 0.0:
		launch_momentum_time -= delta
		is_grabbing = false 
	else:
		is_grabbing = Input.is_action_pressed("press_shift") and is_touching_surface

	if is_grabbing:
		is_stretched = false 
		stretch_ratio = 0.0 # ⚠️ INSTANTÁNEO: Para evitar alturas fantasma al cancelar
		current_stretch_height = 0.0
		
		velocity = velocity.lerp(Vector3.ZERO, delta * 15.0) 
		
		# CARGA:
		if space_pressed:
			slingshot_charge = move_toward(slingshot_charge, 1.0, delta * 1.0)
			
			if visuals:
				visuals.scale.y = lerp(visuals.scale.y, base_visual_scale.y * 0.4, delta * 5.0)
				visuals.position.x = randf_range(-0.05, 0.05) * slingshot_charge
				
		# DISPARO:
		if space_released and slingshot_charge > 0.1:
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
			
	else:
		# 🚫 MODO CANCELACIÓN: Si soltamos Shift, perdemos la carga
		if slingshot_charge > 0.0:
			slingshot_charge = move_toward(slingshot_charge, 0.0, delta * 5.0)
			# Si seguimos presionando espacio mientras la carga baja, activamos el seguro
			if space_pressed:
				cancel_lock = true
				
		# ==========================================
		# 2. ⏱️ GESTIÓN DEL ANDAMIO CLÁSICO
		# ==========================================
		if scaffold_cooldown > 0.0:
			scaffold_cooldown -= delta
			
		# 🔒 El andamio solo crece si el seguro está desactivado
		if space_pressed and is_on_floor() and scaffold_cooldown <= 0.0 and not cancel_lock:
			is_stretched = true
		else:
			is_stretched = false

		# ==========================================
		# 3. 💥 COLAPSO POR IMPACTO
		# ==========================================
		if is_stretched and (is_on_wall() or is_on_ceiling()):
			is_stretched = false
			scaffold_cooldown = 1.0

		# ==========================================
		# 4. 🚀 LA CATAPULTA SLIME (Salto vertical)
		# ==========================================
		if space_released and current_stretch_height > 0.1:
			global_position.y += current_stretch_height
			
			if locomotion and "jump_velocity" in locomotion:
				var jump_power = locomotion.jump_velocity * (0.5 + (stretch_ratio * 0.8))
				velocity.y = jump_power
				
			stretch_ratio = 0.0
			current_stretch_height = 0.0

		# ==========================================
		# 5. 📈 CÁLCULO DE CRECIMIENTO
		# ==========================================
		if is_stretched:
			stretch_ratio = move_toward(stretch_ratio, 1.0, delta * 3.0)
		else:
			stretch_ratio = move_toward(stretch_ratio, 0.0, delta * 5.0)

		var max_height_capacity = current_liquid_scale * 2.5 
		current_stretch_height = max_height_capacity * stretch_ratio

		# ==========================================
		# 6. ⚖️ PÉNDULO FÍSICO REAL (El tambaleo)
		# ==========================================
		if is_stretched:
			var floor_normal = get_floor_normal() if is_on_floor() else Vector3.UP
			var gravity_pull = Vector2(-floor_normal.x, -floor_normal.z) * gravity_influence
			var movement_inertia = Vector2(-velocity.x, -velocity.z) * inertia_influence
			
			var spring_force = -spring_stiffness * scaffold_tilt
			var damping_force = -damping * tilt_velocity
			
			var simulated_mass = 1.0 + (current_stretch_height * 0.5)
			var total_acceleration = (spring_force + damping_force + gravity_pull + movement_inertia) / simulated_mass
			
			tilt_velocity += total_acceleration * delta
			scaffold_tilt += tilt_velocity * delta
		else:
			scaffold_tilt = scaffold_tilt.lerp(Vector2.ZERO, delta * 8.0)
			tilt_velocity = Vector2.ZERO

		# ==========================================
		# 7. 🧅 ASCENSIÓN FÍSICA Y MÓDULOS
		# ==========================================
		for node in ascending_nodes:
			if node != null and original_node_y_positions.has(node):
				var base_y = original_node_y_positions[node]
				node.position.y = base_y + (current_stretch_height * 0.8)

		if main_collision_shape and main_collision_shape.shape is CapsuleShape3D:
			var capsule = main_collision_shape.shape as CapsuleShape3D
			var base_height = default_col_height * current_liquid_scale 
			
			if is_on_floor() or current_stretch_height > 0.01:
				capsule.height = base_height + current_stretch_height
				main_collision_shape.position.y = current_stretch_height / 2.0
			else:
				capsule.height = base_height
				main_collision_shape.position.y = 0.0

	# ==========================================
	# 8. 🏃 MODIFICADORES DE LOCOMOCIÓN Y VUELO LIBRE
	# ==========================================
	if launch_momentum_time > 0.0:
		var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
		velocity.y -= gravity * delta
		move_and_slide() 
	else:
		# Comportamiento normal: Le devolvemos el control al LocomotionController
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

	if not is_grabbing: # Solo animar normalmente si no estamos en la resortera
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
