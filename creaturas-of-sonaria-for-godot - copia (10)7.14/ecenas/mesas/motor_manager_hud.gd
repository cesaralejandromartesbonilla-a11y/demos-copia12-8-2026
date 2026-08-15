extends CanvasLayer
class_name MotorManagerHUD

@export_group("Diseño de Interfaz")
@export var slider_custom_size: Vector2 = Vector2(200, 40)

var central: MotorCommandCenter
# Diccionario para guardar referencias a los textos y actualizarlos sin borrar los sliders
var status_labels: Dictionary = {} 

@onready var machine_list_container = $PanelBackground/HBoxContainer/ScrollContainer/VBoxContainer
@onready var master_power_btn = $PanelBackground/Botonshift
@onready var close_btn = $PanelBackground/BotonCerrar
@onready var refresh_timer = $RefreshTimer

func setup(_central: MotorCommandCenter) -> void:
	central = _central
	
	master_power_btn.text = "Apagar Motores" if central.is_sector_active else "Encender Motores"
	master_power_btn.pressed.connect(_on_master_power_toggled)
	
	close_btn.pressed.connect(func(): queue_free())
	
	# Construimos los sliders y textos UNA sola vez al abrir
	_build_ui_list()
	
	if refresh_timer:
		# El timer solo actualizará las luces de estado
		refresh_timer.timeout.connect(_refresh_status_texts)

func _on_master_power_toggled() -> void:
	central.toggle_sector()
	master_power_btn.text = "Apagar Motores" if central.is_sector_active else "Encender Motores"
	_refresh_status_texts()

# ==========================================
# 1. CONSTRUCCIÓN DE LA INTERFAZ FÍSICA
# ==========================================
func _build_ui_list() -> void:
	if central == null: return
	
	for child in machine_list_container.get_children():
		child.queue_free()
		
	status_labels.clear()
	var status_data = central.get_motors_status()
	
	if status_data.is_empty():
		var lbl = Label.new()
		lbl.text = "Ningún motor detectado en la red lógica."
		machine_list_container.add_child(lbl)
		return
		
	for data in status_data:
		# Creamos un contenedor vertical para agrupar [Estado del Motor] + [Sus Sliders]
		var motor_vbox = VBoxContainer.new()
		machine_list_container.add_child(motor_vbox)
		
		# --- A. Etiqueta de Estado ---
		var status_lbl = Label.new()
		motor_vbox.add_child(status_lbl)
		# Guardamos la etiqueta en el diccionario usando el procesador como "llave"
		status_labels[data.processor_ref] = status_lbl
		
		# --- B. Generar Sliders ---
		# SOLUCIÓN DEL ERROR: Cambiamos HingeJoint3D por Joint3D para que acepte ambos
		var actuators: Array[Joint3D] = []
		_find_actuators(data.motor_ref, actuators) 
		
		if actuators.is_empty():
			var err_lbl = Label.new()
			err_lbl.text = "  -> Sin ejes físicos detectados."
			err_lbl.modulate = Color(0.6, 0.6, 0.6) # Color gris
			motor_vbox.add_child(err_lbl)
		else:
			_populate_sliders_for_motor(data.motor_ref, actuators, motor_vbox)
			
		# --- C. Separador visual entre máquinas ---
		var sep = HSeparator.new()
		sep.custom_minimum_size = Vector2(0, 15)
		machine_list_container.add_child(sep)

	# Actualizamos el texto por primera vez
	_refresh_status_texts()

# Buscador adaptado usando Joint3D
func _find_actuators(node: Node, actuators_array: Array[Joint3D]) -> void:
	for child in node.get_children():
		if child is HingeJoint3D or child is SliderJoint3D:
			actuators_array.append(child)
		_find_actuators(child, actuators_array)

func _populate_sliders_for_motor(motor_machine: Node3D, actuators: Array[Joint3D], parent_container: Container) -> void:
	var max_speed = motor_machine.target_speed if "target_speed" in motor_machine else 5.0
		
	for i in range(actuators.size()):
		var act = actuators[i]
		
		var row = HBoxContainer.new()
		
		var lbl_name = Label.new()
		# Ajustamos el texto según el tipo
		lbl_name.text = ("  Eje " if act is HingeJoint3D else "  Pistón ") + str(i + 1) + ":" 
		lbl_name.custom_minimum_size = Vector2(80, 0)
		
		var slider = HSlider.new()
		slider.min_value = -1.0 
		slider.max_value = 1.0  
		slider.step = 0.01
		
		slider.custom_minimum_size = slider_custom_size
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		# Leemos la velocidad actual correctamente
		var current_vel = 0.0
		if act is HingeJoint3D:
			current_vel = act.get_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY)
		elif act is SliderJoint3D:
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
			_update_actuator_speed(motor_machine, act, value)
		)
		
		row.add_child(lbl_name)
		row.add_child(slider)
		row.add_child(lbl_val)
		
		parent_container.add_child(row)

func _update_actuator_speed(motor_machine: Node3D, act: Joint3D, direction_multiplier: float) -> void:
	var max_speed = motor_machine.target_speed if "target_speed" in motor_machine else 5.0
	var final_speed = max_speed * direction_multiplier
	
	# Aplicamos la velocidad según el tipo de articulación
	if act is HingeJoint3D:
		act.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, final_speed)
	elif act is SliderJoint3D:
		if motor_machine.has_method("set_piston_speed"):
			motor_machine.set_piston_speed(act, direction_multiplier)
	
	var node_a = act.get_node_or_null(act.node_a)
	var node_b = act.get_node_or_null(act.node_b)
	
	if node_a is RigidBody3D: node_a.sleeping = false
	if node_b is RigidBody3D: node_b.sleeping = false

# ==========================================
# 2. ACTUALIZACIÓN DEL TEXTO EN TIEMPO REAL
# ==========================================
func _refresh_status_texts() -> void:
	if central == null: return
	var status_data = central.get_motors_status()
	
	for data in status_data:
		if status_labels.has(data.processor_ref):
			var lbl = status_labels[data.processor_ref]
			
			var box_power = "🟩" if data.power_ok else "🟥"
			var box_logic = "🟩" if data.logic_ok else "🟥"
			var box_state = "🟥"
			
			match data.work_state:
				"WORKING", "IDLE": box_state = "🟩"
				"JAMMED": box_state = "🟧"
				"OFF", "NO_POWER", "NO_FUEL", "NO_FLUID": box_state = "🟥"
				
			lbl.text = "[E:" + box_power + " D:" + box_logic + "] " + data.machine_name + " - Estado: " + box_state
