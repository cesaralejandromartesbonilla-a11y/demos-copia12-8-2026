extends CSGBox3D


func _physics_process(delta: float) -> void:
	position.z = sin(Time.get_ticks_msec() * 0.001) * 50.0
