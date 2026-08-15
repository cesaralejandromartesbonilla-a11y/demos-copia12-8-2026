#vehicle base.gd
extends VehicleBody3D

# Estado del vehículo
var is_mounted: bool = false

# Métodos que el jugador llamará
func on_player_mounted(player: Node) -> void:
	is_mounted = true
	print("montado")

func on_player_unmounted() -> void:
	is_mounted = false
	print("desmontado")

# Método opcional para lógica de montaje (puedes sobreescribir en hijos)
func can_mount() -> bool:
	return !is_mounted
