extends Area3D
class_name CropPlotBasic

enum State { EMPTY, GROWING, READY, DIRTY, PEST_INFESTED, NEEDS_CLEARING }
var current_state: State = State.EMPTY

@export var plot_type: SeedData.TerrainRequired = SeedData.TerrainRequired.NORMAL_PLOT
@onready var item_base_scene = preload("res://items/pickable_item.tscn")
@export var plot_mesh: MeshInstance3D 
@export var signals: bool = false

var current_crop_mesh: MeshInstance3D = null
var current_visual_stage: int = -1

var growth_progress: float = 0.0
var current_water: float = 0.0
var current_organic_matter: float = 0.0
var is_fertilized: bool = false
var planted_seed_data: SeedData = null
var is_submerged: bool = false

var custom_material: StandardMaterial3D

func _ready() -> void:
	# 1. ETAPA DETECTOR 
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	
	# Escaneo instantáneo al aparecer en el mundo
	_scan_environment()
	
	# 2. ETAPA OPERATIVA
	WeatherManager.time_changed.connect(_on_global_time_tick)
	
	if plot_mesh:
		custom_material = StandardMaterial3D.new()
		plot_mesh.material_override = custom_material
		
	add_to_group("crop_plot")
	add_to_group("estructuras")
	_update_visuals()

func _process(_delta: float) -> void:
	if current_state == State.GROWING and planted_seed_data and planted_seed_data.visual_data:
		var vis_data = planted_seed_data.visual_data
		var progress_ratio = clamp(growth_progress / planted_seed_data.grow_time_ticks, 0.0, 1.0)
		
		if vis_data.style == CropVisualData.VisualStyle.COLOR_SHIFT:
			_process_color_shift(vis_data, progress_ratio)
		elif vis_data.style == CropVisualData.VisualStyle.MULTIPLE_MODELS:
			_process_model_stages(vis_data, progress_ratio)

# --- SISTEMA DETECTOR DE ENTORNO ---
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
		if signals:
			print("[Detector] Parcela sumergida detectada.")

func _on_area_exited(area: Area3D) -> void:
	if _is_area_water(area):
		_scan_environment()

func _is_area_water(area: Area3D) -> bool:
	return area.is_in_group("agua") or area.is_in_group("water")

# --- LÓGICA DE TIEMPO Y CRECIMIENTO ---
func _on_global_time_tick(_current_time: float) -> void:
	if current_state != State.GROWING or planted_seed_data == null: return
	
	if planted_seed_data.requires_submerged and not is_submerged:
		return 
		
	if planted_seed_data.vulnerable_to_pests and randf() < 0.05:
		current_state = State.PEST_INFESTED
		if signals:
			print("¡Una plaga ha atacado el cultivo!")
		_update_visuals()
		return
	
	var speed_multiplier = 2.0 if is_fertilized else 1.0 
	var is_raining = (WeatherManager.current_weather == WeatherManager.WeatherType.RAIN)
	if is_raining: current_water += 2.0 
	
	var can_grow = false
	
	match planted_seed_data.crop_type:
		SeedData.CropType.FUNGUS:
			return 
			
		SeedData.CropType.SINGLE_HARVEST, SeedData.CropType.PERENNIAL:
			if is_submerged:
				can_grow = true
			elif current_water >= (planted_seed_data.water_needed * 0.1): 
				can_grow = true
				current_water -= 1.0

	if can_grow:
		growth_progress += 1.0 * speed_multiplier
		if signals:
			print("[Compostador] Crecimiento DETENIDO: Sin materia orgánica en depósito.")
	else:
		growth_progress += 0.2 * speed_multiplier 
		
	if growth_progress >= planted_seed_data.grow_time_ticks:
		current_state = State.READY
		_update_visuals()
		if signals:
			print("[Compostador] ¡Proceso de compostaje FINALIZADO! Listo para recoger.")
		
