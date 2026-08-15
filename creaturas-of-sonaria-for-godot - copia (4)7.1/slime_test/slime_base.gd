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
@onready var modular_hands_inventory = $ModularHandsInventory
@onready var hold_position = $HoldPosition
@onready var magic_inventory = $MagicInventory

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
		if matter_controller: matter_controller.expel_mass()
	if event.is_action_pressed("press_g"): 
		if matter_controller: matter_controller.shed_shell_as_item()

# ==========================================
# ⚙️ FÍSICAS Y MOVIMIENTO
# ==========================================
func _physics_process(delta):
	if locomotion:
		# 1. Velocidad Máxima: Escala hacia arriba con la masa
		locomotion.speed = base_speed * current_liquid_scale
		
		# 2. Inercia (Aceleración/Frenado): Escala hacia ABAJO
		var inertia_factor = 1.0 / current_liquid_scale
		locomotion.acceleration = base_accel * inertia_factor
		
		var input_dir = Input.get_vector("press_a", "press_d", "press_w", "press_s")
		var jump_pressed = Input.is_action_just_pressed("press_space")
		locomotion.process_movement(self, input_dir, jump_pressed, is_build_mode, delta)
	
	if camera_controller:
		camera_controller.process_camera(delta)

	_apply_procedural_animation(delta)

# ==========================================
# 📡 REACCIONES A MASA Y DAÑO (🔥 NUEVO)
# ==========================================
func _on_mass_scale_changed(new_scale: float):
	current_liquid_scale = new_scale
	
	# El núcleo (y por tanto collision_shape) NO CRECE. Efecto Pulpo.
	collision_shape.scale = core_scale 
	
	# Ajustamos la cámara dinámicamente según el tamaño del líquido
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
	visuals.scale = visuals.scale.lerp(base_visual_scale * anim_scale, delta * 10.0)
	
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
