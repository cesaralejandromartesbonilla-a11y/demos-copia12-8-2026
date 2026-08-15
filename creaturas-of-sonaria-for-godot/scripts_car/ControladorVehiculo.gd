extends Node
class_name ControladorVehiculo

## El controlador de tracción y dirección — el más básico de tus tres
## proyectos de joints de vehículo, y el que quedó elegido como base. No
## sabe nada de cómo está armado el vehículo: solo recibe arrays de
## HingeJoint3D ya existentes (joints_direccion, joints_traccion) y les
## mueve el motor según el input. Por eso PiezaMotor.gd puede registrarse
## solo en joints_traccion sin que este script necesite saber que
## EnsambladorMecanico existe — la lógica de acá abajo es la misma que ya
## tenías probada, no la toqué.

@export_group("Prueba sin teclado")
@export var modo_crucero: bool = true  # true = ignora el teclado y usa acelerador_crucero fijo. Sirve para descartar de una si el problema es el motor o es que el input no está llegando (foco de ventana, input map, etc). Editable en vivo desde el Inspector en modo Remote, sin tocar el juego.
@export_range(-100.0, 100.0, 1.0) var acelerador_crucero: float = 0.0  # 0 = inerte, 100 = aceleración máxima hacia adelante, -100 = máxima en reversa

@export_group("Configuración de Dirección")
@export var grados_maximos: float = 30.0
@export var velocidad_volante: float = 5.0

@export_group("Retorno Automático")
@export var auto_centrar: bool = true
@export var velocidad_retorno: float = 8.0 

@export_group("Fuerza")
@export var fuerza_direccion: float = 1500.0 
@export var joints_direccion: Array[HingeJoint3D] = []

@export_group("Configuración del Motor Hinge")
@export var fuerza_motor: float = 1500.0    
@export var velocidad_maxima: float = 50.0 
@export var joints_traccion: Array[HingeJoint3D] = []  # PiezaMotor.gd se registra acá solo, vía el grupo "controlador_vehiculo" — no hace falta asignar a mano

func _set_motor_active(joint: HingeJoint3D, active: bool) -> void:
	joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, active)
	
	if active:
		joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, fuerza_motor)
	else:
		# Si se apaga, quitamos la fuerza física para que deje de empujar/frenar
		joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, 0.0)

func _ready() -> void:
	# Si prefieres usar grupos, solo borra el @export de arriba y usa esto:
	# joints_traccion = get_tree().get_nodes_in_group("motor_traccion")
	
	# Aseguramos que el motor inicie en modo rueda libre usando tu lógica
	for joint in joints_traccion:
		if is_instance_valid(joint):
			_set_motor_active(joint, false)
	var limite_radianes = deg_to_rad(grados_maximos)
	for joint in joints_direccion:
		if is_instance_valid(joint):
			joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
			joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, -limite_radianes)
			joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, limite_radianes)
			joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)

func _physics_process(delta: float) -> void:
	var volante = Input.get_axis("ui_left", "ui_right") 
	var acelerador = (acelerador_crucero / 100.0) if modo_crucero else Input.get_axis("ui_down", "ui_up")
	var freno = Input.is_action_pressed("ui_select") 
	
	for joint in joints_direccion:
		if not is_instance_valid(joint): continue
		
		var velocidad_actual = 0.0
		
		if abs(volante) > 0.05:
			velocidad_actual = velocidad_volante * volante
		else:
			if auto_centrar:
				var mangueta = joint.get_node_or_null(joint.node_b) as Node3D
				var brazo = joint.get_node_or_null(joint.node_a) as Node3D
				
				if mangueta and brazo:
					var transform_local = brazo.global_transform.affine_inverse() * mangueta.global_transform
					var angulo_actual = transform_local.basis.get_euler().y 
					
					if abs(angulo_actual) > 0.01:
						# Si quieres que la rueda vaya hacia los lados, cambia "-angulo_actual" por "angulo_actual"
						velocidad_actual = angulo_actual * velocidad_retorno 
			else:
				velocidad_actual = 0.0
		
		joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, velocidad_actual)
		joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, fuerza_direccion)
	
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
