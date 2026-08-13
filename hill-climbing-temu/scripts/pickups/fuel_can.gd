class_name FuelCan
extends Area2D

@export var restore_amount: float = 40.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = true
	monitorable = false


func _on_body_entered(body: Node2D) -> void:
	var vehicle := body as VehicleController
	if vehicle == null or not vehicle.is_alive:
		return

	vehicle.add_fuel(restore_amount)
	queue_free()
