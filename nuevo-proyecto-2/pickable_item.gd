extends Area3D

@export var item_name := "Recurso"
var is_slotted := false # Para saber si está pegado a la mochila o suelto

func set_physics_state(active: bool):
	# Si el objeto tiene gravedad propia (RigidBody), la apagas al agarrarlo.
	# Por ahora, como es Area3D, solo desactivamos colisiones si está en slot.
	input_ray_pickable = active
	monitoring = active
