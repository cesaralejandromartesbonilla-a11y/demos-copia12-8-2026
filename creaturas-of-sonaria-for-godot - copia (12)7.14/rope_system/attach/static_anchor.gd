class_name StaticAnchor
extends RopeAnchor
## Ancla que representa un punto fijo en el espacio (no sigue a ningún nodo).
## Útil para: puntos de anclaje en el mundo, o como fallback cuando un
## marcador no encuentra con quién conectarse todavía.

var _position: Vector3

func _init(pos: Vector3) -> void:
	_position = pos

func get_anchor_position() -> Vector3:
	return _position

## Permite mover el punto fijo manualmente si hace falta (ej: una polea
## que se reposiciona, o para "prender" el ancla a un punto nuevo).
func set_position(pos: Vector3) -> void:
	_position = pos

func describe() -> String:
	return "StaticAnchor @ %s" % [_position]
