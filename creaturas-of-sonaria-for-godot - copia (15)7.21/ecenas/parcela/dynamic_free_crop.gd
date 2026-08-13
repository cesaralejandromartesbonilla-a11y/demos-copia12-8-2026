extends Area3D
class_name DynamicFreeCrop

enum State { GROWING, READY, PEST_INFESTED }
var current_state: State = State.GROWING

var seed_data: SeedData = null
var seed_item_data: ItemData = null
var growth_progress: float = 0.0
var current_visual_stage: int = -1
var current_water: float = 30.0 
var is_submerged: bool = false
var is_fertilized: bool = false
var is_checking_environment: bool = true

@onready var crop_mesh: MeshInstance3D = $CropMesh
@onready var item_base_scene = preload("res://items/pickable_item.tscn")

func _ready() -> void:
	add_to_group("crop_plot")
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	WeatherManager.time_changed.connect(_on_global_time_tick)

# NUEVA INICIALIZACIÓN: Ahora recibe el ItemData directamente desde la mano
func initialize_crop(data: SeedData, original_item: ItemData) -> void:
	seed_data = data
	seed_item_data = original_item # Guardado seguro
	current_state = State.GROWING
	growth_progress = 0.0
	current_visual_stage = -1
	is_fertilized = false
	is_checking_environment = true # Pausa temporal de crecimiento
	
	if crop_mesh:
		crop_mesh.mesh = null
		crop_mesh.material_override = null
		
	_update_visuals()
	
	# VENTANA DE TOLERANCIA: Esperamos 5 segundos reales a que las físicas se estabilicen
	get_tree().create_timer(5.0).timeout.connect(_validate_environment_requirements)

# --- SISTEMA DE VALIDACIÓN CON TOLERANCIA ---
func _validate_environment_requirements() -> void:
	_scan_environment() # Escaneo fresco después de 5 segundos
	
	if seed_data:
		# Si requiere estar sumergido (Alga) y el Area3D dice que NO está en agua:
		if seed_data.requires_submerged and not is_submerged:
			print("[Farming Libre] No es un entorno acuático para: ", seed_data.resource_name, ". Reembolsando semilla...")
			_abort_and_refund_seed()
			return
			
		# Si es una planta terrestre y la plantaste en medio del océano:
		if not seed_data.requires_submerged and is_submerged:
			print("[Farming Libre] Cultivo terrestre ahogado. Reembolsando semilla...")
			_abort_and_refund_seed()
			return

	# Si pasa la prueba, quitamos el bloqueo y la planta empezará a crecer normalmente
	is_checking_environment = false
	print("[Farming Libre] Entorno validado con éxito. El cultivo libre comienza a crecer.")

func _abort_and_refund_seed() -> void:
	# Devuelve exactamente la semilla que tenías en la mano
	if seed_item_data and item_base_scene:
		_spawn_item(seed_item_data)
	queue_free()

# --- DETECTOR DE ENTORNO ---
func _scan_environment() -> void:
	var overlapping = get_overlapping_areas()
	var found_water = false
	for area in overlapping:
		if _is_area_water(area):
			found_water = true
			break
	is_submerged = found_water

func _on_area_entered(area: Area3D) -> void:
	if _is_area_water(area):
		is_submerged = true

func _on_area_exited(area: Area3D) -> void:
	if _is_area_water(area):
		_scan_environment()

func _is_area_water(area: Area3D) -> bool:
	return area.is_in_group("agua") or area.is_in_group("water")

# --- LÓGICA DE TIEMPO Y CRECIMIENTO ---
func _on_global_time_tick(_current_time: float) -> void:
	# Agregamos la condición de que no procese crecimiento si sigue en los 5 segundos de tolerancia
	if current_state != State.GROWING or seed_data == null or is_checking_environment: return
	
	if seed_data.requires_submerged and not is_submerged: return 
		
	if seed_data.vulnerable_to_pests and randf() < 0.05:
		current_state = State.PEST_INFESTED
		_update_visuals()
		return
	
	var speed_multiplier = 2.0 if is_fertilized else 1.0 
	var is_raining = (WeatherManager.current_weather == WeatherManager.WeatherType.RAIN)
	if is_raining: current_water += 2.0 
	
	var can_grow = false
	
	match seed_data.crop_type:
		SeedData.CropType.FUNGUS:
			return
			
		SeedData.CropType.SINGLE_HARVEST, SeedData.CropType.PERENNIAL:
			if is_submerged:
				can_grow = true
			elif current_water >= (seed_data.water_needed * 0.1): 
				can_grow = true
				current_water -= 1.0

	if can_grow:
		growth_progress += 0.2 * speed_multiplier
	else:
		growth_progress += 0.04 * speed_multiplier 
		
	if growth_progress >= seed_data.grow_time_ticks:
		current_state = State.READY
		print("¡Cultivo libre listo para cosechar!")
		
	_update_visuals()

