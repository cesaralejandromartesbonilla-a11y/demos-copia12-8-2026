extends Area3D
class_name InteractionManager

enum Mode { AREA_3D, RAYCAST, HYBRID, AUTOMATIC, NULL }

@export_group("Habilidades de cultivo")
@export var enable_farming_override: bool = false
@export var crop_plot_scene: PackedScene
@export var current_mode: Mode = Mode.AREA_3D
@export var mostrar_esfera_guia: bool = true
@export var rango_raycast_dinamico: float = 25.0
@export var distancia_esfera_vacio: float = 4.0

@onready var survival = get_parent().get_node("SurvivalManager")
@onready var hands = get_parent().get_node_or_null("HandsInventory")
@onready var controller = get_parent()

var last_action_time: int = 0
var action_cooldown_ms: int = 250
var debug_sphere: MeshInstance3D = null
var _ultimo_frame_calculado: int = -1
var _raycast_cacheado: Dictionary = {}

func _ready() -> void:
	if mostrar_esfera_guia:
		_crear_esfera_procedural()

func _unhandled_input(event: InputEvent) -> void:
	# 1. Validación de estado global
	if controller.current_action_mode != controller.ActionMode.EXPLORATION and controller.current_action_mode != controller.ActionMode.FARMING:
		return

	# 2. Control de cámara en modo Raycast
	if current_mode == Mode.RAYCAST and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	# 3. Interacción principal con click izquierdo
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var modo_usa_raycast = current_mode in [Mode.RAYCAST, Mode.HYBRID, Mode.AUTOMATIC]
		if modo_usa_raycast and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			try_interact_action()
			get_viewport().set_input_as_handled()
			return
	
	# 4. Cambio de modos de interacción
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_0:
			current_mode = ((current_mode + 1) % 5) as Mode
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if current_mode == Mode.RAYCAST else Input.MOUSE_MODE_CAPTURED
			
		elif event.keycode == KEY_9:
			current_mode = ((current_mode - 1 + 5) % 5) as Mode
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if current_mode == Mode.RAYCAST else Input.MOUSE_MODE_CAPTURED
	
	# 5. Desmantelar objetos
	if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_F:
		var modo_usa_raycast = current_mode in [Mode.RAYCAST, Mode.HYBRID, Mode.AUTOMATIC]
		if modo_usa_raycast:
			var ray_result = _obtener_raycast_dinamico()
			if not ray_result.is_empty():
				var objeto_detectado = ray_result.collider
				if objeto_detectado is PickableItem:
					if objeto_detectado.componentes_internos.size() > 1:
						objeto_detectado.desmantelar_en_componentes()
						get_viewport().set_input_as_handled()
						return

func _obtener_raycast_dinamico() -> Dictionary:
	var frame_actual = Engine.get_physics_frames()
	if frame_actual == _ultimo_frame_calculado:
		return _raycast_cacheado
		
	_ultimo_frame_calculado = frame_actual
	_raycast_cacheado = {}
	
	var modo_usa_raycast = current_mode in [Mode.RAYCAST, Mode.HYBRID, Mode.AUTOMATIC]
	if not modo_usa_raycast or current_mode == Mode.NULL:
		return _raycast_cacheado
		
	var camera = get_viewport().get_camera_3d()
	if not camera: return _raycast_cacheado
	
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * rango_raycast_dinamico
	
	var space_state = get_viewport().world_3d.direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	if controller:
		query.exclude = [controller.get_rid()]
		
	_raycast_cacheado = space_state.intersect_ray(query)
	return _raycast_cacheado

func try_interact_continuous(delta: float) -> void:
	# 6. Validación de estado para interacción continua
	if controller.current_action_mode != controller.ActionMode.EXPLORATION:
		return

	if controller.current_creature_data == null: return
	var current_diet = controller.current_creature_data.diet
	
	if hands:
		var item_to_eat = null
		if hands.item_in_right and _is_edible(hands.item_in_right.data, current_diet):
			item_to_eat = hands.item_in_right
		elif hands.item_in_left and _is_edible(hands.item_in_left.data, current_diet):
			item_to_eat = hands.item_in_left
			
		if item_to_eat:
			_process_hand_consumption(item_to_eat, 40.0 * delta)
			controller.velocity = Vector3.ZERO
			return
			
	var areas = _get_custom_areas()
	var interacted = false
	
	for area in areas:
		if area.is_in_group("planta"):
			if current_diet == CreatureData.DietType.HERBIVORE or current_diet == CreatureData.DietType.OMNIVORE:
				_process_consumption(area, 20.0 * delta, "hunger", false, true)
				interacted = true
				
		elif area.is_in_group("carne") or area.is_in_group("podrido"):
			if current_diet == CreatureData.DietType.CARNIVORE or current_diet == CreatureData.DietType.OMNIVORE:
				var is_toxic = area.is_in_group("podrido")
				_process_consumption(area, 30.0 * delta, "hunger", is_toxic, true)
				interacted = true
				
		elif area.is_in_group("agua"):
			_process_consumption(area, 25.0 * delta, "thirst", false, false)
			interacted = true
		elif area.is_in_group("agua_contaminada"):
			_process_consumption(area, 15.0 * delta, "thirst", true, false)
			interacted = true
			
		if interacted:
			controller.velocity = Vector3.ZERO
			break

