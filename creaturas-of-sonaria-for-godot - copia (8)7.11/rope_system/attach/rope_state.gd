class_name RopeState
extends RefCounted
## Contenedor de datos PURO de la simulación: posiciones actuales y del
## frame anterior (para Verlet), y el largo de reposo uniforme por
## segmento. Ninguna lógica de física ni de colisión vive acá.
##
## FASE 3: todavía no hay pinneo por partícula ni largos de reposo
## individuales por segmento (eso llega recién con Fase 4, cuando existan
## wrap-anchors) — por ahora todos los segmentos comparten el mismo largo
## de reposo, y los únicos puntos "fijos" son los dos extremos, manejados
## aparte por Rope3D._pin_ends(). Cuando lleguemos a Fase 4, este archivo
## va a crecer (pinned, rest_lengths por segmento) — no antes.

var pos: PackedVector3Array = PackedVector3Array()      # posiciones actuales, en espacio GLOBAL
var pos_old: PackedVector3Array = PackedVector3Array()  # posiciones del frame anterior, para Verlet
var segment_length: float = 0.0                          # largo de reposo, uniforme para todos los segmentos

func point_count() -> int:
	return pos.size()

## Reemplaza TODO el estado con una línea recta nueva entre start_pos y
## end_pos, con `count` partículas y el largo de reposo uniforme dado.
func setup_straight_line(start_pos: Vector3, end_pos: Vector3, count: int, uniform_segment_length: float) -> void:
	pos.resize(count)
	pos_old.resize(count)
	for i in range(count):
		var t := float(i) / float(count - 1)
		var p := start_pos.lerp(end_pos, t)
		pos[i] = p
		pos_old[i] = p
	segment_length = uniform_segment_length
