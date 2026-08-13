extends RigidBody3D

@export_group("Suspensión por Hinge Motor")
@export var angulo_reposo_grados: float = 0.0
@export var rigidez_resorte: float = 15.0
@export var fuerza_maxima_motor: float = 5000.0

@onready var pivote: HingeJoint3D = $"../PivoteChasis"

func _ready() -> void:
	if pivote:
		pivote.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)

func _physics_process(delta: float) -> void:
	if not pivote: return
	_simular_suspension_motor()

func _simular_suspension_motor() -> void:
	# 1. Leemos el ángulo actual del brazo
	var angulo_actual = rad_to_deg(rotation.z) 
	
	# 2. Calculamos la distancia hasta el punto de descanso
	var error_angulo = angulo_reposo_grados - angulo_actual
	
	# 3. MÁGIA DEL MOTOR: La velocidad objetivo es proporcional al error.
	var velocidad_objetivo = deg_to_rad(error_angulo) * rigidez_resorte
	
	# 4. Le inyectamos los parámetros al motor interno de Godot
	pivote.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, velocidad_objetivo)
	pivote.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, fuerza_maxima_motor)
