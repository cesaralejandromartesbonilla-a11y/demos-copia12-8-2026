extends Node
class_name BuilderManager

@export var blueprint_label: Label

@onready var controller = get_parent()
@onready var ground_detector: RayCast3D = $"../GroundDetector"
@onready var interaction_manager = $"../InteractionManager"
@onready var construction_site_scene: PackedScene = preload("res://ecenas/construction_site.tscn")

var is_wiring_mode: bool = false
var first_pole_selected: Node3D = null
var last_hovered_pole: Node3D = null

var active_blueprints: Array[BlueprintData] = []
var current_bp_index: int = 0
var is_build_mode: bool = false
var snap_to_grid: bool = true
var grid_size: float = 2.0
var blueprint_rotation_y: float = 0.0

var hologram: MeshInstance3D
var mat_valid: StandardMaterial3D
var mat_invalid: StandardMaterial3D

# 1. Inicializacion
func _ready() -> void:
	_setup_materials()
	hologram = MeshInstance3D.new()
	add_child(hologram)
	hologram.visible = false

# 2. Control de entradas
func _unhandled_input(event: InputEvent) -> void:
	if is_build_mode and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	if event.is_action_pressed("press_tab"):
		if is_wiring_mode: _exit_wiring_mode()
		
		var farming_manager = controller.get_node_or_null("FarmingManager")
		if farming_manager and farming_manager.is_farming_mode:
			farming_manager._exit_farming_mode()
			
		if not is_build_mode: _toggle_build_mode()
		else: _exit_build_mode()
		return
		
	if event.is_action_pressed("press_x"):
		if is_build_mode: _exit_build_mode()
		
		var farming_manager = controller.get_node_or_null("FarmingManager")
		if farming_manager and farming_manager.is_farming_mode:
			farming_manager._exit_farming_mode()
			
		if not is_wiring_mode: _toggle_wiring_mode()
		else: _exit_wiring_mode()
		return

	if is_build_mode:
		if event.is_action_pressed("press_pleca"): snap_to_grid = !snap_to_grid
		if event.is_action_pressed("press_c"): blueprint_rotation_y += deg_to_rad(90)
		elif event.is_action_pressed("press_v"): blueprint_rotation_y -= deg_to_rad(90)
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP: _change_blueprint(1)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _change_blueprint(-1)
			elif event.button_index == MOUSE_BUTTON_LEFT: _try_place_blueprint()
				
	elif is_wiring_mode:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_try_connect_wire()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_handle_wire_disconnection()
	else:
		var farming_manager = controller.get_node_or_null("FarmingManager")
		if not (farming_manager and farming_manager.is_farming_mode):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_handle_default_click_action()

# 3. Logica de proceso
func _physics_process(_delta: float) -> void:
	if is_build_mode:
		_update_hologram_logic()
	elif is_wiring_mode:
		_update_wiring_hover()

# 4. Modo Construccion
func _toggle_build_mode() -> void:
	active_blueprints.clear()
	
	var evo_manager = controller.get_node_or_null("EvolutionManager")
	if evo_manager == null: return
	
	var current_stage_resource = evo_manager._get_current_stage()
	if current_stage_resource == null or not "unlocked_blueprints" in current_stage_resource: return
		
	var guardados = current_stage_resource.unlocked_blueprints
	if guardados.is_empty(): return
		
	active_blueprints = guardados.duplicate()
	
	if interaction_manager: interaction_manager.current_mode = interaction_manager.Mode.NULL

	is_build_mode = true
	hologram.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	current_bp_index = 0
	_update_blueprint_ui()

func _exit_build_mode() -> void:
	is_build_mode = false
	hologram.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if blueprint_label: blueprint_label.text = ""
	if interaction_manager: interaction_manager.current_mode = interaction_manager.Mode.HYBRID

func _update_hologram_logic() -> void:
	var result = _get_raycast_result(20.0, false, 1)
	if result:
		var pos = result.position
		if snap_to_grid:
			pos.x = snapped(pos.x, grid_size)
			pos.z = snapped(pos.z, grid_size)
		
		hologram.global_position = pos
		hologram.rotation.y = blueprint_rotation_y
		hologram.material_override = mat_valid
	else:
		hologram.material_override = mat_invalid

func _change_blueprint(dir: int) -> void:
	current_bp_index = clampi(current_bp_index + dir, 0, active_blueprints.size() - 1)
	_update_blueprint_ui()

func _update_blueprint_ui() -> void:
	var bp = active_blueprints[current_bp_index]
	hologram.mesh = bp.hologram_mesh
	if blueprint_label:
		blueprint_label.text = "Construyendo: " + bp.building_name

