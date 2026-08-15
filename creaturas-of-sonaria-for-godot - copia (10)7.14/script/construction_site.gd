extends Area3D
class_name ConstructionSite

# --- NUEVAS REFERENCIAS PARA AGRICULTURA LIBRE ---
var seed_data: SeedData = null
@export var free_crop_base_scene: PackedScene # Asigna aquí una escena base ligera para la planta libre

var blueprint: BlueprintData
var progress: Array[int] = [] 

@onready var preview_mesh = MeshInstance3D.new()
@onready var floating_label_scene = preload("res://test/damage_label.tscn")

func _ready() -> void:
	add_child(preview_mesh)
	
	# === MODO 1: CONSTRUCCIÓN TRADICIONAL ===
	if blueprint:
		progress.resize(blueprint.required_items.size())
		progress.fill(0)
			
		if blueprint.hologram_mesh:
			preview_mesh.mesh = blueprint.hologram_mesh
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.5, 0.5, 0.5, 0.5) 
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			preview_mesh.material_override = mat
			
		if blueprint.build_instantly:
			_finish_construction()
			
	# === MODO 2: SIEMBRA LIBRE Y DIRECTA ===
	elif seed_data:
		_setup_seed_hologram()
		# Como acordamos, las plantas sin plano se construyen e instancian inmediatamente
		_finish_construction()

func _setup_seed_hologram() -> void:
	if seed_data.visual_data == null: return
	var v_data = seed_data.visual_data
	
	# Extraemos dinámicamente la malla inicial según el estilo del recurso
	if v_data.style == CropVisualData.VisualStyle.COLOR_SHIFT:
		preview_mesh.mesh = v_data.single_mesh
		if v_data.single_mesh:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = v_data.start_color
			mat.albedo_color.a = 0.5 # Le damos transparencia de holograma
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			preview_mesh.material_override = mat
	else:
		preview_mesh.mesh = v_data.sprout_mesh
		if v_data.sprout_mesh:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0, 1, 0, 0.4) # Tinte verde holograma para el brote
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			preview_mesh.material_override = mat

func interact(player: Node3D) -> void:
	# Si es una semilla autoconstruida, no permitimos interacciones manuales de materiales
	if seed_data: return 
	
	var hands = player.get_node_or_null("HandsInventory")
	if not hands or not blueprint: return
	
	var item_to_use: PickableItem = null
	var hand_item_data = null
	
	if hands.item_in_right:
		hand_item_data = hands.item_in_right.data
		item_to_use = hands.item_in_right
	elif hands.item_in_left:
		hand_item_data = hands.item_in_left.data
		item_to_use = hands.item_in_left
		
	if item_to_use:
		var item_index = blueprint.required_items.find(hand_item_data)
		
		if item_index != -1: 
			var amount_needed = blueprint.required_amounts[item_index]
			var current_amount = progress[item_index] 
			
			if current_amount < amount_needed:
				hands.consume_item(item_to_use)
				progress[item_index] += 1 
				
				_spawn_floating_text("+1 " + str(hand_item_data.item_name), Color.GREEN)
				_check_if_finished()
			else:
				_spawn_floating_text("¡Suficiente " + str(hand_item_data.item_name) + "!", Color.YELLOW)
		else:
			_spawn_floating_text("Material incorrecto", Color.RED)
	else:
		var missing_text = "Falta material"
		for i in range(blueprint.required_items.size()):
			if progress[i] < blueprint.required_amounts[i]:
				missing_text = "Falta " + str(blueprint.required_items[i].item_name) + " (" + str(progress[i]) + "/" + str(blueprint.required_amounts[i]) + ")"
				break
		_spawn_floating_text(missing_text, Color.ORANGE)

func _check_if_finished() -> void:
	var is_finished = true
	for i in range(blueprint.required_items.size()):
		if progress[i] < blueprint.required_amounts[i]:
			is_finished = false
			break
			
	if is_finished:
		_finish_construction()

func _finish_construction() -> void:
	# --- FINALIZACIÓN DE ESTRUCTURA ---
	if blueprint:
		_spawn_floating_text("¡Terminado!", Color.AQUA)
		if blueprint.final_scene:
			var building = blueprint.final_scene.instantiate()
			get_tree().current_scene.add_child(building)
			building.global_position = global_position
			building.global_rotation = global_rotation
			
	# --- FINALIZACIÓN DE PLANTA LIBRE ---
	elif seed_data:
		_spawn_floating_text("¡Sembrado!", Color.GREEN)
		if free_crop_base_scene:
			var new_crop = free_crop_base_scene.instantiate()
			get_tree().current_scene.add_child(new_crop)
			new_crop.global_position = global_position
			new_crop.global_rotation = global_rotation
			
			# Inicializamos la planta pasándole los datos puros
			if new_crop.has_method("initialize_crop"):
				new_crop.initialize_crop(seed_data)
				
			# PASO CRÍTICO: La registramos en el mánager masivo para que empiece a crecer
			var manager = get_tree().get_first_node_in_group("crop_manager")
			if manager and manager.has_method("register_free_crop"):
				manager.register_free_crop(new_crop)
		else:
			printerr("Error: No se asignó 'free_crop_base_scene' en el ConstructionSite.")
		
	queue_free()

func _spawn_floating_text(texto: String, color: Color) -> void:
	if floating_label_scene == null: return
	
	var label = floating_label_scene.instantiate()
	get_tree().root.add_child(label) 
	label.global_position = global_position + Vector3(0, 2.0, 0) 
	
	if label.has_method("display_text"):
		label.display_text(texto, color)
	elif label.has_method("display"):
		label.display(0, color) 
		label.text = texto
