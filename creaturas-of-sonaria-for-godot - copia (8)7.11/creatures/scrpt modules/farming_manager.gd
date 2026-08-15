extends Node
class_name FarmingManager

@export var blueprint_label: Label

@onready var controller = get_parent()
@onready var interaction_manager = $"../InteractionManager"
@onready var free_crop_scene: PackedScene = preload("res://ecenas/parcela/dynamic_free_crop.tscn")
@onready var procedural_crop_scene: PackedScene = preload("res://ecenas/parcela/procedural_free_crop.tscn")

var is_farming_mode: bool = false
var farming_selector: MeshInstance3D
var current_hovered_plot: Area3D = null
var current_hovered_cell: Vector2i = Vector2i(-1, -1)
var mat_valid: StandardMaterial3D
var mat_invalid: StandardMaterial3D

# --- 1. Inicialización ---
func _ready() -> void:
	_setup_materials()
	farming_selector = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.95, 0.1, 0.95) 
	farming_selector.mesh = box_mesh
	add_child(farming_selector)
	farming_selector.visible = false

# --- 2. Control de Entradas ---
func _unhandled_input(event: InputEvent) -> void:
	# Activar/Desactivar Modo Cultivo
	if event.is_action_pressed("press_z"):
		# Comunicación segura con el BuilderManager para apagar sus modos
		var builder_manager = controller.get_node_or_null("BuilderManager")
		if builder_manager:
			if builder_manager.is_build_mode: builder_manager._exit_build_mode()
			if builder_manager.is_wiring_mode: builder_manager._exit_wiring_mode()
			
		if not is_farming_mode: _toggle_farming_mode()
		else: _exit_farming_mode()
		return

	if is_farming_mode:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if current_hovered_plot and current_hovered_cell != Vector2i(-1, -1):
				if current_hovered_plot.has_method("interact"):
					if current_hovered_plot.has_method("global_to_cell"):
						current_hovered_plot.interact(controller, current_hovered_cell)
					else:
						current_hovered_plot.interact(controller)
			elif current_hovered_cell == Vector2i(-2, -2):
				_plant_free_crop()
	else:
		# Modo exploración normal (Interacciones directas fuera del modo construcción/cultivo)
		var builder_manager = controller.get_node_or_null("BuilderManager")
		if not (builder_manager and (builder_manager.is_build_mode or builder_manager.is_wiring_mode)):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_handle_default_click_action()

# --- 3. Lógica de Proceso ---
func _physics_process(_delta: float) -> void:
	if is_farming_mode:
		_update_farming_hover()

# --- 4. Gestión del Estado del Modo ---
func _toggle_farming_mode() -> void:
	is_farming_mode = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if interaction_manager: interaction_manager.current_mode = interaction_manager.Mode.NULL
	if blueprint_label: blueprint_label.text = "Modo Agricultura: Selecciona con el mouse"

func _exit_farming_mode() -> void:
	is_farming_mode = false
	farming_selector.visible = false
	current_hovered_plot = null
	current_hovered_cell = Vector2i(-1, -1)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if blueprint_label: blueprint_label.text = ""
	if interaction_manager: interaction_manager.current_mode = interaction_manager.Mode.HYBRID

# --- 5. Lógica del Puntero y Visualización ---
func _update_farming_hover() -> void:
	var result = _get_raycast_result(40.0, true)
	
	if result and result.collider.is_in_group("crop_plot"):
		current_hovered_plot = result.collider
		
		var hands = controller.get_node_or_null("HandsInventory")
		var held_item = hands.item_in_right if hands else null
		var s_data = null
		
		if held_item and held_item.data and held_item.data.get("seed_data"):
			s_data = held_item.data.seed_data

		if current_hovered_plot.has_method("global_to_cell"):
			_handle_grid_plot_hover(result.position, s_data)
			
	elif result and result.collider.is_in_group("suelo_fertil"):
		_handle_fertile_soil_hover(result.position)
	else:
		farming_selector.visible = false
		current_hovered_plot = null
		current_hovered_cell = Vector2i(-1, -1)

