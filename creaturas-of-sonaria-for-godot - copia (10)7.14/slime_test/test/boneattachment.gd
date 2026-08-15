extends Node3D

var active_socket: InteractiveSocket

func generate_socket_sensor(target_bone_name: String, radius: float = 0.5) -> void:
	if active_socket != null: return # Evitar duplicados
	
	active_socket = InteractiveSocket.new()
	active_socket.bone_name = target_bone_name
	
	# Generar la forma de colisión por código
	var collision = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = radius
	collision.shape = sphere
	
	active_socket.add_child(collision)
	add_child(active_socket)

func remove_socket_sensor() -> void:
	if active_socket != null:
		active_socket.queue_free()
		active_socket = null
