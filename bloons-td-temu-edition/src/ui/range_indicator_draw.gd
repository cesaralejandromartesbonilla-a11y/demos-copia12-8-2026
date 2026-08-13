extends Node2D

var radius: float = 150.0

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.2, 0.6, 1.0, 0.25))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(0.2, 0.6, 1.0, 0.8), 2.0)