func try_interact_action() -> void:
	if controller.current_creature_data == null: return
	
	var current_time = Time.get_ticks_msec()
	if current_time - last_action_time < action_cooldown_ms:
		return
		
	last_action_time = current_time
	
	var areas = _get_custom_areas()
	var bodies = _get_custom_bodies()
	
	# 7. Llenar contenedores de agua
	for area in areas:
		if area.is_in_group("agua") or area.is_in_group("agua_contaminada"):
			if hands:
				if _try_fill_container(hands.item_in_right, area): return
				if _try_fill_container(hands.item_in_left, area): return

	# 8. Cosecha y herramientas de agricultura
	var tool_in_hand: PickableItem = null
	if hands:
		if hands.item_in_right and hands.item_in_right.data.is_tool and hands.item_in_right.data.can_till_soil:
			tool_in_hand = hands.item_in_right
		elif hands.item_in_left and hands.item_in_left.data.is_tool and hands.item_in_left.data.can_till_soil:
			tool_in_hand = hands.item_in_left

	if tool_in_hand and crop_plot_scene:
		var can_till = true
		for area in areas:
			if area.is_in_group("crop_plot") or area.is_in_group("estructuras"):
				can_till = false
				break
				
		if can_till:
			var new_plot = crop_plot_scene.instantiate()
			get_tree().current_scene.add_child(new_plot)
			var forward_offset = -controller.global_transform.basis.z * 1.5
			var spawn_pos = controller.global_position + forward_offset
			new_plot.global_position = spawn_pos
			return
			
	for area in areas:
		if area.has_method("intentar_cosechar_frutos"):
			if area.intentar_cosechar_frutos():
				return

	# 9. Interacción con estructuras y parcelas
	for area in areas:
		if area.is_in_group("estructuras") or area.is_in_group("crop_plot"):
			if area.has_method("interact"):
				area.interact(controller)
				return
	
	var can_farm = enable_farming_override
	var evo_manager = controller.get_node_or_null("EvolutionManager")
	if evo_manager:
		var stage = evo_manager._get_current_stage()
		if stage and stage.can_farm:
			can_farm = true
			
	for area in areas:
		if area.is_in_group("crop_plot"):
			if can_farm:
				if area.has_method("interact"):
					area.interact(controller)
					break

	# 10. Recolección genérica (Áreas y Cuerpos)
	for body in bodies:
		if "data" in body and body.data is ItemData:
			if hands and hands.try_pick_up(body):
				return

	for area in areas:
		if area is PickableItem:
			if controller.get_node_or_null("HandsInventory"):
				if controller.get_node("HandsInventory").try_pick_up(area):
					break

func _try_fill_container(item: PickableItem, water_area: Area3D) -> bool:
	if item == null or item.data == null: return false
	
	if item.data.is_container and item.data.filled_result_data != null:
		if water_area.is_in_group(item.data.gather_liquid_group):
			item.data = item.data.filled_result_data
			
			if item.mesh_instance != null and item.data.item_mesh != null:
				item.mesh_instance.mesh = item.data.item_mesh
				
			item.add_to_group("agua")
			if item.data.is_edible:
				item.set_meta("current_capacity", item.data.nutrition_value)
				item.set_meta("max_capacity", item.data.nutrition_value)
				
			return true
	return false

func _process(_delta: float) -> void:
	if not debug_sphere or not mostrar_esfera_guia: return
	
	var modo_usa_raycast = current_mode in [Mode.RAYCAST, Mode.HYBRID, Mode.AUTOMATIC]
	if not modo_usa_raycast:
		debug_sphere.visible = false
		return
		
	var ray_result = _obtener_raycast_dinamico()
	
	if not ray_result.is_empty():
		debug_sphere.visible = true
		debug_sphere.global_position = ray_result.position
	else:
		var camera = get_viewport().get_camera_3d()
		if camera:
			debug_sphere.visible = true
			var mouse_pos = get_viewport().get_mouse_position()
			
			var ray_origin = camera.project_ray_origin(mouse_pos)
			var ray_dir = camera.project_ray_normal(mouse_pos)
			
			debug_sphere.global_position = ray_origin + ray_dir * distancia_esfera_vacio
		else:
			debug_sphere.visible = false