# --- INTERACCIONES COMPLETA (RIEGO, FERTILIZANTE, PLAGAS Y HONGOS) ---
func interact(player: Node3D) -> void:
	if seed_data == null: return
	
	var hands = player.get_node_or_null("HandsInventory")
	var hand_item: PickableItem = null
	if hands:
		hand_item = hands.item_in_right if hands.item_in_right else hands.item_in_left
	
	match current_state:
		State.GROWING:
			# CASO ESPECIAL 1: Es un Hongo (Necesita comer materia orgánica)
			if seed_data.crop_type == SeedData.CropType.FUNGUS:
				if hand_item and hand_item.is_in_group("organico"):
					var compost_added: float = 0.0
					if "compost_value" in hand_item.data and hand_item.data.compost_value > 0.0:
						compost_added = hand_item.data.compost_value
					elif "nutrition_value" in hand_item.data and hand_item.data.nutrition_value > 0.0:
						compost_added = hand_item.data.nutrition_value
					else:
						compost_added = 10.0 
						
					growth_progress += compost_added
					hands.consume_item(hand_item)
					
					print("Hongo libre alimentado. Progreso: ", int(growth_progress), "/", int(seed_data.grow_time_ticks))
					
					if growth_progress >= seed_data.grow_time_ticks:
						current_state = State.READY
						_update_visuals()
				else:
					print("El hongo necesita materia orgánica de tu mano.")
			
			# CASO COMÚN: Plantas normales en crecimiento
			else:
				# Regar de forma manual
				if hand_item and hand_item.is_in_group("agua") and not is_submerged:
					current_water = 100.0
					print("Planta libre regada manualmente.")
					_drain_water_item(hand_item)
				# Fertilizar
				elif hand_item and hand_item.data.is_fertilizer and not is_fertilized:
					is_fertilized = true
					hands.consume_item(hand_item)
					print("Planta libre fertilizada. ¡Crecerá el doble de rápido!")
				else:
					print("Progreso de crecimiento libre: ", int(growth_progress), "/", int(seed_data.grow_time_ticks))
				
		State.PEST_INFESTED:
			if hand_item and hand_item.data.is_pest_killer:
				current_state = State.GROWING
				print("Plaga eliminada del cultivo libre.")
				_update_visuals()
			else:
				print("¡Este cultivo libre tiene una plaga! Necesitas un pesticida.")
				
		State.READY:
			_harvest()

# --- COSECHA Y DESTINO (PERENNE VS COSECHA ÚNICA) ---
func _harvest() -> void:
	if seed_data.result_item_data and item_base_scene:
		var total_drops = seed_data.drop_amount + (2 if is_fertilized else 0)
		for i in range(total_drops):
			_spawn_item(seed_data.result_item_data)
			
	if seed_data.secondary_result_data and item_base_scene:
		_spawn_item(seed_data.secondary_result_data)
		
	# Comprobación de inmortalidad (Perennes y Hongos se quedan en el mundo)
	if seed_data.crop_type == SeedData.CropType.PERENNIAL or seed_data.crop_type == SeedData.CropType.FUNGUS:
		current_state = State.GROWING
		is_fertilized = false
		
		var retain_ratio = 0.0
		if "retained_growth_ratio" in seed_data:
			retain_ratio = seed_data.retained_growth_ratio
			
		growth_progress = seed_data.grow_time_ticks * retain_ratio
		current_visual_stage = -1
		_update_visuals()
	else:
		# SINGLE_HARVEST se destruye y desaparece de la faz de la tierra
		queue_free()

