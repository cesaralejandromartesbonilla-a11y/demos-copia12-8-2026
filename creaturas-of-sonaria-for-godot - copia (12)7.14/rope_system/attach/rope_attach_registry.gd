extends Node
## AUTOLOAD. Registrar como singleton en Project Settings > Autoload
## con el nombre "RopeAttachRegistry".
##
## Lleva la lista de marcadores que ya generaron su extremo de cuerda
## pero todavía no tienen pareja, para que la búsqueda "punto cercano"
## no dependa de recorrer todo el árbol de la escena cada vez.

var _available_markers: Array = []

func register_available(marker: Node) -> void:
	if not _available_markers.has(marker):
		_available_markers.append(marker)

func unregister(marker: Node) -> void:
	_available_markers.erase(marker)

## Devuelve el marcador disponible más cercano dentro del radio, o null.
## "Disponible" = ya tocó algo (tiene su propio extremo) pero no tiene pareja.
func find_nearest_available(from_marker: Node3D, radius: float) -> Node:
	var best: Node = null
	var best_dist := radius
	for m in _available_markers:
		if m == from_marker or not is_instance_valid(m):
			continue
		var d := from_marker.global_position.distance_to(m.global_position)
		if d <= best_dist:
			best_dist = d
			best = m
	return best