# --- INTERACCIONES ---
func interact(player: Node3D) -> void:
	var hands = player.get_node_or_null("HandsInventory")
	var hand_item: PickableItem = null
	
	if hands:
		if hands.item_in_right: hand_item = hands.item_in_right
		elif hands.item_in_left: hand_item = hands.item_in_left
	
	match current_state:
		State.EMPTY:
			if hand_item and hand_item.data.seed_data != null:
				_try_plant_seed(hand_item, hands)
			else:
				if signals:
					print("Necesitas una semilla compatible en la mano.")
				
		State.GROWING:
			if planted_seed_data.crop_type == SeedData.CropType.FUNGUS:
				if hand_item and hand_item.is_in_group("organico"):
					# --- NUEVA LÓGICA: Leer compost_value ---
					var compost_added: float = 0.0
					
					# 1. Prioridad absoluta: compost_value del ItemData
					if "compost_value" in hand_item.data and hand_item.data.compost_value > 0.0:
						compost_added = hand_item.data.compost_value
					# 2. Respaldo: nutrition_value (por si a un alimento se te olvida ponerle compost_value)
					elif "nutrition_value" in hand_item.data and hand_item.data.nutrition_value > 0.0:
						compost_added = hand_item.data.nutrition_value
					# 3. Valor de seguridad por defecto
					else:
						compost_added = 10.0 
						
					growth_progress += compost_added
					hands.consume_item(hand_item)
					
					if signals:
						print("[Compostador] Hongo alimentado con +", compost_added, ". Progreso: ", int(growth_progress), "/", int(planted_seed_data.grow_time_ticks))
					
					if growth_progress >= planted_seed_data.grow_time_ticks:
						current_state = State.READY
						_update_visuals()
						if signals:
							print("[Compostador] ¡Proceso completado! Listo para recolectar.")
				else:
					if signals:
						print("El hongo necesita materia orgánica. Sostén un ítem del grupo 'organico'. Progreso: ", int(growth_progress), "/", int(planted_seed_data.grow_time_ticks))
			
			else:
				if hand_item and hand_item.is_in_group("agua") and not is_submerged:
					_water_plot(hand_item)
				elif hand_item and hand_item.data.is_fertilizer and not is_fertilized:
					is_fertilized = true
					hands.consume_item(hand_item)
					if signals:
						print("Parcela fertilizada.")
				else:
					if signals:
						if hand_item:
							print("--- DIAGNÓSTICO DEL COMPOSTADOR ---")
							print("Nombre del ítem en mano: ", hand_item.name)
							print("Grupos del ítem: ", hand_item.get_groups())
							print("ID CropType de la semilla: ", planted_seed_data.crop_type)
					if signals:
						print("Progreso de crecimiento: ", int(growth_progress), "/", int(planted_seed_data.grow_time_ticks))
				
		State.PEST_INFESTED:
			if hand_item and hand_item.data.is_pest_killer:
				current_state = State.GROWING
				if signals:
					print("Plaga eliminada. El cultivo vuelve a crecer.")
			else:
				if signals:
					print("¡Necesitas algo para matar las plagas!")
				
		State.READY:
			_harvest()
			
		State.NEEDS_CLEARING:
			if hand_item and hand_item.data.is_fire_starter:
				if signals:
					print("Quemando restos agrícolas...")
				_reset_plot()
			else:
				if signals:
					print("Necesitas fuego para limpiar los restos de este cultivo.")
				
		State.DIRTY:
			if signals:
				print("Limpiando parcela...")
			_reset_plot()

func _try_plant_seed(seed_item: PickableItem, hands: Node) -> void:
	var s_data = seed_item.data.seed_data
	
	if s_data.required_terrain != plot_type:
		if signals:
			print("Este no es el terreno adecuado para esta semilla.")
		return
		
	planted_seed_data = s_data
	growth_progress = 0.0
	current_state = State.GROWING
	hands.consume_item(seed_item)
	_update_visuals()
	if signals:
		print("Semilla plantada.")

func _water_plot(water_item: PickableItem) -> void:
	current_water = 100.0
	if signals:
		print("Parcela regada.")
	if water_item.data.result_item_data != null:
		water_item.data = water_item.data.result_item_data
		if water_item.mesh_instance and water_item.data.item_mesh:
			water_item.mesh_instance.mesh = water_item.data.item_mesh
		water_item.remove_from_group("agua")

