class_name RopeEdgeWrapping
extends RefCounted
## FASE 4 completa: inserción (Paso 1) + liberación (Paso 2).
##
## Inserción: detecta contacto sostenido por segmento y, al superar
## wrap_insert_frames CON un doblez real (no apoyado plano), inserta una
## partícula PINNEADA exactamente en el punto de contacto, con el offset
## de rope_radius ya incorporado para no quedar embebida.
##
## Liberación: cada release_check_interval frames, revisa si algún
## wrap-anchor ya puede soltarse — si hay línea de visión limpia entre
## sus dos vecinos, se libera y los dos segmentos que lo rodeaban vuelven
## a ser uno solo. Esto es lo que evita que se acumulen anclas "huérfanas"
## al arrastrar la cuerda por la escena (la causa real del bug del "haz
## de luz" que encontramos antes de dormir este sistema).

var wrap_insert_frames: int = 12 # frames consecutivos de contacto sostenido antes de insertar un ancla real
var max_wrap_anchors: int = 8 # tope de anclas temporales simultáneas por cuerda
var min_wrap_spacing: float = 0.05 # distancia mínima a un wrap-anchor vecino para permitir insertar otro
var min_bend_distance: float = 0.02 # cuánto tiene que desviarse el punto de contacto de la línea recta del segmento para contar como "doblez real" y no como "apoyado plano"
var rope_radius: float = 0.03
var collision_mask: int = 1
var exclude_rids: Array[RID] = []
var release_check_interval: int = 15 # cada cuántos frames se intenta liberar anclas existentes

var _release_check_counter: int = 0

## Lleva la cuenta de cuántos frames SEGUIDOS lleva cada segmento en
## contacto sostenido. Versión simple a propósito: reset a 0 apenas se
## pierde contacto un frame (sin decaimiento suave todavía — eso se
## agrega después, solo si hace falta, no de entrada).
func update_streaks(state: RopeState) -> void:
	for i in range(state.contact_streak.size()):
		if state.had_contact_this_frame[i]:
			state.contact_streak[i] += 1
		else:
			state.contact_streak[i] = 0

## Si algún segmento acumuló suficiente contacto sostenido, inserta una
## partícula PINNEADA exactamente en el punto de contacto real, partiendo
## ese segmento en dos con sus propios largos de reposo.
func try_insert_wrap_anchor(state: RopeState) -> void:
	var current_wrap_count: int = state.count_pinned() - 2 # descontamos los dos extremos reales (siempre pinneados)
	if current_wrap_count >= max_wrap_anchors:
		return

	for i in range(state.contact_streak.size()):
		if state.contact_streak[i] < wrap_insert_frames:
			continue

		var contact_point: Vector3 = state.last_contact_point[i]
		var contact_normal: Vector3 = state.last_contact_normal[i]

		# CLAVE (aprendida la vuelta pasada): el punto que devuelve la
		# colisión está SOBRE la superficie del objeto, no en el centro
		# de la cuerda. Si pinneamos ahí directo, la mitad del tubo
		# visual queda incrustada para siempre. Desplazamos rope_radius
		# a lo largo de la normal para pinnear el CENTRO correctamente
		# — desde este primer intento, no como parche después.
		var insertion_point := contact_point + contact_normal * rope_radius

		# No insertamos pegado a un wrap-anchor vecino ya existente: evita
		# generar micro-segmentos inestables uno al lado del otro.
		if state.pinned[i] and insertion_point.distance_to(state.pos[i]) < min_wrap_spacing:
			continue
		if state.pinned[i + 1] and insertion_point.distance_to(state.pos[i + 1]) < min_wrap_spacing:
			continue

		var new_rest_a := state.pos[i].distance_to(insertion_point)
		var new_rest_b := insertion_point.distance_to(state.pos[i + 1])

		# CLAVE: sin esto, una cuerda apoyada PLANA sobre un piso termina
		# insertando anclas igual (lleva contacto sostenido, pero no hay
		# ningún doblez real ahí). Medimos qué tan lejos está el punto de
		# contacto de la línea recta entre las dos puntas del segmento —
		# apoyado plano da una desviación casi nula; un borde real da una
		# desviación notoria.
		var segment_vec := state.pos[i + 1] - state.pos[i]
		var segment_len := segment_vec.length()
		if segment_len > 0.0001:
			var segment_dir := segment_vec / segment_len
			var to_point := insertion_point - state.pos[i]
			var along := clampf(to_point.dot(segment_dir), 0.0, segment_len)
			var closest_on_line := state.pos[i] + segment_dir * along
			var bend_amount := insertion_point.distance_to(closest_on_line)
			if bend_amount < min_bend_distance:
				continue # apoyado plano, sin doblez real: no insertamos

		state.insert_pinned_point(i, insertion_point, new_rest_a, new_rest_b)

		return # una inserción por frame alcanza; el resto espera al próximo

## Cada release_check_interval frames, revisa si algún wrap-anchor ya
## puede soltarse: si hay línea de visión limpia entre sus dos vecinos
## (el segmento podría ser una línea recta sin volver a cruzar el
## obstáculo), el punto se elimina y los dos segmentos que lo rodeaban
## vuelven a ser uno solo.
##
## Simplificación consciente para esta etapa: el raycast no tiene en
## cuenta el grosor real de la cuerda (rope_radius), así que en bordes
## muy ajustados puede liberar un poco antes de lo ideal — queda anotado
## para Fase 10 (pulido) si hace falta más precisión ahí.
func try_release_wrap_anchors(state: RopeState, space_state: PhysicsDirectSpaceState3D) -> void:
	_release_check_counter += 1
	if _release_check_counter < release_check_interval:
		return
	_release_check_counter = 0

	for i in range(1, state.pos.size() - 1):
		if not state.pinned[i]:
			continue

		var prev_pos: Vector3 = state.pos[i - 1]
		var next_pos: Vector3 = state.pos[i + 1]

		var query := PhysicsRayQueryParameters3D.create(prev_pos, next_pos)
		query.collision_mask = collision_mask
		query.exclude = exclude_rids

		var result: Dictionary = space_state.intersect_ray(query)
		if not result.is_empty():
			continue # todavía hay algo en el medio, no se libera

		state.remove_pinned_point(i)

		return # un solo cambio estructural por chequeo, por las dudas