# --- UTILIDADES ---
func _drain_water_item(water_item: PickableItem) -> void:
	if water_item.data.result_item_data != null:
		water_item.data = water_item.data.result_item_data
		if water_item.mesh_instance and water_item.data.item_mesh:
			water_item.mesh_instance.mesh = water_item.data.item_mesh
		water_item.remove_from_group("agua")

func _spawn_item(data: ItemData) -> void:
	var drop = item_base_scene.instantiate()
	drop.data = data 
	get_tree().current_scene.add_child(drop)
	drop.global_position = global_position + Vector3(randf_range(-0.3, 0.3), 0.5, randf_range(-0.3, 0.3))

func _update_visuals() -> void:
	if seed_data == null or seed_data.visual_data == null: return
	var vis_data = seed_data.visual_data
	var progress_ratio = clamp(growth_progress / seed_data.grow_time_ticks, 0.0, 1.0)
	
	if vis_data.style == CropVisualData.VisualStyle.COLOR_SHIFT:
		if not crop_mesh.mesh or crop_mesh.mesh != vis_data.single_mesh:
			crop_mesh.mesh = vis_data.single_mesh
			var mate = StandardMaterial3D.new()
			crop_mesh.material_override = mate
			
		var mat = crop_mesh.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = vis_data.start_color.lerp(vis_data.ready_color, progress_ratio)
			
	elif vis_data.style == CropVisualData.VisualStyle.MULTIPLE_MODELS:
		var new_stage = 0
		if progress_ratio >= 0.66: new_stage = 2
		elif progress_ratio >= 0.33: new_stage = 1
		
		if new_stage != current_visual_stage:
			_transition_to_stage(new_stage, vis_data)

func _transition_to_stage(new_stage: int, vis_data: CropVisualData) -> void:
	var new_mesh_data = null
	match new_stage:
		0: new_mesh_data = vis_data.sprout_mesh
		1: new_mesh_data = vis_data.growing_mesh
		2: new_mesh_data = vis_data.ready_mesh
		
	if new_mesh_data == null: return
		
	var new_instance = MeshInstance3D.new()
	new_instance.mesh = new_mesh_data
	add_child(new_instance)
	
	if crop_mesh and crop_mesh.mesh != null:
		var old_mesh = crop_mesh
		var tween = create_tween().set_parallel(true)
		new_instance.scale = Vector3.ZERO
		tween.tween_property(new_instance, "scale", Vector3.ONE, vis_data.transition_duration).set_trans(Tween.TRANS_BACK)
		tween.tween_property(old_mesh, "scale", Vector3.ZERO, vis_data.transition_duration)
		tween.chain().tween_callback(old_mesh.queue_free)
	else:
		new_instance.scale = Vector3.ONE
		if crop_mesh: crop_mesh.queue_free()
		
	crop_mesh = new_instance
	current_visual_stage = new_stage

func save_data() -> Dictionary:
	var save_dict = {
		"filename" : get_scene_file_path(),
		"parent" : str(get_parent().get_path()) if get_parent() else "",
		"pos_x" : global_position.x,
		"pos_y" : global_position.y,
		"pos_z" : global_position.z,
		"current_state" : current_state,
		"is_fertilized" : is_fertilized,
		"growth_progress" : growth_progress,
		"current_water": current_water,
		"is_submerged": is_submerged,
		"seed_data_path" : "",
		"seed_item_path" : ""
	}
	if seed_data != null:
		save_dict["seed_data_path"] = seed_data.resource_path
	if seed_item_data != null:
		save_dict["seed_item_path"] = seed_item_data.resource_path
	return save_dict

func load_data(data: Dictionary) -> void:
	global_position = Vector3(data["pos_x"], data["pos_y"], data["pos_z"])
	current_state = data["current_state"] as State
	is_fertilized = data["is_fertilized"]
	growth_progress = data["growth_progress"]
	current_water = data["current_water"]
	is_submerged = data["is_submerged"]
	
	# CRÍTICO: Al cargar, saltamos la validación de 5s para que no se autoelimine por error
	is_checking_environment = false 
	
	if data["seed_data_path"] != "":
		seed_data = load(data["seed_data_path"])
	if data["seed_item_path"] != "":
		seed_item_data = load(data["seed_item_path"])
		
	_update_visuals()