func _try_place_blueprint() -> void:
	if active_blueprints.is_empty() or current_bp_index < 0 or current_bp_index >= active_blueprints.size(): return
	if construction_site_scene == null or hologram.material_override == mat_invalid: return

	var bp = active_blueprints[current_bp_index]
	var site = construction_site_scene.instantiate()
	
	site.blueprint = bp
	get_tree().current_scene.add_child(site)
	
	site.global_position = hologram.global_position
	site.global_rotation.y = blueprint_rotation_y
	
	_exit_build_mode()

func _setup_materials() -> void:
	mat_valid = StandardMaterial3D.new()
	mat_valid.albedo_color = Color(0, 1, 0, 0.4)
	mat_valid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_invalid = StandardMaterial3D.new()
	mat_invalid.albedo_color = Color(1, 0, 0, 0.4)
	mat_invalid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

# 5. Modo Cableado
func _toggle_wiring_mode() -> void:
	is_wiring_mode = true
	first_pole_selected = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if interaction_manager: interaction_manager.current_mode = interaction_manager.Mode.NULL
	if blueprint_label: blueprint_label.text = "Modo Cableado: Selecciona un poste o conector"

func _exit_wiring_mode() -> void:
	is_wiring_mode = false
	first_pole_selected = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if blueprint_label: blueprint_label.text = ""
	if interaction_manager: interaction_manager.current_mode = interaction_manager.Mode.HYBRID

func _try_connect_wire() -> void:
	var result = _get_raycast_result(50.0)
	if result:
		var target = result.collider
		if (target.is_in_group("poste_electrico") or target.is_in_group("poste_logico") or target.is_in_group("conector_tuberia")) and target.has_method("connect_to_node"):
			if first_pole_selected == null:
				first_pole_selected = target
				if blueprint_label: blueprint_label.text = "Conectando a... (Clic en otro conector similar)"
			else:
				if target != first_pole_selected:
					var is_valid = (target.is_in_group("poste_electrico") and first_pole_selected.is_in_group("poste_electrico")) or \
								   (target.is_in_group("poste_logico") and first_pole_selected.is_in_group("poste_logico")) or \
								   (target.is_in_group("conector_tuberia") and first_pole_selected.is_in_group("conector_tuberia"))
					if not is_valid: return
						
					first_pole_selected.connect_to_node(target)
					first_pole_selected = target
					get_viewport().set_input_as_handled()
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _handle_wire_disconnection() -> void:
	var result = _get_raycast_result(50.0)
	if result and (result.collider.is_in_group("poste_electrico") or result.collider.is_in_group("poste_logico")):
		var target = result.collider
		if target.has_method("disconnect_all_cables"):
			target.disconnect_all_cables()
		
		if first_pole_selected == target:
			first_pole_selected = null
			if blueprint_label: blueprint_label.text = "Modo Cableado: Selecciona un poste"
	else:
		if first_pole_selected != null:
			first_pole_selected = null
			if blueprint_label: blueprint_label.text = "Modo Cableado: Selecciona un poste"
		else:
			_exit_wiring_mode()

func _update_wiring_hover() -> void:
	if last_hovered_pole and is_instance_valid(last_hovered_pole) and last_hovered_pole.has_method("set_hover"):
		last_hovered_pole.set_hover(false)
		last_hovered_pole = null
		
	var result = _get_raycast_result(50.0)
	if result:
		var target = result.collider
		if target.is_in_group("poste_electrico") or target.is_in_group("poste_logico") or target.is_in_group("conector_tuberia"):
			last_hovered_pole = target
			if target.has_method("set_hover"):
				target.set_hover(true)

# 6. Interaccion Estandar
func _handle_default_click_action() -> void:
	var result = _get_raycast_result(20.0, true)
	if result:
		var target = result.collider
		if target.is_in_group("estructuras"):
			var hands = controller.get_node_or_null("HandsInventory")
			var has_tool = false
			if hands:
				if (hands.item_in_right and hands.item_in_right.data.can_till_soil) or (hands.item_in_left and hands.item_in_left.data.can_till_soil):
					has_tool = true
					
			if has_tool:
				if target.has_method("disassemble_with_tool"):
					target.disassemble_with_tool()
				else:
					target.queue_free()

# 7. Helper de Raycast
func _get_raycast_result(distance: float, with_areas: bool = false, mask: int = 0xFFFFFFFF) -> Dictionary:
	var camera = get_viewport().get_camera_3d()
	if not camera: return {}
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * distance
	var space_state = get_viewport().world_3d.direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = with_areas
	query.collide_with_bodies = true
	query.collision_mask = mask
	return space_state.intersect_ray(query)
