class_name RopeAnchor
extends RefCounted
## Contrato base para cualquier extremo de una cuerda.
##
## La cuerda NUNCA debe saber si está atada a un jugador, un rigidbody,
## un punto fijo o a otra cuerda. Solo conoce esta interfaz.
## Todas las subclases deben sobreescribir get_anchor_position().

func get_anchor_position() -> Vector3:
	push_error("RopeAnchor.get_anchor_position() no implementado")
	return Vector3.ZERO

## Velocidad del ancla, usada para amortiguación o para calcular impulsos.
## Las anclas que no tengan noción de velocidad pueden dejarlo en cero.
func get_anchor_velocity() -> Vector3:
	return Vector3.ZERO

## Permite que la simulación le devuelva fuerza al origen del ancla
## (por ejemplo, tirar de un RigidBody3D). Las anclas estáticas la ignoran.
func receive_impulse(_impulse: Vector3) -> void:
	pass

## False cuando el nodo/objeto detrás del ancla ya no existe.
## La cuerda debe chequear esto antes de usar el ancla cada frame.
func is_valid() -> bool:
	return true

## RID del PhysicsBody3D detrás de esta ancla, si lo hay. Se usa para
## excluir ese cuerpo de la colisión de la cuerda contra el mundo (si no,
## la cuerda choca contra el propio objeto del que está colgando).
func get_body_rid() -> RID:
	return RID()

## Descripción legible para debug (se muestra en el Inspector/Remote de
## Rope3D). Cada subclase la sobreescribe con algo útil.
func describe() -> String:
	return "RopeAnchor (base, sin describe() implementado)"
