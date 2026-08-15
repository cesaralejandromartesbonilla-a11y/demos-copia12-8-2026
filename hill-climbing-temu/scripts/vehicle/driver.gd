extends Area2D

@export var crash_speed_threshold: float = 155.0
@export var crash_spin_factor: float = 24.0


func _physics_process(_delta: float) -> void:
	var vehicle := get_parent() as VehicleController
	if vehicle == null or not vehicle.is_alive:
		return

	if get_overlapping_bodies().is_empty():
		return

	var impact_stress: float = (
		vehicle.linear_velocity.length() + abs(vehicle.angular_velocity) * crash_spin_factor
	)
	if impact_stress >= crash_speed_threshold:
		vehicle.die("crash")