func _harvest() -> void:
	if planted_seed_data == null: return
	
	if planted_seed_data.result_item_data and item_base_scene:
		var total_drops = planted_seed_data.drop_amount + (2 if is_fertilized else 0) 
		for i in range(total_drops):
			_spawn_item(planted_seed_data.result_item_data)
			
	if planted_seed_data.secondary_result_data and item_base_scene:
		_spawn_item(planted_seed_data.secondary_result_data)
	
	if planted_seed_data.crop_type == SeedData.CropType.PERENNIAL or planted_seed_data.crop_type == SeedData.CropType.FUNGUS:
		current_state = State.GROWING
		is_fertilized = false 
		
		# --- NUEVA LÓGICA DE BASE RETENIDA ---
		var retain_ratio = 0.0
		if "retained_growth_ratio" in planted_seed_data:
			retain_ratio = planted_seed_data.retained_growth_ratio
			
		growth_progress = planted_seed_data.grow_time_ticks * retain_ratio
		
		if retain_ratio <= 0.0:
			# Si es 0.0, se arranca todo de raíz. Volvemos a empezar limpios.
			if current_crop_mesh:
				current_crop_mesh.queue_free()
				current_crop_mesh = null
			current_visual_stage = -1
		else:
			# MAGIA: Si retiene progreso, no borramos el mesh viejo.
			# Solo reseteamos el 'current_visual_stage'.
			# En el próximo frame, tu función '_process_model_stages' verá que el ratio
			# bajó y usará el Tween para encoger el hongo listo y hacer crecer la base. ¡Se ve increíble!
			current_visual_stage = -1
			
		if signals:
			print("Cosecha completada. Progreso retenido: ", retain_ratio * 100, "%")
	else:
		_reset_plot()
	
	_update_visuals()

func _spawn_item(data: ItemData) -> void:
	var drop = item_base_scene.instantiate()
	drop.data = data 
	get_tree().current_scene.add_child(drop)
	drop.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 1.0, randf_range(-0.5, 0.5))

func _process_color_shift(vis_data: CropVisualData, ratio: float) -> void:
	if not current_crop_mesh:
		current_crop_mesh = MeshInstance3D.new()
		current_crop_mesh.mesh = vis_data.single_mesh
		add_child(current_crop_mesh)
		var mate = StandardMaterial3D.new()
		current_crop_mesh.set_surface_override_material(0, mate)
		
	var mat = current_crop_mesh.get_surface_override_material(0) as StandardMaterial3D
	if mat:
		mat.albedo_color = vis_data.start_color.lerp(vis_data.ready_color, ratio)

func _process_model_stages(vis_data: CropVisualData, ratio: float) -> void:
	var new_stage = 0
	if ratio >= 0.66: new_stage = 2
	elif ratio >= 0.33: new_stage = 1
	
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
	
	if current_crop_mesh:
		var old_mesh = current_crop_mesh
		var tween = create_tween().set_parallel(true)
		new_instance.scale = Vector3.ZERO
		tween.tween_property(new_instance, "scale", Vector3.ONE, vis_data.transition_duration).set_trans(Tween.TRANS_BACK)
		tween.tween_property(old_mesh, "scale", Vector3.ZERO, vis_data.transition_duration)
		tween.chain().tween_callback(old_mesh.queue_free)
	else:
		new_instance.scale = Vector3.ONE
		
	current_crop_mesh = new_instance
	current_visual_stage = new_stage

func _reset_plot() -> void:
	if current_crop_mesh:
		current_crop_mesh.queue_free()
		current_crop_mesh = null
	current_visual_stage = -1
	
	current_state = State.EMPTY
	planted_seed_data = null
	growth_progress = 0.0
	current_water = 0.0
	current_organic_matter = 0.0
	is_fertilized = false

func save_data() -> Dictionary:
	var save_dict = {
		"filename" : get_scene_file_path(),
		"parent" : str(get_parent().get_path()) if get_parent() else "",
		"pos_x" : global_position.x,
		"pos_y" : global_position.y,
		"pos_z" : global_position.z,
		"rot_x" : global_rotation.x,
		"rot_y" : global_rotation.y,
		"rot_z" : global_rotation.z,
		"current_state" : current_state,
		"current_compost" : is_fertilized,
		"growth_progress" : growth_progress,
		"is_watered": is_submerged,
		"planted_seed_path" : ""
	}
	if planted_seed_data != null:
		save_dict["planted_seed_path"] = planted_seed_data.resource_path
	return save_dict

func load_data(data: Dictionary) -> void:
	global_position = Vector3(data["pos_x"], data["pos_y"], data["pos_z"])
	global_rotation = Vector3(data["rot_x"], data["rot_y"], data["rot_z"])
	current_state = data["current_state"] as State
	is_fertilized = data["current_compost"]
	growth_progress = data["growth_progress"]
	is_submerged = data["is_watered"]
	
	# Cargamos el recurso .tres de la semilla de forma segura
	if data["planted_seed_path"] != "":
		planted_seed_data = load(data["planted_seed_path"])
	
	_update_visuals()

func _update_visuals() -> void:
	pass
