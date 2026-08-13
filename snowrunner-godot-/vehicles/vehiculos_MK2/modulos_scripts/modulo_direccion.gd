extends Node

@export_group("Configuración de Dirección")
@export var grados_maximos: float = 30.0
@export var velocidad_volante: float = 5.0

@export_group("Retorno Automático")
@export var auto_centrar: bool = true
@export var velocidad_retorno: float = 8.0 

@export_group("Fuerza")
@export var fuerza_direccion: float = 1500.0 

@export var joints_direccion: Array[HingeJoint3D] = []

func _ready() -> void:
	var limite_radianes = deg_to_rad(grados_maximos)
	for joint in joints_direccion:
		if is_instance_valid(joint):
			joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
			joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, -limite_radianes)
			joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, limite_radianes)
			joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)

func _physics_process(delta: float) -> void:
	var volante = Input.get_axis("ui_left", "ui_right") 
	
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
