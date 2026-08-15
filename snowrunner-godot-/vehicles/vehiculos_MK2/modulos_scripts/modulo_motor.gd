extends Node

@export_group("Configuración del Motor Hinge")
@export var fuerza_motor: float = 1500.0    
@export var velocidad_maxima: float = 50.0 
@export var joints_traccion: Array[HingeJoint3D] = []

func _ready() -> void:
	# Si prefieres usar grupos, solo borra el @export de arriba y usa esto:
	# joints_traccion = get_tree().get_nodes_in_group("motor_traccion")
	
	# Aseguramos que el motor inicie en modo rueda libre usando tu lógica
	for joint in joints_traccion:
		if is_instance_valid(joint):
			_set_motor_active(joint, false)

func _physics_process(delta: float) -> void:
	var acelerador = Input.get_axis("ui_down", "ui_up")
	var freno = Input.is_action_pressed("ui_select") 
	
	for joint in joints_traccion:
		if not is_instance_valid(joint): continue
		
		if freno:
			# FRENO: Encendemos el motor, exigimos velocidad 0 y aplicamos el doble de fuerza
			joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
			joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.0)
			joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, fuerza_motor * 2.0)
			
		elif abs(acelerador) > 0.05:
			# ACELERACIÓN: Encendemos el motor, asignamos la velocidad y restauramos tu fuerza máxima
			joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
			joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, velocidad_maxima * acelerador)
			joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, fuerza_motor)
			
		else:
			# RUEDA LIBRE
			_set_motor_active(joint, false)

func _set_motor_active(joint: HingeJoint3D, active: bool) -> void:
	joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, active)
	
	if active:
		joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, fuerza_motor)
	else:
		# Si se apaga, quitamos la fuerza física para que deje de empujar/frenar
		joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, 0.0)
