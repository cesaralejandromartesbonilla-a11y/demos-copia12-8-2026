extends Area3D

@export var wind_direction: Vector3 = Vector3(1, 0, 0)
@export var wind_strength: float = 15.0

func _physics_process(delta: float):
	# Obtiene todos los cuerpos dentro de la zona de viento
	for body in get_overlapping_bodies():
		# Verificamos si es tu Slime buscando tu script de Locomotion
		if body.has_node("LocomotionController"):
			var locomotion = body.get_node("LocomotionController")
			# ¡Lo empujamos constantemente mientras esté en el área!
			locomotion.apply_external_force(wind_direction.normalized() * wind_strength * delta)
