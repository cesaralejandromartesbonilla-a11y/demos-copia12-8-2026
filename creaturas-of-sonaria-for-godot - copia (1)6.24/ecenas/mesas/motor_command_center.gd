extends Area3D
class_name MotorCommandCenter

@export_group("Configuración Global")
@export var sector_name: String = "Sector Mecánico"

@export_group("Conexiones Físicas")
@export var main_power_receiver: PowerReceiverComponent

var is_logic_transmitter: bool = true
var logic_transmitter_component = self
var my_logic_grid 
var connected_logic_nodes: Array = []
var is_sector_active: bool = false

@onready var ui_scene = preload("res://ecenas/mesas/motor_manager_hud.tscn")
var is_in_use: bool = false

func _ready() -> void:
	add_to_group("estructuras")
	add_to_group("managers")

func _process(delta: float) -> void:
	if not is_sector_active: return
	
	if main_power_receiver:
		var power_ratio = main_power_receiver.try_consume_power(delta)
		if power_ratio < 1.0:
			print("¡Alerta! Tensión insuficiente en Central de Motores. Apagando sector...")
			_shutdown_sector()

func interact(_player: Node3D) -> void:
	if is_in_use or ui_scene == null: return
	
	var ui_instance = ui_scene.instantiate()
	get_tree().current_scene.add_child(ui_instance)
	
	ui_instance.setup(self)
	
	is_in_use = true
	ui_instance.tree_exited.connect(func(): is_in_use = false)

# ==========================================
# LECTURA DE DATOS PARA LA INTERFAZ
# ==========================================
func get_motors_status() -> Array:
	var status_list = []
	
	if my_logic_grid == null or not my_logic_grid is Dictionary: 
		return status_list
	
	for logic_rec in my_logic_grid.receivers:
		if logic_rec.processor == null: continue
		var proc = logic_rec.processor
		var parent = proc.get_parent()
		
		# FILTRO VITAL: Aceptamos Motores Rotativos y Pistones
		if not (parent is MotorHingeMachine or parent is PistonMachine):
			continue
		
		var has_power = false
		if proc.power_receiver:
			var enchufe = proc.power_receiver.get("my_connector")
			if enchufe != null and enchufe.get("my_grid") != null:
				has_power = true
				
		var has_logic = true 
		var state = proc.current_state 
		
		# Intentamos leer el machine_name del inspector, si no, usamos el nombre del nodo
		var m_name = parent.machine_name if "machine_name" in parent else parent.name
		
		status_list.append({
			"machine_name": m_name,
			"power_ok": has_power,
			"logic_ok": has_logic,
			"work_state": state,
			"motor_ref": parent,
			"processor_ref": proc
		})
		
	return status_list

# ==========================================
# CONTROL MAESTRO DE MOTORES
# ==========================================
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
		# Encendemos si es un motor y está apagado
		if proc and proc.get_parent() is MotorHingeMachine and not proc.is_machine_enabled:
			proc.toggle_machine()

func _shutdown_sector() -> void:
	is_sector_active = false
	if my_logic_grid == null: return
	for logic_rec in my_logic_grid.receivers:
		var proc = logic_rec.processor
		# Apagamos si es un motor y está encendido
		if proc and proc.get_parent() is MotorHingeMachine and proc.is_machine_enabled:
			proc.toggle_machine()
