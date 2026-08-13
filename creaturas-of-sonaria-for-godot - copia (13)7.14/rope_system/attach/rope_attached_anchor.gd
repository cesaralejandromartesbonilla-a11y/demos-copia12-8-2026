class_name RopeAttachedAnchor
extends RopeAnchor
## Ancla que NO sigue a un Node3D, sino a un punto a lo largo de OTRA
## cuerda ya simulada. Es lo que permite que un puente cuelgue tirantes
## desde su cable principal sin que el cable principal sepa que existen
## sus hijos.
##
## FASE 6, versión simple y UNIDIRECCIONAL: este ancla lee la posición
## del padre cada vez que se le pregunta, pero receive_impulse() no hace
## nada (heredado de RopeAnchor) — el padre nunca se entera de que este
## hijo existe, ni recibe fuerza de vuelta. Suficiente para un puente
## colgante creíble, porque el cable principal pesa mucho más que
## cualquier tirante individual. Si algún día hace falta que el peso del
## tablero tire del cable principal a través de los tirantes, eso es un
## sistema aparte (un grafo de restricciones resuelto en conjunto), no
## una extensión de esta clase.

var _parent_rope: Rope3D
var _t: float # fracción de arco a lo largo del padre: 0 = anchor_start, 1 = anchor_end

func _init(parent_rope: Rope3D, t: float) -> void:
	_parent_rope = parent_rope
	_t = clampf(t, 0.0, 1.0)

## Interpola por LONGITUD DE ARCO real, no por índice de partícula — el
## padre puede tener segmentos de largos distintos (por ejemplo si algún
## día Fase 4 vuelve a estar activa e insertó wrap-anchors ahí), así que
## no asumimos espaciado uniforme.
func get_anchor_position() -> Vector3:
	if not is_instance_valid(_parent_rope):
		return Vector3.ZERO

	var points := _parent_rope.get_points_global()
	if points.size() < 2:
		return Vector3.ZERO # el padre todavía no corrió su primera simulación

	var total_length := 0.0
	for i in range(points.size() - 1):
		total_length += points[i].distance_to(points[i + 1])

	if total_length < 0.0001:
		return points[0]

	var target_distance := _t * total_length
	var accumulated := 0.0
	for i in range(points.size() - 1):
		var seg_length := points[i].distance_to(points[i + 1])
		var reached_target := accumulated + seg_length >= target_distance
		var is_last_segment := i == points.size() - 2
		if reached_target or is_last_segment:
			var local_t := 0.0
			if seg_length > 0.0001:
				local_t = (target_distance - accumulated) / seg_length
			return points[i].lerp(points[i + 1], clampf(local_t, 0.0, 1.0))
		accumulated += seg_length

	return points[points.size() - 1]

func is_valid() -> bool:
	return is_instance_valid(_parent_rope)

func describe() -> String:
	if not is_instance_valid(_parent_rope):
		return "RopeAttachedAnchor(<padre inválido>)"
	return "RopeAttachedAnchor(t=%.2f) @ %s" % [_t, get_anchor_position()]
