extends CanvasLayer
class_name MotorHUD

@export_group("Diseño de Interfaz")
@export var slider_custom_size: Vector2 = Vector2(200, 40) 

var motor_machine: Node3D 
var processor: ProcessorComponent
var actuators: Array[Joint3D] = [] # Ahora acepta cualquier tipo de articulación

@onready var controls_container = $PanelBackground/HBoxContainer/ScrollContainer/VBoxContainer
@onready var toggle_btn = $PanelBackground/Botonshift
@onready var close_btn = $PanelBackground/BotonCerrar

func setup(_motor: Node3D, _processor: ProcessorComponent) -> void:
	motor_machine = _motor
	processor = _processor
	
	actuators.clear()
	_find_actuators(motor_machine)
	
	close_btn.pressed.connect(func(): queue_free())
	
	if processor:
		_update_toggle_btn_text()
		toggle_btn.pressed.connect(_on_toggle_pressed)
		processor.machine_state_changed.connect(_on_state_changed)
		
	_populate_sliders()

# Buscamos tanto ejes rotativos como pistones lineales
func _find_actuators(node: Node) -> void:
	for child in node.get_children():
		if child is HingeJoint3D or child is SliderJoint3D:
			actuators.append(child)
		_find_actuators(child) 

func _populate_sliders() -> void:
	for child in controls_container.get_children():
		child.queue_free()
		
	if actuators.is_empty():
		var lbl = Label.new()
		lbl.text = "Error: No se detectaron actuadores físicos."
		controls_container.add_child(lbl)
		return
		
	var max_speed = motor_machine.target_speed if "target_speed" in motor_machine else 5.0
		
	for i in range(actuators.size()):
		var act = actuators[i]
		var row = HBoxContainer.new()
		
		var lbl_name = Label.new()
		# Le damos un nombre distinto según lo que encuentre
		lbl_name.text = ("Eje " if act is HingeJoint3D else "Pistón ") + str(i + 1) + ":"
		lbl_name.custom_minimum_size = Vector2(80, 0)
		
		var slider = HSlider.new()
		slider.min_value = -1.0 
		slider.max_value = 1.0  
		slider.step = 0.01
		slider.custom_minimum_size = slider_custom_size
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		# Leemos la velocidad actual dependiendo del tipo de articulación
		var current_vel = 0.0
		if act is HingeJoint3D:
			current_vel = act.get_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY)
		elif act is SliderJoint3D:
			# Leemos la velocidad desde nuestro nuevo diccionario en la máquina
			if motor_machine.has_method("get_piston_speed"):
				current_vel = motor_machine.get_piston_speed(act) * max_speed
			
		if max_speed != 0:
			slider.value = current_vel / max_speed
		else:
			slider.value = 0.0
		
		var lbl_val = Label.new()
		lbl_val.text = str(int(slider.value * 100)) + "%"
		lbl_val.custom_minimum_size = Vector2(50, 0)
		lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		
		slider.value_changed.connect(func(value: float):
			lbl_val.text = str(int(value * 100)) + "%"
			_update_actuator_speed(act, value)
		)
		
		row.add_child(lbl_name)
		row.add_child(slider)
		row.add_child(lbl_val)
		controls_container.add_child(row)

func _update_actuator_speed(act: Joint3D, direction_multiplier: float) -> void: # En la HUD central el primer parámetro es motor_machine
	var max_speed = motor_machine.target_speed if "target_speed" in motor_machine else 5.0
	var final_speed = max_speed * direction_multiplier
	
	if act is HingeJoint3D:
		act.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, final_speed)
	elif act is SliderJoint3D:
		if motor_machine.has_method("set_piston_speed"):
			motor_machine.set_piston_speed(act, direction_multiplier)
			
	# Despertar físicas (igual que antes)
	var node_a = act.get_node_or_null(act.node_a)
	var node_b = act.get_node_or_null(act.node_b)
	if node_a is RigidBody3D: node_a.sleeping = false
	if node_b is RigidBody3D: node_b.sleeping = false

func _on_toggle_pressed() -> void:
	if processor:
		processor.toggle_machine()
		_update_toggle_btn_text()

func _update_toggle_btn_text() -> void:
	if processor:
		toggle_btn.text = "Apagar Sistema" if processor.is_machine_enabled else "Encender Sistema"

func _on_state_changed(_new_state: String) -> void:
	_update_toggle_btn_text()
