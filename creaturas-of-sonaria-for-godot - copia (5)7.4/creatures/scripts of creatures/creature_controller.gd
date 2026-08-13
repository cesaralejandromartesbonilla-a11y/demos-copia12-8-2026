extends CharacterBody3D

# --- ESTADOS FÍSICOS Y DE LOCOMOCIÓN ---
enum MoveState { GROUND, SWIM, HOVER, GLIDE }
var current_state: MoveState = MoveState.GROUND
# ---------------------------------------------------------

# --- ESTADOS DE ANIMACIÓN  ---
enum AnimLocomotion { IDLE, WALK, RUN, FALL, JUMP, SWIM_IDLE, SWIM_MOVE }
var current_anim_locomotion: AnimLocomotion = AnimLocomotion.IDLE

enum AnimAction { NONE, GRAB_1H, GRAB_2H, LEDGE_GRAB, ATTACK }
var current_anim_action: AnimAction = AnimAction.NONE
# ---------------------------------------------------------

# --- ESTADOS GLOBALES DE ACCIÓN ---
enum ActionMode { EXPLORATION, BUILDING, FARMING, WIRING, INVENTORY_OPEN }
var current_action_mode: ActionMode = ActionMode.EXPLORATION
# ---------------------------------------------------------

signal action_mode_changed(new_mode: ActionMode)

@export_group("Locomoción")
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.003
@export var can_swim: bool = false 
@export var can_fly: bool = false

# --- Referencias Módulos ---
@onready var survival = $SurvivalManager
@onready var effects = $effect_manager
@onready var spring_arm = $SpringArm3D
@onready var interaction = $InteractionManager
@onready var ability_manager = $AbilityManager
@onready var evo_manager = $EvolutionManager
@onready var stat_scaler = $StatScaler
@onready var combat_manager = $CombatManager
@onready var level_manager = $LevelManager
@onready var Hands_Inventory = $HandsInventory 
@onready var anim_tree: AnimationTree = $AnimationTree

var current_biome: String = "pradera"
var current_creature_data: CreatureData
var is_in_water: bool = false
var is_frozen_by_temp: bool = false

func set_action_mode(new_mode: ActionMode) -> void:
	if current_action_mode != new_mode:
		current_action_mode = new_mode
		emit_signal("action_mode_changed", new_mode)

func _unhandled_input(event: InputEvent) -> void:
	if not survival or survival.is_dead:
		return
	
	# 1. Movimiento de Cámara
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-45), deg_to_rad(45))
		
	if is_frozen_by_temp:
		return 
		
	# 2. Teclas de Sistema
	elif event.is_action_pressed("press_f12"): 
		InventoryManager.save_game(self) 
		
	# 3. ACCIONES QUE DEPENDEN DEL MODO ACTUAL
	elif event.is_action_pressed("press_clickIZ"):
		match current_action_mode:
			ActionMode.EXPLORATION:
				# Solo atacamos si estamos explorando libremente
				if combat_manager:
					var dmg = stat_scaler.current_damage if stat_scaler else 10.0
					combat_manager.perform_mathematical_bite(self, dmg)
			ActionMode.BUILDING:
				# Aquí el BuilderManager interceptará el click desde su propio script
				pass
			ActionMode.FARMING:
				# Aquí el granjero/constructor de huertos actuará
				pass
				
	elif event.is_action_pressed("press_q"): 
		# Evitamos soltar cosas por error si estamos construyendo
		if current_action_mode == ActionMode.EXPLORATION and Hands_Inventory:
			Hands_Inventory.drop_items()
		
	# Habilidades
	elif ability_manager and current_action_mode == ActionMode.EXPLORATION:
		if event.is_action_pressed("press_1"): ability_manager.try_use_ability(0)
		elif event.is_action_pressed("press_2"): ability_manager.try_use_ability(1)
		elif event.is_action_pressed("press_3"): ability_manager.try_use_ability(2)

	# Vuelo
	if can_fly and not is_in_water:
		if event.is_action_pressed("press_space") and not is_on_floor():
			if current_state in [MoveState.HOVER, MoveState.GLIDE]:
				current_state = MoveState.GROUND
			else:
				current_state = MoveState.HOVER
		if current_state in [MoveState.HOVER, MoveState.GLIDE] and event.is_action_pressed("press_shift"):
			current_state = MoveState.GLIDE if current_state == MoveState.HOVER else MoveState.HOVER

