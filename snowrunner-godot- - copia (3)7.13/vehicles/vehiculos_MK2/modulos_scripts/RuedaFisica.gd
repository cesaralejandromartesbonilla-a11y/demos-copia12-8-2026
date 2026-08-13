extends RigidBody3D
class_name RuedaFisica

@export_group("Geometría")
@export var radio_rueda: float = 0.35  # debe coincidir con el radio real de malla/colisión

@export_group("Sensor de contacto")
@onready var sensor_suelo: ShapeCast3D = $SensorSuelo

@export_group("Fricción de neumático")
@onready var mangueta: Node3D = $"../Mangueta"
@export var curva_agarre: Curve                      # deslizamiento normalizado → multiplicador de agarre
@export var deslizamiento_referencia: float = 2.0    # m/s de deslizamiento que satura la curva
@export var mu_superficie_default: float = 1.0       # más adelante: leer del collider real (Fase 2)

# Estado de contacto expuesto — la fricción de aquí abajo ya lo usa;
# el shader del Paso 1.1.6 también leerá de aquí más adelante
var hay_contacto: bool = false
var punto_contacto: Vector3 = Vector3.ZERO
var normal_contacto: Vector3 = Vector3.UP
var profundidad_contacto: float = 0.0

# La escribe BrazoSuspension cada frame, con la fuerza que ya calcula
# su propio resorte + amortiguador
var fuerza_normal_actual: float = 0.0

func _physics_process(delta: float) -> void:
	_detectar_contacto()
	if hay_contacto:
		_calcular_y_aplicar_friccion()

func _detectar_contacto() -> void:
	if not sensor_suelo:
		hay_contacto = false
		return

	sensor_suelo.force_shapecast_update()

	if not sensor_suelo.is_colliding():
		hay_contacto = false
		return

	hay_contacto = true
	punto_contacto = sensor_suelo.get_collision_point(0)
	normal_contacto = sensor_suelo.get_collision_normal(0)

	# Profundidad calculada a mano a propósito: get_closest_collision_safe_fraction()
	# tiene bugs conocidos y reportados, sobre todo bajo Jolt — no confiamos en ese método.
	var distancia_al_contacto = global_position.distance_to(punto_contacto)
	profundidad_contacto = max(0.0, radio_rueda - distancia_al_contacto)

func _calcular_y_aplicar_friccion() -> void:
	if not mangueta or not curva_agarre:
		return

	# Direcciones estables (de la mangueta, no de la rueda que gira sin parar),
	# proyectadas sobre el plano de contacto real
	var adelante_bruto = -mangueta.global_transform.basis.z  # ajustar eje/signo a tu orientación real
	var adelante = (adelante_bruto - adelante_bruto.project(normal_contacto)).normalized()
	var lateral = normal_contacto.cross(adelante).normalized()

	# Velocidad del punto de la rueda que está tocando el suelo ahora mismo.
	# Si rodara sin deslizar, esto daría cero — cualquier valor distinto de cero ES el deslizamiento.
	var velocidad_punto = linear_velocity + angular_velocity.cross(punto_contacto - global_position)
	var deslizamiento_long = velocidad_punto.dot(adelante)
	var deslizamiento_lat = velocidad_punto.dot(lateral)

	var vector_deslizamiento = Vector2(deslizamiento_long, deslizamiento_lat)
	var magnitud = vector_deslizamiento.length()
	if magnitud < 0.001:
		return

	# Círculo de fricción: una sola curva sobre la magnitud combinada,
	# así longitudinal y lateral comparten presupuesto de agarre automáticamente
	var factor_agarre = curva_agarre.sample(clamp(magnitud / deslizamiento_referencia, 0.0, 1.0))
	var magnitud_fuerza = factor_agarre * fuerza_normal_actual * mu_superficie_default

	var direccion_deslizamiento = vector_deslizamiento.normalized()
	var fuerza_plano = -direccion_deslizamiento * magnitud_fuerza  # se opone al deslizamiento
	var fuerza_mundo = fuerza_plano.x * adelante + fuerza_plano.y * lateral

	apply_force(fuerza_mundo, punto_contacto - global_position)
