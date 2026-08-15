extends Control
class_name ChimeraBuilderHUD

@onready var tabs_container = $LeftPanel/MainVBox/TabScroll/TabContainer
@onready var item_grid = $LeftPanel/MainVBox/GridScroll/ItemGrid
@onready var assembler = $AssemblerModule
@onready var sockets_manager = $BuildingSocketsManager
@export var player_dummy: CharacterBody3D

var categories: Array[String] = [
	"Pies", "Manos", "Extensiones", "Chasis", 
	"Torsos", "Caderas", "Cabezas", "Decoraciones"
]

func _ready():
	_setup_tabs()
	_evaluate_zero_state() # <- NUEVO: Revisar si nacemos de la nada

func _setup_tabs():
	for i in categories.size():
		var category = categories[i]
		var btn = Button.new()
		btn.text = category
		# Pasamos el índice entero 'i' en lugar de la cadena de texto
		btn.pressed.connect(func(): _on_tab_selected(i))
		tabs_container.add_child(btn)

func _on_tab_selected(category_index: int):
	_clear_grid()
	
	# Ahora enviamos el número entero sin problemas de tipo
	var parts = InventoryManager.get_parts_by_category(category_index)
	
	for part in parts:
		var item_btn = Button.new()
		item_btn.text = part.display_name
		item_btn.pressed.connect(func(): _select_part_for_building(part))
		item_grid.add_child(item_btn)

func _clear_grid():
	for child in item_grid.get_children():
		child.queue_free()

func _select_part_for_building(part: CreaturePartData):
	if part.slot_type == CreaturePartData.SlotType.CHASIS:
		# 1. Limpiamos las piezas viejas del ADN para empezar fresco
		assembler.active_dna.attached_parts.clear()
		# 2. Le asignamos la escena del chasis al ADN
		assembler.active_dna.chassis_scene = part.part_scene
		
		# 3. Forzamos el nacimiento del nuevo cuerpo usando la referencia exportada
		if player_dummy:
			assembler.apply_dna_transformation(player_dummy)
		else:
			push_error("HUD: No se ha asignado el PlayerDummy en el Inspector.")
		
		_unlock_all_tabs()
		
	else:
		if sockets_manager and sockets_manager.has_method("set_selected_part"):
			sockets_manager.set_selected_part(part)
		else:
			push_error("HUD: No se ha asignado el SocketsManager en el Inspector.")

func _evaluate_zero_state():
	if not assembler.active_dna or not assembler.active_dna.chassis_scene:
		# Pasamos el índice del Chasis (3) en lugar del String
		_lock_tabs_except(CreaturePartData.SlotType.CHASIS)
		_on_tab_selected(CreaturePartData.SlotType.CHASIS)
		print("Estado Cero detectado: Selecciona un Núcleo Base primero.")
	else:
		_unlock_all_tabs()
		_on_tab_selected(CreaturePartData.SlotType.CHASIS)

func _lock_tabs_except(allowed_category_index: int):
	for i in tabs_container.get_child_count():
		var btn = tabs_container.get_child(i)
		if btn is Button:
			# Bloquea el botón si su posición no coincide con la permitida
			btn.disabled = (i != allowed_category_index)

func _unlock_all_tabs():
	for btn in tabs_container.get_children():
		if btn is Button:
			btn.disabled = false
