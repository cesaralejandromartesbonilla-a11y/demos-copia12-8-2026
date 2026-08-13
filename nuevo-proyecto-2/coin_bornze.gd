extends RigidBody3D


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		%Player.consume_coin()
		hide()
		queue_free()
		
