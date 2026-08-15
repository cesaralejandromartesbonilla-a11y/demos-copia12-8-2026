extends CanvasLayer
class_name MachineHUD

var processor: ProcessorComponent
var player_hands: Node 
var item_base_scene: PackedScene
var generador_conectado: Node3D

# --- REFERENCIAS ---
@onready var seccion_izq = $PanelBackground/HBoxContainer/SeccionIzquierda
@onready var seccion_der = $PanelBackground/HBoxContainer/SeccionDerecha
@onready var titulo_combustible = $PanelBackground/HBoxContainer/SeccionDerecha/VBoxContainer/TituloCombustible
@onready var titulo_principal = $PanelBackground/TituloPrincipal

@onready var recipe_list = $PanelBackground/HBoxContainer/SeccionIzquierda/ScrollContainer/RecipeList
@onready var inventory_list = $PanelBackground/HBoxContainer/SeccionCentro/ScrollContainer/InventoryList

@onready var status_label = $PanelBackground/HBoxContainer/SeccionDerecha/VBoxContainer/StatusLabel
@onready var work_bar = $PanelBackground/HBoxContainer/SeccionDerecha/VBoxContainer/WorkBar
@onready var fuel_bar = $PanelBackground/HBoxContainer/SeccionDerecha/VBoxContainer/FuelBar

var fluid_label: Label

func setup(_processor: ProcessorComponent, _player_hands: Node, _base_scene: PackedScene, _name: String) -> void:
	processor = _processor
	player_hands = _player_hands
	item_base_scene = _base_scene
	
	# Ponemos el título
	if titulo_principal:
		titulo_principal.text = "--- " + _name + " ---"
	
	if generador_conectado != null:
		var power_comp = generador_conectado.get_node_or_null("PowerGeneratorComponent")
		if power_comp:
			var kw_actual = power_comp.get_current_generation() 
			status_label.text = "Generando: " + str(kw_actual) + " KW"
	
	$PanelBackground/BotonCerrar.pressed.connect(_on_close)
	
	# --- 1. MODULARIDAD VISUAL ---
	var has_burner = processor.burner != null
	var has_recipes = processor.recipes.size() > 0
	
	fuel_bar.visible = has_burner
	titulo_combustible.visible = has_burner
	seccion_izq.visible = has_recipes
	
	seccion_der.visible = has_burner or has_recipes
	
	var vbox_derecha = $PanelBackground/HBoxContainer/SeccionDerecha/VBoxContainer
	
	fluid_label = Label.new()
	fluid_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fluid_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0)) # Un tono azul para diferenciarlo
	vbox_derecha.add_child(fluid_label)
	
	var power_btn = Button.new()
	power_btn.text = "Apagar Máquina" if processor.is_machine_enabled else "Encender Máquina"
	
	power_btn.pressed.connect(func(): 
		processor.toggle_machine()
		power_btn.text = "Apagar Máquina" if processor.is_machine_enabled else "Encender Máquina"
	)
	
	var lights_btn = Button.new()
	lights_btn.text = "Apagar Luces" if processor.lights_enabled else "Encender Luces"
	
	lights_btn.pressed.connect(func(): 
		processor.toggle_lights()
		lights_btn.text = "Apagar Luces" if processor.lights_enabled else "Encender Luces"
	)
	
	vbox_derecha.add_child(lights_btn)
	vbox_derecha.add_child(power_btn)
	vbox_derecha.move_child(lights_btn, 1) 
	vbox_derecha.move_child(power_btn, 0) 
	
	# --- 2. CONEXIONES ---
	processor.progress_updated.connect(_on_work_progress)
	processor.status_changed.connect(_on_status_changed)
	
	if processor.input_inv: processor.input_inv.inventory_changed.connect(_update_inventory_ui)
	if processor.fuel_inv: processor.fuel_inv.inventory_changed.connect(_update_inventory_ui)
	if processor.output_inv: processor.output_inv.inventory_changed.connect(_update_inventory_ui)
		
	_populate_recipes()
	_update_inventory_ui()

func _process(_delta: float) -> void:
	if fuel_bar.visible and processor and processor.burner:
		fuel_bar.value = processor.burner.remaining_burn_time 

# --- RECETAS CON TEXTO DETALLADO ---
func _populate_recipes() -> void:
	for child in recipe_list.get_children(): child.queue_free()
		
	for recipe in processor.recipes:
		var btn = Button.new()
		var req_text = ""
		for req_item in recipe.required_items: req_text += req_item.item_name + ", "
			
		btn.text = "Fabricar: " + recipe.recipe_name + "\n[Requiere: " + req_text.trim_suffix(", ") + "]"
		
		btn.pressed.connect(func(): processor.start_recipe(recipe))
		
		recipe_list.add_child(btn)

func _update_inventory_ui() -> void:
	for child in inventory_list.get_children():
		child.queue_free()
		
	if processor.input_inv: _draw_inventory_section("Entrada (Para Procesar)", processor.input_inv)
	if processor.fuel_inv: _draw_inventory_section("Combustible", processor.fuel_inv)
	if processor.output_inv: _draw_inventory_section("Salida (Terminado)", processor.output_inv)

func _draw_inventory_section(title: String, inv: InventoryComponent) -> void:
	var title_lbl = Label.new()
	title_lbl.text = "--- " + title + " ---"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.2)) 
	inventory_list.add_child(title_lbl)
	
	if inv.stored_items.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "Vacío"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inventory_list.add_child(empty_lbl)
	else:
		var item_counts = {}
		var item_references = {} 
		
		for item in inv.stored_items:
			if item_counts.has(item.item_name):
				item_counts[item.item_name] += 1
			else:
				item_counts[item.item_name] = 1
				item_references[item.item_name] = item
				
		for item_name in item_counts:
			var item_btn = Button.new()
			item_btn.text = "> " + item_name + " x" + str(item_counts[item_name])
			item_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			
			item_btn.pressed.connect(_on_item_clicked.bind(item_references[item_name], inv))
			
			inventory_list.add_child(item_btn)
			
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	inventory_list.add_child(spacer)

func _on_item_clicked(item_data: ItemData, from_inv: InventoryComponent) -> void:
	if player_hands and item_base_scene:
		var physical_item = item_base_scene.instantiate()
		physical_item.data = item_data
		
		get_tree().current_scene.add_child(physical_item)
		
		if player_hands.try_pick_up(physical_item):
			from_inv.remove_item(item_data)
		else:
			physical_item.queue_free()
			status_label.text = "Manos llenas"

func _on_work_progress(percent: float) -> void:
	work_bar.value = percent * 100

func _on_status_changed(msg: String) -> void:
	status_label.text = msg

func _on_close() -> void:
	queue_free()
