extends CanvasLayer
class_name ManagerHUD

var central: CommandCenter

@onready var machine_list_container = $PanelBackground/HBoxContainer/MachineList/RecipeList
@onready var recipe_list_container = $PanelBackground/HBoxContainer/MachineList/RecipeList
@onready var master_power_btn = $PanelBackground/Botonshift
@onready var refresh_timer = $RefreshTimer

func setup(_central: CommandCenter) -> void:
	central = _central
	
	# Botón para encender/apagar TODO el sector
	master_power_btn.text = "Apagar Sector" if central.is_sector_active else "Encender Sector"
	master_power_btn.pressed.connect(_on_master_power_toggled)
	
	$PanelBackground/BotonCerrar.pressed.connect(func(): queue_free())
	
	if refresh_timer:
		refresh_timer.timeout.connect(_update_status_board)
	
	_update_status_board()

func _on_master_power_toggled() -> void:
	central.toggle_sector()
	master_power_btn.text = "Apagar Sector" if central.is_sector_active else "Encender Sector"
	_update_status_board()

# ==========================================
# 1. MOSTRAR LAS MEGA-RECETAS
# ==========================================
func _populate_mega_recipes(delta) -> void:
	for child in recipe_list_container.get_children():
		child.queue_free()
		
	for mega_recipe in central.available_mega_recipes:
		var btn = Button.new()
		# Asumimos que ProductionLineData tiene un nombre, ajústalo según tu clase
		btn.text = "Ejecutar Línea: " + mega_recipe.resource_name 
		
		btn.pressed.connect(func(): 
			_update_status_board()
		)
		recipe_list_container.add_child(btn)

# ==========================================
# 2. EL PANEL DE MONITOREO (Los Cuadritos)
# ==========================================
func _update_status_board() -> void:
	if central == null: return
	
	# Limpiamos la lista anterior
	for child in machine_list_container.get_children():
		child.queue_free()
		
	# Obtenemos los datos fresquitos de la Central
	var status_data = central.get_machines_status()
	
	if status_data.is_empty():
		var lbl = Label.new()
		lbl.text = "Ninguna máquina detectada en la red lógica."
		machine_list_container.add_child(lbl)
		return
		
	# Creamos una fila de texto por cada máquina conectada
	for data in status_data:
		var row = Label.new()
		
		# Decidimos los colores de los cuadritos
		var box_power = "🟩" if data.power_ok else "🟥"
		var box_logic = "🟩" if data.logic_ok else "🟥"
		var box_state = "🟥"
		
		match data.work_state:
			"WORKING": box_state = "🟩"
			"JAMMED": box_state = "🟧"
			"OFF", "NO_POWER", "NO_FUEL", "NO_FLUID", "IDLE": box_state = "🟥"
			
		# Armamos el texto final
		row.text = "[E:" + box_power + " D:" + box_logic + "] " + data.machine_name + " - Estado: " + box_state
		
		machine_list_container.add_child(row)
