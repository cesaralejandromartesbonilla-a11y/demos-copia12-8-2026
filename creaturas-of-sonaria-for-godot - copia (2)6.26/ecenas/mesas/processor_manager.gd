extends Area3D
class_name CommandCenter

@export_group("Configuración Global")
@export var sector_name: String = "Sector Industrial Alpha"

@export_group("Conexiones Físicas")
@export var main_power_receiver: PowerReceiverComponent # Enchufe de la Central

# --- Variables de Transmisión Lógica ---
# Esto convierte a la Central en un "Router" para el LogicManager
var is_logic_transmitter: bool = true
var logic_transmitter_component = self
var my_logic_grid 
var connected_logic_nodes: Array = []
# ---------------------------------------

var is_sector_active: bool = false

@onready var ui_scene = preload("res://ecenas/mesas/manager_hud.tscn")
var is_in_use: bool = false

func _ready() -> void:
	add_to_group("estructuras")
	add_to_group("managers")

func _process(delta: float) -> void:
	if not is_sector_active: return
	
	# MECÁNICA DE SEGURIDAD:
	# Si la Central se queda sin energía suficiente, se apaga a sí misma
	# y manda una señal de apagado a todo el sector para salvar el resto de la base.
	if main_power_receiver:
		var power_ratio = main_power_receiver.try_consume_power(delta)
		if power_ratio < 1.0:
			print("¡Alerta! Tensión insuficiente en Central. Apagando sector...")
			_shutdown_sector()

func interact(_player: Node3D) -> void:
	if is_in_use or ui_scene == null: return
	
	var ui_instance = ui_scene.instantiate()
	get_tree().current_scene.add_child(ui_instance)
	
	# Le pasamos este script a la UI para que pueda leer los estados
	ui_instance.setup(self)
	
	is_in_use = true
	ui_instance.tree_exited.connect(func(): is_in_use = false)

# ==========================================
# LECTURA DE DATOS PARA LA INTERFAZ (Los cuadritos)
# ==========================================
func get_machines_status() -> Array:
	var status_list = []
	
	if my_logic_grid == null or not my_logic_grid is Dictionary: 
		return status_list
	
	for logic_rec in my_logic_grid.receivers:
		if logic_rec.processor == null: continue
		var proc = logic_rec.processor
		
		# 1. ¿Tiene cable eléctrico? (CORREGIDO)
		var has_power = false
		if proc.power_receiver:
			# Buscamos el enchufe físico de la máquina (MachineConnector) de forma segura
			var enchufe = proc.power_receiver.get("my_connector")
			# Si el enchufe existe y está conectado a una red (my_grid)
			if enchufe != null and enchufe.get("my_grid") != null:
				has_power = true
				
		# 2. ¿Tiene cable lógico? 
		var has_logic = true 
		
		# 3. Estado de trabajo
		var state = proc.current_state 
		
		status_list.append({
			"machine_name": proc.get_parent().name, # Ej: "Mesa de Elaboración"
			"power_ok": has_power,
			"logic_ok": has_logic,
			"work_state": state,
			"processor_ref": proc # Por si desde la UI quieres darle una orden manual
		})
		
	return status_list

# ==========================================
# CONTROL REMOTO DEL SECTOR
# ==========================================
func select_and_start_mega_recipe() -> void:
	if my_logic_grid == null: return
	
	is_sector_active = true

func toggle_sector() -> void:
	is_sector_active = !is_sector_active
	if is_sector_active:
		_boot_sector()
	else:
		_shutdown_sector()

func _boot_sector() -> void:
	if my_logic_grid == null: return
	for logic_rec in my_logic_grid.receivers:
		var proc = logic_rec.processor
		if proc and not proc.is_machine_enabled:
			proc.toggle_machine()

func _shutdown_sector() -> void:
	is_sector_active = false
	if my_logic_grid == null: return
	for logic_rec in my_logic_grid.receivers:
		var proc = logic_rec.processor
		if proc and proc.is_machine_enabled:
			proc.toggle_machine()
