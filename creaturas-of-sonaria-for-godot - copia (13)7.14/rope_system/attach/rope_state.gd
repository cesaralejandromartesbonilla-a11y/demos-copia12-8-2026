class_name RopeState
extends RefCounted
## Contenedor de datos PURO de la simulación: posiciones, pinneo, y
## largos de reposo. Ninguna lógica de física ni de colisión vive acá.
##
## PASO 1 de Fase 4: se suman `pinned` (qué partículas no se mueven
## libremente) y `rest_lengths` POR SEGMENTO (reemplaza al segment_length
## único de Fase 3 — insertar un wrap-anchor parte un segmento en dos con
## largos distintos). También se suma el tracking de contacto sostenido,
## insumo para decidir cuándo insertar. Todavía NO hay liberación (Paso 2)
## — por ahora, un wrap-anchor insertado queda para siempre.

var pos: PackedVector3Array = PackedVector3Array()      # posiciones actuales, en espacio GLOBAL
var pos_old: PackedVector3Array = PackedVector3Array()  # posiciones del frame anterior, para Verlet
var pinned: Array[bool] = []                              # true = extremo real o wrap-anchor: no se mueve libremente
var rest_lengths: PackedFloat32Array = PackedFloat32Array() # largo de reposo POR SEGMENTO (tamaño = pos.size() - 1)

# --- Tracking de contacto sostenido, insumo del sistema de envolvimiento ---
var had_contact_this_frame: PackedByteArray = PackedByteArray()
var contact_streak: PackedInt32Array = PackedInt32Array()
var last_contact_point: PackedVector3Array = PackedVector3Array()
var last_contact_normal: PackedVector3Array = PackedVector3Array()

## Reemplaza TODO el estado con una línea recta nueva entre start_pos y
## end_pos, con `count` partículas y un largo de reposo uniforme por
## segmento (todavía no hay wrap-anchors en la inicialización, así que
## todos arrancan iguales).
func setup_straight_line(start_pos: Vector3, end_pos: Vector3, count: int, uniform_rest_length: float) -> void:
	pos.resize(count)
	pos_old.resize(count)
	pinned.resize(count)
	for i in range(count):
		var t := float(i) / float(count - 1)
		var p := start_pos.lerp(end_pos, t)
		pos[i] = p
		pos_old[i] = p
		pinned[i] = (i == 0 or i == count - 1)

	var seg_count := count - 1
	rest_lengths.resize(seg_count)
	for i in range(seg_count):
		rest_lengths[i] = uniform_rest_length

	had_contact_this_frame.resize(seg_count)
	contact_streak.resize(seg_count)
	last_contact_point.resize(seg_count)
	last_contact_normal.resize(seg_count)
	for i in range(seg_count):
		had_contact_this_frame[i] = 0
		contact_streak[i] = 0
		last_contact_point[i] = Vector3.ZERO
		last_contact_normal[i] = Vector3.ZERO

func clear_contact_flags() -> void:
	for i in range(had_contact_this_frame.size()):
		had_contact_this_frame[i] = 0

## Inserta un punto PINNEADO justo después del segmento `segment_index`,
## partiéndolo en dos con los largos de reposo dados.
func insert_pinned_point(segment_index: int, position: Vector3, rest_a: float, rest_b: float) -> void:
	var at_index := segment_index + 1
	pos.insert(at_index, position)
	pos_old.insert(at_index, position)
	pinned.insert(at_index, true)

	rest_lengths[segment_index] = rest_a
	rest_lengths.insert(at_index, rest_b)

	had_contact_this_frame.insert(at_index, 0)
	contact_streak.insert(at_index, 0)
	last_contact_point.insert(at_index, Vector3.ZERO)
	last_contact_normal.insert(at_index, Vector3.ZERO)
	contact_streak[segment_index] = 0

func count_pinned() -> int:
	var n := 0
	for p in pinned:
		if p:
			n += 1
	return n

## Elimina el punto pinneado en at_index, fusionando los dos segmentos
## que lo rodeaban en uno solo (sumando sus largos de reposo, para no
## generar tensión de golpe). Simétrico a insert_pinned_point: mantiene
## los mismos 8 arrays paralelos sincronizados en un solo lugar.
func remove_pinned_point(at_index: int) -> void:
	var merged_rest: float = rest_lengths[at_index - 1] + rest_lengths[at_index]
	rest_lengths[at_index - 1] = merged_rest
	rest_lengths.remove_at(at_index)

	pos.remove_at(at_index)
	pos_old.remove_at(at_index)
	pinned.remove_at(at_index)
	had_contact_this_frame.remove_at(at_index)
	contact_streak.remove_at(at_index)
	last_contact_point.remove_at(at_index)
	last_contact_normal.remove_at(at_index)
