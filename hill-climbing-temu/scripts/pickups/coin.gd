class_name Coin
extends Area2D

@export var value: int = 1


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = true
	monitorable = false


func _on_body_entered(body: Node2D) -> void:
	var vehicle := body as VehicleController
	if vehicle == null or not vehicle.is_alive:
		return

	GameState.add_run_coins(value)
	queue_free()