func _ready() -> void:
	print("iniciando criatura")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if survival: update_visual_scale()
	_verify_modules()

# --- VERIFICADOR INTELIGENTE ---
func _verify_modules() -> void:
	print("_verify_modules")
	var modules = {
		"SurvivalManager": survival, "effect_manager": effects, 
		"SpringArm3D": spring_arm, "InteractionManager": interaction, 
		"AbilityManager": ability_manager, "EvolutionManager": evo_manager, 
		"StatScaler": stat_scaler, "CombatManager": combat_manager, 
	}
	var missing = []
	for mod_name in modules:
		if modules[mod_name] == null:
			missing.append(mod_name)
			
	if missing.is_empty():
		print("Inicialización modular completada con éxito.")
	else:
		print("Inicialización modular completada. Módulos faltantes: ", ", ".join(missing))

func initialize_from_data(data: CreatureData) -> void:
	print("initialize_from_data")
	current_creature_data = data
	if not survival or data == null: return

	survival.max_health = data.get("max_health") if data.get("max_health") else 100.0
	survival.max_hunger = data.get("max_hunger") if data.get("max_hunger") else 100.0
	survival.max_thirst = data.get("max_thirst") if data.get("max_thirst") else 100.0
	survival.max_energy = data.get("max_energy") if data.get("max_energy") else 100.0

	var save = InventoryManager.current_save_state
	var current_level_to_apply = 1

	if save != null:
		# --- CARGAR PARTIDA ---
		survival.current_health = save.current_health
		survival.current_hunger = save.current_hunger
		survival.current_thirst = save.current_thirst
		survival.current_energy = save.get("current_energy") if save.get("current_energy") != null else survival.max_energy
		survival.growth_percent = save.growth_percent
		
		# Cargar Nivel
		if level_manager:
			level_manager.level = save.get("level") if save.get("level") != null else 1
			level_manager.current_xp = save.get("current_xp") if save.get("current_xp") != null else 0.0
			current_level_to_apply = level_manager.level
			
		print("Partida REAL cargada. Nivel actual: ", current_level_to_apply)
	else:
		# --- NUEVA CRIATURA ---
		survival.current_health = survival.max_health
		survival.current_hunger = survival.max_hunger
		survival.current_thirst = survival.max_thirst
		survival.current_energy = survival.max_energy
		survival.growth_percent = 0.0
		
		if level_manager:
			level_manager.level = 1
			level_manager.current_xp = 0.0
			
		print("Criatura nueva. Stats al máximo.")

	# Inicializar evolución con el nivel que acabamos de cargar o crear
	if evo_manager and data.get("evolution_stages"):
		evo_manager.setup_stages(data.evolution_stages, current_level_to_apply)

func _physics_process(delta: float) -> void:
	if not survival or survival.is_dead or is_frozen_by_temp:
		print("muerto o congelado")
		if not is_on_floor():
			velocity.y -= 9.8 * delta 
			
		move_and_slide()
		return
		
	update_visual_scale()
	_check_water_mathematically()
	_determine_state()
	handle_movement(delta)
	_update_current_biome()
	
	_update_animation_states()
	
	if Input.is_action_pressed("press_e") and interaction:
		interaction.try_interact_continuous(delta)
		interaction.try_interact_action()

func _determine_state():
	if is_in_water and can_swim: current_state = MoveState.SWIM
	elif is_in_water and not can_swim: current_state = MoveState.GROUND 
	elif current_state == MoveState.SWIM and not is_in_water: current_state = MoveState.GROUND

func handle_movement(delta: float) -> void:
	var input_dir = Input.get_vector("press_a", "press_d", "press_w", "press_s")
	var speed = stat_scaler.current_speed if stat_scaler else 5.0

	match current_state:
		MoveState.GROUND: _move_ground(delta, input_dir, speed)
		MoveState.SWIM: _move_3d(delta, input_dir, speed * 0.8, 3.0, false)
		MoveState.HOVER: _move_3d(delta, input_dir, speed * 1.5, 2.0, false)
		MoveState.GLIDE: _move_3d(delta, input_dir, speed * 2.5, 0.5, true)

	move_and_slide()

