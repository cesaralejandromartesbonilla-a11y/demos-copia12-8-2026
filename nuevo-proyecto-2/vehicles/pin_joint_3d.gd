# Script en el vehículo o sistema de enganche
extends ConeTwistJoint3D

@onready var joint = $"." # O PinJoint3D
@onready var raycast = $RayCast3D

func _input(event):
	if event.is_action_pressed("interactuar"):
		if joint.node_b == "": # Si no hay nada enganchado
			intentar_enganchar()
		else:
			desenganchar()

func intentar_enganchar():
	if raycast.is_colliding():
		var objeto = raycast.get_collider()
		if objeto is RigidBody3D: # Verifica que sea un cuerpo físico
			# Node A suele ser el vehículo (ya asignado en el editor)
			# Node B se asigna dinámicamente al objeto detectado
			joint.node_b = objeto.get_path()
			print("Carga enganchada")

func desenganchar():
	joint.node_b = "" # Al vaciarlo, se suelta el objeto
