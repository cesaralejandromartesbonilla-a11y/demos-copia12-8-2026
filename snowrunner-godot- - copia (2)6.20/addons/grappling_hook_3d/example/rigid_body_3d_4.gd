extends RigidBody3D


func _physics_process(delta: float) -> void:
	position.z = sin(Time.get_ticks_msec() * 0.001) * 10.0
