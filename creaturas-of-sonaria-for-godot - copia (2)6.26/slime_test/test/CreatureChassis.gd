extends Node3D
class_name CreatureChassis

@export var skeleton: Skeleton3D

var _socket_cache: Dictionary = {}

func _ready():
	_index_sockets(self)
	print("Chasis ensamblado. Sockets indexados: ", _socket_cache.size())

# Función recursiva que se ejecuta UNA SOLA VEZ para indexar los enchufes
func _index_sockets(node: Node):
	if node is InteractiveSocket:
		_socket_cache[node.bone_name] = node
		
	for child in node.get_children():
		_index_sockets(child)

# El Ensamblador usará esta función para pedir los sockets en O(1)
func get_socket(bone_name: String) -> InteractiveSocket:
	return _socket_cache.get(bone_name, null)
