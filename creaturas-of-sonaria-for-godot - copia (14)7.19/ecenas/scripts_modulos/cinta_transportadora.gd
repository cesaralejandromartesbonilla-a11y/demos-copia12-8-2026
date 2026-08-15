extends StaticBody3D

@export var belt_speed: float = 2.0

func _ready() -> void:
	# -global_transform.basis.z es la dirección "Adelante" del objeto en Godot
	constant_linear_velocity = -global_transform.basis.z * belt_speed
