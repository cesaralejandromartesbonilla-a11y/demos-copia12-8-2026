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
@onready var visuals = $Visuals
@onready var slime_mesh = $Visuals/SlimeMesh
@onready var stone_mesh = $Visuals/StoneMesh
@onready var FIRE_mesh = $Visuals/fireMesh
@onready var skeleton_mesh = $Visuals/SkeletonMesh
@onready var element_core = $Visuals/ElementCore
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
var base_visual_scale: Vector3 = Vector3.ONE
var default_col_radius: float = 0.5
var default_col_height: float = 1.0

var is_build_mode: bool = false
var step_cycle: float = 0.0
var visual_base_y: float = 0.0

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

	if health:
		health.damage_taken.connect(_on_damage_taken)
		health.died.connect(_on_player_died)
	
	if form_controller:
		form_controller.form_changed.connect(_on_form_changed)
		_on_form_changed(form_controller.get_current_form())

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
		var input_dir = Input.get_vector("press_a", "press_d", "press_w", "press_s")
		var jump_pressed = Input.is_action_just_pressed("press_space")
		locomotion.process_movement(self, input_dir, jump_pressed, is_build_mode, delta)
	
	if camera_controller:
		camera_controller.process_camera(delta)

	_apply_procedural_animation(delta)

# ==========================================
# 📡 REACCIONES A SEÑALES (Callbacks)
# ==========================================
func _on_damage_taken(_amount: float, wear_percentage: float):
	var current_mesh = get_current_active_mesh()
	if current_mesh and current_mesh.material_override is ShaderMaterial:
		current_mesh.material_override.set_shader_parameter("damage_level", wear_percentage)

func _on_player_died():
	print("El jugador ha muerto.")

func _on_form_changed(new_form: FormController.Form):
	await get_tree().create_timer(0.1).timeout
	
	if magic_inventory:
		if transformation_module and not transformation_module.allows_internal_inventory(int(new_form)):
			magic_inventory._expel_internal_inventory()
		else:
			magic_inventory._enforce_capacity_limit(int(new_form))

	slime_mesh.visible = (new_form == FormController.Form.SLIME)
	stone_mesh.visible = (new_form == FormController.Form.STONE)
	FIRE_mesh.visible = (new_form == FormController.Form.FIRE)
	skeleton_mesh.visible = (new_form == FormController.Form.SKELETON)
	
	element_core.mesh = get_current_active_mesh().mesh
	element_core.scale = Vector3(0.95, 0.95, 0.95)

	var ik_node = slime_mesh.get_node_or_null("Armature/Skeleton3D/SkeletonIK3D")
	if ik_node:
		if new_form == FormController.Form.SLIME: ik_node.start()
		else: ik_node.stop()

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

# ==========================================
# 🛠️ FUNCIONES AUXILIARES
# ==========================================
func get_current_active_mesh() -> MeshInstance3D:
	if not form_controller: return slime_mesh
	match form_controller.get_current_form():
		FormController.Form.SLIME: return slime_mesh
		FormController.Form.STONE: return stone_mesh
		FormController.Form.FIRE: return FIRE_mesh
		FormController.Form.SKELETON: return skeleton_mesh
	return slime_mesh
