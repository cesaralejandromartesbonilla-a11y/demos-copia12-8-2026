extends Node3D
class_name CreatureChassis

var speed: float = 0.0
var jump_velocity: float = 0.0
var _socket_cache: Dictionary = {}
var active_limbs: Array = [] # Requerido por _assemble_modular_creature

@export var collision_shape: CollisionShape3D
@export var skeleton: Skeleton3D

func _ready():
	_index_sockets(self)
	print("Chasis ensamblado. Sockets indexados: ", _socket_cache.size())

func register_limb(limb): pass # Requerido si tus piezas registran lógica
func move_hold_position_to(marker): pass

# Función recursiva que se ejecuta UNA SOLA VEZ para indexar los enchufes
func _index_sockets(node: Node):
	if node is InteractiveSocket:
		_socket_cache[node.bone_name] = node
		
	for child in node.get_children():
		_index_sockets(child)

# El Ensamblador usará esta función para pedir los sockets en O(1)
func get_socket(bone_name: String) -> InteractiveSocket:
	return _socket_cache.get(bone_name, null)
