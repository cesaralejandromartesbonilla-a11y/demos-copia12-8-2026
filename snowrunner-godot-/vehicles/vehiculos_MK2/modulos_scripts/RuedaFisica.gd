# Requiere un hijo ShapeCast3D llamado "SensorSuelo" (SphereShape3D, radio ≈
# config.radio_rueda, target_position apuntando hacia abajo), una referencia a
# "mangueta", un ConfiguracionRueda en "config", y opcionalmente "malla_neumatico"
# (el MeshInstance3D visual) con neumatico_deformacion.gdshader asignado como
# "surface override material" en el slot 0.
extends RigidBody3D
class_name RuedaFisica

@export_group("Configuración compartida")
@export var config: ConfiguracionRueda  # el mismo .tres que usa el BrazoSuspension de esta esquina

@export_group("Específico de esta esquina")
@onready var sensor_suelo: ShapeCast3D = $SensorSuelo
@export var mangueta: Node3D  # arrastrá el mismo nodo que ya usás para el auto-centrado
@export var malla_neumatico: MeshInstance3D  # opcional — el mesh visual, para la deformación

# Estado de contacto expuesto — la fricción de aquí abajo ya lo usa
var hay_contacto: bool = false
var punto_contacto: Vector3 = Vector3.ZERO
var normal_contacto: Vector3 = Vector3.UP
var profundidad_contacto: float = 0.0

# La escribe GestorPeso cada frame, con la carga dinámica real de todo el vehículo
var fuerza_normal_actual: float = 0.0

var material_neumatico: ShaderMaterial  # se cachea una sola vez en _ready()

func _ready() -> void:
	can_sleep = false  # sin esto, Godot puede dormir la rueda al quedar quieta
	if not config:
		push_warning("RuedaFisica (%s) sin 'config' asignado — arrastrá un ConfiguracionRueda." % name)

	if malla_neumatico:
		material_neumatico = malla_neumatico.get_surface_override_material(0) as ShaderMaterial
		if not material_neumatico:
			push_warning("malla_neumatico (%s) no tiene neumatico_deformacion.gdshader asignado como surface override material." % name)

func _physics_process(delta: float) -> void:
	_detectar_contacto()
	if hay_contacto:
		_calcular_y_aplicar_friccion()
	_actualizar_shader_deformacion()

func _detectar_contacto() -> void:
	if not sensor_suelo or not config:
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
	# tiene bugs conocidos y reportados, sobre todo bajo Jolt.
	var distancia_al_contacto = global_position.distance_to(punto_contacto)
	profundidad_contacto = max(0.0, config.radio_rueda - distancia_al_contacto)

func _calcular_y_aplicar_friccion() -> void:
	if not mangueta or not config or not config.curva_agarre:
		return

	var adelante_bruto = -mangueta.global_transform.basis.z  # ajustar eje/signo a tu orientación real
	var adelante = (adelante_bruto - adelante_bruto.project(normal_contacto)).normalized()
	var lateral = normal_contacto.cross(adelante).normalized()

	var velocidad_punto = linear_velocity + angular_velocity.cross(punto_contacto - global_position)
	var deslizamiento_long = velocidad_punto.dot(adelante)
	var deslizamiento_lat = velocidad_punto.dot(lateral)

	var vector_deslizamiento = Vector2(deslizamiento_long, deslizamiento_lat)
	var magnitud = vector_deslizamiento.length()
	if magnitud < 0.001:
		return

	var factor_agarre = config.curva_agarre.sample(clamp(magnitud / config.deslizamiento_referencia, 0.0, 1.0))
	var magnitud_fuerza = factor_agarre * fuerza_normal_actual * config.mu_superficie_default

	var direccion_deslizamiento = vector_deslizamiento.normalized()
	var fuerza_plano = -direccion_deslizamiento * magnitud_fuerza
	var fuerza_mundo = fuerza_plano.x * adelante + fuerza_plano.y * lateral

	apply_force(fuerza_mundo, punto_contacto - global_position)

func _actualizar_shader_deformacion() -> void:
	if not material_neumatico:
		return

	if hay_contacto:
		material_neumatico.set_shader_parameter("punto_contacto_mundo", punto_contacto)
		material_neumatico.set_shader_parameter("profundidad_contacto", profundidad_contacto)
	else:
		material_neumatico.set_shader_parameter("profundidad_contacto", 0.0)
