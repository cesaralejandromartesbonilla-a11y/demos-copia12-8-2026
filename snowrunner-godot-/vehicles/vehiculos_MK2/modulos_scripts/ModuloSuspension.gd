# Espera: un HingeJoint3D hermano para el pivote (ajusta "pivote" si el tuyo no se llama
# "PivoteChasis"), una referencia a la RuedaFisica de esta esquina, y un ConfiguracionRueda
# arrastrado en "config" (el mismo .tres se puede compartir entre varias esquinas).
extends RigidBody3D
class_name BrazoSuspension

@export_group("Configuración compartida")
@export var config: ConfiguracionRueda  # arrastrá el mismo .tres a todas las esquinas que la compartan

@export_group("Específico de esta esquina")
@export var angulo_reposo_grados: float = 0.0
@export var rueda: RuedaFisica

# Calculadas automáticamente en _ready() a partir de config — no las edites a mano
var rigidez_resorte: float
var amortiguacion: float
var torque_maximo: float

@onready var pivote: HingeJoint3D = $"../PivoteChasis"  # ajusta el nombre si el tuyo es distinto

func _ready() -> void:
	can_sleep = false  # sin esto, Godot puede dormir el cuerpo al quedar quieto (atascado, parado)
	if not config:
		push_warning("BrazoSuspension (%s) sin 'config' asignado — arrastrá un ConfiguracionRueda." % name)
		return
	_calcular_constantes()
	if pivote:
		pivote.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false) # ya no usamos el motor del joint

		# Tope físico duro: cuando torque_maximo no alcanza para absorber un golpe
		# (bache tomado rápido), el brazo pega contra esto en vez de girar de más
		# suavemente — así "fondear" la suspensión se siente como un evento real.
		pivote.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
		var limite_inferior = deg_to_rad(angulo_reposo_grados - config.recorrido_maximo_grados)
		var limite_superior = deg_to_rad(angulo_reposo_grados + config.recorrido_maximo_grados)
		pivote.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, limite_inferior)
		pivote.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, limite_superior)

func _calcular_constantes() -> void:
	var g = 9.8
	var torque_estatico = config.masa_soportada_kg * g * config.longitud_brazo
	var angulo_rad = deg_to_rad(max(config.angulo_hundimiento_grados, 0.1))  # evita dividir entre 0

	rigidez_resorte = torque_estatico / angulo_rad
	amortiguacion = rigidez_resorte * config.multiplicador_amortiguacion
	torque_maximo = torque_estatico * config.factor_seguridad_torque

func _physics_process(delta: float) -> void:
	if not pivote or not config:
		return
	_simular_suspension_real()

func _simular_suspension_real() -> void:
	var eje_bisagra = global_transform.basis.z  # eje local de giro, en espacio del mundo

	var error_angulo = deg_to_rad(angulo_reposo_grados) - rotation.z
	var velocidad_giro = angular_velocity.dot(eje_bisagra)

	var torque_resorte = error_angulo * rigidez_resorte
	var torque_amortiguador = -velocidad_giro * amortiguacion
	var torque_total = clamp(torque_resorte + torque_amortiguador, -torque_maximo, torque_maximo)

	apply_torque(eje_bisagra * torque_total)
	# fuerza_normal_actual la fija GestorPeso, no este script