func _handle_grid_plot_hover(hit_position: Vector3, s_data) -> void:
	var raw_cell = current_hovered_plot.global_to_cell(hit_position)
	var crop_shape: Array[Vector2i] = [Vector2i(0, 0)]
	var crop_size: Vector2i = Vector2i(1, 1) 
	
	if s_data:
		crop_size = s_data.crop_size
		crop_shape.clear()
		for x in range(crop_size.x):
			for y in range(crop_size.y):
				crop_shape.append(Vector2i(x, y))

	var cols = current_hovered_plot.get("grid_columns") if "grid_columns" in current_hovered_plot else 4
	var rows = current_hovered_plot.get("grid_rows") if "grid_rows" in current_hovered_plot else 4
	
	var max_offset_x = 0
	var max_offset_y = 0
	for offset in crop_shape:
		if offset.x > max_offset_x: max_offset_x = offset.x
		if offset.y > max_offset_y: max_offset_y = offset.y
	
	var safe_mouse_cell = Vector2i(
		clampi(raw_cell.x, 0, cols - 1 - max_offset_x),
		clampi(raw_cell.y, 0, rows - 1 - max_offset_y)
	)
	
	var final_cell = safe_mouse_cell
	var space_found = false
	
	for radius in range(0, max(cols, rows)):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var test_cell = safe_mouse_cell + Vector2i(dx, dy)
				var inside_bounds = true
				for offset in crop_shape:
					var check_pos = test_cell + offset
					if check_pos.x < 0 or check_pos.x >= cols or check_pos.y < 0 or check_pos.y >= rows:
						inside_bounds = false
						break
				if inside_bounds and current_hovered_plot.can_fit(crop_size, test_cell, s_data):
					final_cell = test_cell
					space_found = true
					break
			if space_found: break
		if space_found: break
		
	if not space_found:
		final_cell = safe_mouse_cell

	current_hovered_cell = final_cell
	_sync_selector_cubes(crop_shape.size())
	
	var is_valid = current_hovered_plot.can_fit(crop_size, final_cell, s_data)
	var active_material = mat_valid if is_valid else mat_invalid
	var c_size = current_hovered_plot.cell_world_size
	
	for i in range(crop_shape.size()):
		var offset = crop_shape[i]
		var target_cell = final_cell + offset
		var cell_local_3d = current_hovered_plot.cell_to_local_3d(target_cell)
		var cell_global_3d = current_hovered_plot.to_global(cell_local_3d)
		
		var cube = farming_selector.get_child(i) as MeshInstance3D
		cube.mesh.size = Vector3(c_size * 0.95, 0.05, c_size * 0.95)
		cube.global_position = cell_global_3d
		cube.global_position.y += 0.02
		cube.material_override = active_material
		cube.visible = true
		
	farming_selector.visible = true

func _handle_fertile_soil_hover(hit_position: Vector3) -> void:
	var hands = controller.get_node_or_null("HandsInventory")
	var held_item = hands.item_in_right if hands else null
	if held_item and held_item.data and held_item.data.get("seed_data"):
		current_hovered_plot = null
		current_hovered_cell = Vector2i(-2, -2) # Flag mágico que indica "Tierra libre lista"
		_sync_selector_cubes(1)
		
		var cube = farming_selector.get_child(0) as MeshInstance3D
		cube.mesh.size = Vector3(1.0, 0.05, 1.0)
		cube.global_position = hit_position + Vector3(0, 0.02, 0)
		cube.material_override = mat_valid
		cube.visible = true
		farming_selector.visible = true
	else:
		farming_selector.visible = false
		current_hovered_plot = null
		current_hovered_cell = Vector2i(-1, -1)

# --- 6. Acciones de Cultivo ---
func _plant_free_crop() -> void:
	var hands = controller.get_node_or_null("HandsInventory")
	var held_item = hands.item_in_right if hands else null
	
	if held_item and held_item.data and held_item.data.get("seed_data"):
		var seed_data = held_item.data.seed_data
		var scene_to_use = free_crop_scene
		
		# Verificación
		var visual_data = seed_data.get("visual_data")
		if visual_data and visual_data is ProceduralVisualData:
			scene_to_use = procedural_crop_scene
		
		# Instanciamos la escena correcta
		var new_crop = scene_to_use.instantiate()
		get_tree().current_scene.add_child(new_crop)
		
		# Posicionamiento
		new_crop.global_position = farming_selector.get_child(0).global_position - Vector3(0, 0.02, 0)
		
		# Aseguramos que la inicialización ocurra
		if new_crop.has_method("initialize_crop"):
			new_crop.initialize_crop(seed_data, held_item.data)
		else:
			push_warning("La escena instanciada no tiene el método 'initialize_crop'")
		
		hands.consume_item(held_item)

func _handle_default_click_action() -> void:
	var result = _get_raycast_result(20.0, true)
	if result:
		var target = result.collider
		if target.is_in_group("crop_plot"):
			if target.has_method("interact"):
				if target.has_method("global_to_cell"):
					target.interact(controller, current_hovered_cell)
				else:
					target.interact(controller)

# --- 7. Utilidades y Helpers ---
func _sync_selector_cubes(count: int) -> void:
	while farming_selector.get_child_count() < count:
		var mi = MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		farming_selector.add_child(mi)
		
	for i in range(farming_selector.get_child_count()):
		farming_selector.get_child(i).visible = (i < count)

func _setup_materials() -> void:
	mat_valid = StandardMaterial3D.new()
	mat_valid.albedo_color = Color(0, 1, 0, 0.4)
	mat_valid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_invalid = StandardMaterial3D.new()
	mat_invalid.albedo_color = Color(1, 0, 0, 0.4)
	mat_invalid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

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
