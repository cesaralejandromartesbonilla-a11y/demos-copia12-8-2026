extends Area3D
class_name MotorHingeMachine

@export_group("Configuración del Motor")
@export var machine_name: String = "Motor Rotativo"
@export var target_speed: float = 5.0 # Velocidad de giro (Radianes por segundo)
@export var max_torque: float = 100.0 # Fuerza del motor (Max Impulse)

@onready var ui_scene = preload("res://ecenas/mesas/motor_ui.tscn")
@onready var processor: ProcessorComponent = get_node_or_null("ProcessorComponent")

var is_in_use: bool = false

func _ready() -> void:
	add_to_group("estructuras")
	
	if processor:
		processor.machine_state_changed.connect(_on_machine_state_changed)
	else:
		print("Error: El Motor no encontró su ProcessorComponent.")
		
	_set_motor_active(false)

# Interfaz actualizada para abrir el menú
func interact(_player: Node3D) -> void:
	if is_in_use: return
	
	if ui_scene != null and processor != null:
		var ui_instance = ui_scene.instantiate()
		get_tree().current_scene.add_child(ui_instance)
		
		# Le pasamos el motor (self) y el procesador a la UI para que arme los sliders
		ui_instance.setup(self, processor)
		
		is_in_use = true
		ui_instance.tree_exited.connect(func(): is_in_use = false)
	else:
		print("Error: Falta ui_scene o ProcessorComponent en el Motor.")

func _on_machine_state_changed(new_state: String) -> void:
	match new_state:
		# IDLE significa que la máquina está ON y tiene recursos, pero no craftea.
		"IDLE", "WORKING":
			_set_motor_active(true)
		
		# Cualquier estado de falta de recursos o apagado detiene el eje
		"OFF", "NO_FUEL", "NO_POWER", "NO_FLUID", "JAMMED":
			_set_motor_active(false)

func _set_motor_active(active: bool) -> void:
	for child in get_children():
		if child is HingeJoint3D:
			child.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, active)
			
			if active:
				# Solo restauramos el torque (fuerza)
				child.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, max_torque)
			else:
				# Si se apaga, quitamos la fuerza física para que deje de empujar
				child.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, 0.0)
