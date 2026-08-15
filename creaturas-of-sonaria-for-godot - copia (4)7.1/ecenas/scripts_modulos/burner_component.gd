extends Node
class_name BurnerComponent

var is_burning: bool = false
var remaining_burn_time: float = 0.0

func _process(delta: float) -> void:
	if remaining_burn_time > 0:
		remaining_burn_time -= delta
		is_burning = true
	else:
		if is_burning:
			print("El fuego se ha apagado.")
		is_burning = false
		remaining_burn_time = 0.0

func add_fuel(burn_seconds: float) -> void:
	remaining_burn_time += burn_seconds
	is_burning = true
