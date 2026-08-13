extends Node3D

@onready var animated_skel: Skeleton3D = $EsqueletoAnimado

func _ready():
	# Encendemos automáticamente todos los nodos IK que estén dentro del esqueleto
	for child in animated_skel.get_children():
		if child is SkeletonIK3D:
			child.start()
			print("IK Iniciado: ", child.name)

# Aquí en el futuro puedes poner tu lógica de "LegStepper" o mover los radares de las patas.