func _move_ground(delta: float, input_dir: Vector2, speed: float):
	if not is_on_floor(): velocity.y -= 9.8 * delta
	elif Input.is_action_just_pressed("press_space"): velocity.y = jump_velocity
		
	# ARREGLO DE ENERGÍA
	if Input.is_action_pressed("press_shift") and survival.current_energy > 10 and input_dir != Vector2.ZERO:
		speed *= 2.0
		survival.current_energy -= 10 * delta
	else:
		survival.current_energy = min(survival.current_energy + 5.0 * delta, survival.max_energy)
		
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

func _move_3d(delta: float, input_dir: Vector2, speed: float, drag: float, auto_forward: bool):
	var cam_basis = spring_arm.global_transform.basis
	var direction = Vector3.ZERO
	
	if auto_forward:
		direction = -cam_basis.z 
		direction += cam_basis.x * input_dir.x * 2.0
	else:
		direction = (cam_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if Input.is_action_pressed("press_space"): direction += Vector3.UP
		
	if direction != Vector3.ZERO:
		velocity = velocity.lerp(direction * speed, delta * 5.0)
		var target_rotation = atan2(-velocity.x, -velocity.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * 5.0)
	else:
		velocity = velocity.lerp(Vector3.ZERO, delta * drag)

func take_damage(amount: float):
	if survival: survival.take_damage(amount)

func update_visual_scale():
	if survival:
		# max() tomará el valor más grande. Si growth_percent es 0.0, usará 0.1.
		var safe_scale = max(survival.growth_percent, 0.1)
		scale = Vector3.ONE * safe_scale

func apply_status_effect(effect: StatusEffect):
	if effects: effects.add_status_effect(effect)

func _check_water_mathematically():
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsPointQueryParameters3D.new()
	query.position = global_position + Vector3(0, 0.5, 0)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var results = space_state.intersect_point(query)
	
	is_in_water = false
	for res in results:
		if res.collider.is_in_group("water"):
			is_in_water = true
			break

func _update_current_biome():
	var interaction_areas = interaction.get_overlapping_areas()
	var found_biome = "vacio"
	
	for area in interaction_areas:
		if area.is_in_group("bioma_desierto"):
			found_biome = "desierto"
			break
		elif area.is_in_group("bioma_artico"):
			found_biome = "artico"
			break
			
	if current_biome != found_biome:
		current_biome = found_biome
		print("Entrando al bioma: ", current_biome)

func _update_animation_states() -> void:
	if not anim_tree:
		return
		
	# 1. Determinar Estado de Locomoción basado en la física real
	var speed_xz = Vector2(velocity.x, velocity.z).length()
	
	if current_state == MoveState.GROUND:
		if not is_on_floor():
			current_anim_locomotion = AnimLocomotion.FALL if velocity.y < 0 else AnimLocomotion.JUMP
		elif speed_xz > 0.1:
			current_anim_locomotion = AnimLocomotion.RUN if Input.is_action_pressed("press_shift") and survival.current_energy > 10 else AnimLocomotion.WALK
		else:
			current_anim_locomotion = AnimLocomotion.IDLE
			
	elif current_state == MoveState.SWIM:
		current_anim_locomotion = AnimLocomotion.SWIM_MOVE if speed_xz > 0.1 else AnimLocomotion.SWIM_IDLE
		
	# 2. Comunicarse con el AnimationTree (¡Con la ruta confirmada por el escáner!)
	var playback = anim_tree.get("parameters/Locomotion/playback")
	
	if playback:
		var target_anim = AnimLocomotion.keys()[current_anim_locomotion].to_lower()
		playback.travel(target_anim)
	
	# 3. Lógica para transiciones de Acción
	match current_anim_action:
		AnimAction.GRAB_1H:
			anim_tree.set("parameters/ActionBlend/blend_amount", 1.0) 
		AnimAction.LEDGE_GRAB:
			pass
		AnimAction.NONE:
			anim_tree.set("parameters/ActionBlend/blend_amount", 0.0)
