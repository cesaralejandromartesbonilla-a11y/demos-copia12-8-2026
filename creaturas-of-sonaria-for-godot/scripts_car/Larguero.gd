extends RigidBody3D
class_name Larguero

## Estructura rígida única del MVP. Motor, engranaje y rueda cuelgan de este
## cuerpo por un HingeJoint3D cada uno — no hay ningún otro RigidBody3D
## "estructural" en el sistema, así que no hace falta Generic6DOFJoint3D
## en ningún lado.
##
## Si más adelante agregás un segundo larguero: la opción sin
## Generic6DOFJoint3D es sumar sus CollisionShape3D/MeshInstance3D como
## hijos de ESTE MISMO cuerpo en vez de crear un RigidBody3D nuevo — cero
## joint que resolver, imposible que tiemble.

func get_sockets() -> Array[SocketMecanico]:
	var resultado: Array[SocketMecanico] = []
	for child in get_children():
		if child is SocketMecanico:
			resultado.append(child)
	return resultado


func _ready() -> void:
	can_sleep = false