func _process_consumption(area: Area3D, requested_amount: float, stat_type: String, is_toxic: bool, is_depletable: bool):
	var amount_received = requested_amount
	
	if is_depletable:
		if not area.has_meta("current_capacity"):
			area.set_meta("current_capacity", 100.0)
			area.set_meta("max_capacity", 100.0)
		
		var current_cap = area.get_meta("current_capacity")
		if current_cap <= 0: return
		
		amount_received = min(requested_amount, current_cap)
		current_cap -= amount_received
		area.set_meta("current_capacity", current_cap)
		
		var max_cap = area.get_meta("max_capacity")
		var scale_factor = max(0.1, current_cap / max_cap)
		area.scale = Vector3(scale_factor, scale_factor, scale_factor)
		
		if current_cap <= 0:
			area.queue_free()
			
	if stat_type == "hunger":
		survival.current_hunger = clamp(survival.current_hunger + amount_received, 0, survival.max_hunger)
		if is_toxic: survival.take_damage(5.0 * get_process_delta_time())
		
	elif stat_type == "thirst":
		survival.current_thirst = clamp(survival.current_thirst + amount_received, 0, survival.max_thirst)
		if is_toxic: survival.take_damage(10.0 * get_process_delta_time())

func _crear_esfera_procedural() -> void:
	debug_sphere = MeshInstance3D.new()
	var mesh_esfera = SphereMesh.new()
	mesh_esfera.radius = 0.08
	mesh_esfera.height = 0.16
	
	var material_neon = StandardMaterial3D.new()
	material_neon.albedo_color = Color(1, 0, 0.2)
	material_neon.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mesh_esfera.material = material_neon
	
	debug_sphere.mesh = mesh_esfera
	debug_sphere.visible = false
	
	get_tree().current_scene.call_deferred("add_child", debug_sphere)

func _is_edible(item_data: ItemData, diet: int) -> bool:
	if item_data == null or not item_data.is_edible: return false
	
	var is_plant = (item_data.item_category == "planta")
	var is_meat = (item_data.item_category == "carne")
	
	if diet == CreatureData.DietType.OMNIVORE: return true
	if diet == CreatureData.DietType.HERBIVORE and is_plant: return true
	if diet == CreatureData.DietType.CARNIVORE and is_meat: return true
	
	return false

func _process_hand_consumption(item: PickableItem, amount: float):
	survival.current_hunger = clamp(survival.current_hunger + amount, 0, survival.max_hunger)
	if item.consume(amount):
		hands.consume_item(item)

func _get_custom_areas() -> Array:
	match current_mode:
		Mode.NULL:
			return []
		Mode.AREA_3D:
			return get_overlapping_areas()
		Mode.RAYCAST:
			var ray_result = _obtener_raycast_dinamico()
			if not ray_result.is_empty() and ray_result.collider is Area3D:
				return [ray_result.collider]
			return []
		Mode.HYBRID:
			var targets = get_overlapping_areas()
			var ray_result = _obtener_raycast_dinamico()
			if not ray_result.is_empty() and ray_result.collider is Area3D:
				if not targets.has(ray_result.collider): targets.insert(0, ray_result.collider)
			return targets
		Mode.AUTOMATIC:
			var ray_result = _obtener_raycast_dinamico()
			if not ray_result.is_empty():
				if ray_result.collider is Area3D:
					return [ray_result.collider]
				else:
					return []
			return get_overlapping_areas()
	return []

func _get_custom_bodies() -> Array:
	match current_mode:
		Mode.NULL:
			return []
		Mode.AREA_3D:
			return get_overlapping_bodies()
		Mode.RAYCAST:
			var ray_result = _obtener_raycast_dinamico()
			if not ray_result.is_empty() and ray_result.collider is CollisionObject3D and not (ray_result.collider is Area3D):
				return [ray_result.collider]
			return []
		Mode.HYBRID:
			var targets = get_overlapping_bodies()
			var ray_result = _obtener_raycast_dinamico()
			if not ray_result.is_empty() and ray_result.collider is CollisionObject3D and not (ray_result.collider is Area3D):
				if not targets.has(ray_result.collider): targets.insert(0, ray_result.collider)
			return targets
		Mode.AUTOMATIC:
			var ray_result = _obtener_raycast_dinamico()
			if not ray_result.is_empty():
				if ray_result.collider is CollisionObject3D and not (ray_result.collider is Area3D):
					return [ray_result.collider]
				else:
					return []
			return get_overlapping_bodies()
	return []
