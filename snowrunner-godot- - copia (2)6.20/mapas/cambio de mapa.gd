extends Area3D

@export var mapa_destino: PackedScene

func _on_body_entered(body: Node3D) -> void:
	if body is VehicleBody3D: # Si el que tocó la zona es un vehículo
		if mapa_destino:
			get_tree().change_scene_to_packed(mapa_destino)
		else:
			print("ERROR: Zona de viaje sin mapa asignado.")
