extends Node3D

@export var joint_torreta: HingeJoint3D
@export var joint_brazo: HingeJoint3D

@export var velocidad_giro: float = 1.5
@export var velocidad_elevacion: float = 1.0

func _physics_process(_delta: float) -> void:
	_controlar_torreta()
	_controlar_brazo()

func _controlar_torreta() -> void:
	var input_giro = Input.get_axis("ui_right", "ui_left")
	
	# Si hay input, gira. Si no, la velocidad objetivo es 0 y el motor frena la torreta.
	joint_torreta.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, input_giro * velocidad_giro)

func _controlar_brazo() -> void:
	var input_elevacion = Input.get_axis("ui_down", "ui_up")
	
	joint_brazo.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, input_elevacion * velocidad_elevacion)
