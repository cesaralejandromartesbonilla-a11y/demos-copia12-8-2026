# Vive en el chasis (o como hijo de él). Calcula cuánta carga dinámica lleva cada rueda
# —peso estático más transferencia por aceleración— y se la entrega directo a cada
# RuedaFisica. No asume 4 ruedas ni una forma rectangular: reparte según la posición
# real de cada esquina respecto al centro de masa, así sirve para cualquier vehículo
# que armes, sin importar cuántas ruedas tenga ni cómo estén acomodadas.
extends Node
class_name GestorPeso

@export_group("Vehículo")
@export var chasis: RigidBody3D
@export var esquinas: Array[BrazoSuspension] = []  # todas las esquinas del vehículo, sin importar cuántas

@export_group("Transferencia de peso")
@export var altura_centro_masa: float = 0.5         # más alto = más transferencia al frenar/girar
@export var sensibilidad_transferencia: float = 1.0  # 1.0 = físicamente "correcto"; bajalo si se siente exagerado

var velocidad_anterior: Vector3 = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if not chasis or esquinas.is_empty():
		return

	var aceleracion = (chasis.linear_velocity - velocidad_anterior) / delta
	velocidad_anterior = chasis.linear_velocity

	# Aceleración en espacio LOCAL del chasis (adelante/atrás, derecha/izquierda),
	# sin importar hacia dónde esté orientado el vehículo en el mundo.
	# Ajustá el signo de .z si tu "adelante" no es el eje -Z estándar de Godot.
	var acel_local = chasis.global_transform.basis.inverse() * aceleracion
	var momento_longitudinal = chasis.mass * acel_local.z * altura_centro_masa
	var momento_lateral = chasis.mass * acel_local.x * altura_centro_masa

	# Suma de brazos de palanca al cuadrado — reparte la transferencia proporcional
	# a qué tan lejos está cada rueda del centro, sin asumir ninguna cantidad fija de ruedas
	var suma_z2 = 0.0
	var suma_x2 = 0.0
	for esquina in esquinas:
		if not is_instance_valid(esquina):
			continue
		var pos = chasis.to_local(esquina.global_position)
		suma_z2 += pos.z * pos.z
		suma_x2 += pos.x * pos.x

	for esquina in esquinas:
		if not is_instance_valid(esquina) or not esquina.rueda or not esquina.config:
			continue

		var pos = chasis.to_local(esquina.global_position)
		var transferencia_n = 0.0

		if suma_z2 > 0.001:
			transferencia_n += -momento_longitudinal * pos.z / suma_z2
		if suma_x2 > 0.001:
			transferencia_n += -momento_lateral * pos.x / suma_x2

		var fuerza_estatica_n = esquina.config.masa_soportada_kg * 9.8
		var fuerza_total_n = max(0.0, fuerza_estatica_n + transferencia_n * sensibilidad_transferencia)

		esquina.rueda.fuerza_normal_actual = fuerza_total_n
