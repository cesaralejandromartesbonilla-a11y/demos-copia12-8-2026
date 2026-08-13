class_name NodeAnchor
extends RopeAnchor
## Ancla genérica para CUALQUIER Node3D: jugador, RigidBody3D,
## CharacterBody3D, StaticBody3D, o incluso un nodo sin física.
## Esta es la pieza clave para que la cuerda no distinga "jugador" de
## "objeto": ambos terminan siendo el mismo NodeAnchor.

var _node: Node3D
var _body: PhysicsBody3D # null si el nodo no tiene cuerpo físico
var _local_offset: Vector3
var _last_position: Vector3

func _init(node: Node3D, local_offset: Vector3 = Vector3.ZERO) -> void:
	_node = node
	_local_offset = local_offset
	if node is PhysicsBody3D:
		_body = node
	_last_position = get_anchor_position()

func get_anchor_position() -> Vector3:
	if not is_instance_valid(_node):
		return _last_position
	return _node.global_transform * _local_offset

## Si hay un RigidBody3D detrás, usamos su velocidad real.
## Si no, estimamos por diferencia de posición (aproximado, sin dividir
## por delta a propósito: quien consuma esto decide la escala que necesita).
func get_anchor_velocity() -> Vector3:
	if _body is RigidBody3D:
		return _body.linear_velocity
	var current := get_anchor_position()
	var estimated := current - _last_position
	_last_position = current
	return estimated

func receive_impulse(impulse: Vector3) -> void:
	if _body is RigidBody3D:
		_body.apply_impulse(impulse, get_anchor_position() - _body.global_position)
	# CharacterBody3D y StaticBody3D no reciben impulso: es esperado,
	# no un caso especial que la cuerda necesite conocer.

func is_valid() -> bool:
	return is_instance_valid(_node)

func get_body_rid() -> RID:
	if _body:
		return _body.get_rid()
	return RID()

func get_node_ref() -> Node3D:
	return _node
