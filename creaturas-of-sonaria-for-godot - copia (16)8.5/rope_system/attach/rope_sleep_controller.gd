class_name RopeSleepController
extends RefCounted
## PASO 3 de Fase 7/8. Máquina de dormir/despertar para UN tramo de
## cuerda entre dos puntos fijos. Decide cuándo conviene dejar de
## simular partícula por partícula y usar la catenaria analítica en su
## lugar (o congelar la forma, según el caso), y cuándo hay que volver
## a despertar. Standalone: no sabe nada de Rope3D ni de RopeState —
## solo de "estos dos puntos, este largo de arco, este espacio físico".
##
## Tres estados:
##   AWAKE             — simulación normal, esto no lo maneja esta clase
##                        (el llamador sigue haciendo Verlet como siempre)
##   ASLEEP_ANALYTICAL — RopeCatenarySolver resuelve la forma; si un
##                        extremo se mueve, se recalcula (barato, sin
##                        despertar de verdad)
##   ASLEEP_FROZEN     — holgura de sobra apoyada (Caso C del
##                        clasificador): no hay forma única, se congela
##                        la última forma que Verlet tenía al dormir
##
## Transiciones:
##   AWAKE -> dormido:    extremos quietos N frames Y el clasificador
##                        dice que no hay perturbación en curso
##   dormido -> AWAKE:    el chequeo periódico contra el mundo encuentra
##                        algo nuevo tocando la curva/forma congelada
##                        (perturbación en el medio del tramo)
##   dormido, extremo se mueve: en ASLEEP_ANALYTICAL, se recalcula sin
##                        despertar; en ASLEEP_FROZEN, si el movimiento
##                        es significativo, se fuerza el despertar (una
##                        forma congelada no sabe "estirarse" sola)

enum SleepState { AWAKE, ASLEEP_ANALYTICAL, ASLEEP_FROZEN }

var still_frames_to_sleep: int = 30 # cuántos frames seguidos con extremos quietos antes de dormir
var still_move_threshold: float = 0.01 # un extremo que se movió menos que esto entre frames se considera "quieto"
var wake_check_interval: int = 20 # cada cuántos frames, estando dormido, se revisa si algo nuevo perturba el tramo
var frozen_wake_move_threshold: float = 0.05 # si un extremo se movió más que esto estando ASLEEP_FROZEN, se fuerza el despertar (una forma congelada no se puede "estirar" sola)
var probe_radius: float = 0.03
var collision_mask: int = 1
var exclude_rids: Array[RID] = []

var state: SleepState = SleepState.AWAKE

var _classifier: RopeRestCaseClassifier = RopeRestCaseClassifier.new()
var _still_frame_count: int = 0
var _wake_check_counter: int = 0
var _has_prev_points: bool = false
var _prev_p1: Vector3 = Vector3.ZERO
var _prev_p2: Vector3 = Vector3.ZERO
var _frozen_points: PackedVector3Array = PackedVector3Array()

## Llamar UNA VEZ por frame mientras el tramo está AWAKE, pasándole los
## puntos que la simulación Verlet ya calculó normalmente. Decide si
## corresponde empezar a dormir. `verlet_points`, si se pasan, son los
## puntos actuales de la simulación — se guardan por si hay que congelar
## (Caso C) al dormir.
func update_awake(p1: Vector3, p2: Vector3, arc_length: float, space_state: PhysicsDirectSpaceState3D, verlet_points: PackedVector3Array = PackedVector3Array()) -> void:
	if not _has_prev_points:
		_reset_stillness(p1, p2)
		return

	var moved_a: float = p1.distance_to(_prev_p1)
	var moved_b: float = p2.distance_to(_prev_p2)
	if moved_a > still_move_threshold or moved_b > still_move_threshold:
		_still_frame_count = 0
	else:
		_still_frame_count += 1

	_prev_p1 = p1
	_prev_p2 = p2

	if _still_frame_count < still_frames_to_sleep:
		return

	# Se ganó el derecho a intentar dormir: clasificamos para saber a
	# cuál de los dos estados dormidos corresponde.
	var rest_case: RopeRestCaseClassifier.RestCase = _classifier.classify(p1, p2, arc_length, space_state)
	if rest_case == RopeRestCaseClassifier.RestCase.HANGING_OR_TAUT:
		state = SleepState.ASLEEP_ANALYTICAL
	else:
		state = SleepState.ASLEEP_FROZEN
		_frozen_points = verlet_points.duplicate()

	_wake_check_counter = 0
	_still_frame_count = 0

## Llamar UNA VEZ por frame mientras el tramo está dormido (en
## cualquiera de los dos modos). Devuelve los puntos representativos
## para este frame (para render o lo que haga falta). Si el tramo
## despierta este frame, `state` pasa a AWAKE y quien llama debe volver
## a tomar el control con Verlet normal desde donde estos puntos quedaron.
func update_asleep(p1: Vector3, p2: Vector3, arc_length: float, space_state: PhysicsDirectSpaceState3D) -> PackedVector3Array:
	match state:
		SleepState.ASLEEP_ANALYTICAL:
			return _update_analytical(p1, p2, arc_length, space_state)
		SleepState.ASLEEP_FROZEN:
			return _update_frozen(p1, p2, space_state)
		_:
			return PackedVector3Array()

func _update_analytical(p1: Vector3, p2: Vector3, arc_length: float, space_state: PhysicsDirectSpaceState3D) -> PackedVector3Array:
	_classifier.get_solver().solve(p1, p2, arc_length)

	_wake_check_counter += 1
	if _wake_check_counter >= wake_check_interval:
		_wake_check_counter = 0
		# Revisamos si, tras haberse movido los extremos, la forma ideal
		# ahora choca contra algo nuevo — si es así, ya no es un simple
		# "recalcular sin despertar", hace falta volver a Verlet de verdad.
		var rest_case: RopeRestCaseClassifier.RestCase = _classifier.classify(p1, p2, arc_length, space_state)
		if rest_case == RopeRestCaseClassifier.RestCase.EXCESS_SLACK_ON_SURFACE:
			state = SleepState.AWAKE
			_has_prev_points = false
			return PackedVector3Array()

	return _sample_solver(_classifier.get_solver(), 16)

func _update_frozen(p1: Vector3, p2: Vector3, space_state: PhysicsDirectSpaceState3D) -> PackedVector3Array:
	# Una forma congelada no tiene noción de "estirarse": si algún
	# extremo se movió de verdad, no hay forma válida de adaptarla sin
	# volver a simular.
	if _frozen_points.size() >= 2:
		var moved_a: float = p1.distance_to(_frozen_points[0])
		var moved_b: float = p2.distance_to(_frozen_points[_frozen_points.size() - 1])
		if moved_a > frozen_wake_move_threshold or moved_b > frozen_wake_move_threshold:
			state = SleepState.AWAKE
			_has_prev_points = false
			return PackedVector3Array()

	_wake_check_counter += 1
	if _wake_check_counter >= wake_check_interval:
		_wake_check_counter = 0
		if _frozen_shape_perturbed(space_state):
			state = SleepState.AWAKE
			_has_prev_points = false
			return PackedVector3Array()

	return _frozen_points

func _frozen_shape_perturbed(space_state: PhysicsDirectSpaceState3D) -> bool:
	# Barato a propósito: probamos unos pocos puntos de la forma
	# congelada contra el mundo. Si algo nuevo se metió ahí desde que
	# se congeló (un objeto se movió, algo cayó encima), hace falta
	# despertar — una forma congelada no reacciona sola a colisión nueva.
	#
	# IMPORTANTE: se excluyen los extremos (índice 0 y el último) del
	# sondeo. Son los puntos de anclaje, no tienen por qué estar tocando
	# nada — igual que RopeRestCaseClassifier los saltea al clasificar.
	# Sin esta exclusión, cualquier tramo Caso C con anclajes que no
	# tocan superficie (el caso normal: solo la panza cuelga y toca el
	# piso, los extremos están en el aire) despierta solo, siempre, en
	# el primer chequeo periódico — quedó confirmado con pruebas
	# aisladas (ver NOTAS_PRUEBA_ROPE_SLEEP_CONTROLLER.md).
	if _frozen_points.size() < 3:
		return false # sin puntos interiores que sondear, nada que revisar
	var sphere := SphereShape3D.new()
	sphere.radius = probe_radius
	var last_index: int = _frozen_points.size() - 1
	var step: int = max(1, (_frozen_points.size() - 2) / 6)
	for i in range(1, last_index, step):
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform = Transform3D(Basis(), _frozen_points[i])
		query.collision_mask = collision_mask
		query.exclude = exclude_rids
		query.margin = 0.01
		var result: Array = space_state.intersect_shape(query, 1)
		# Nota: esto SIEMPRE va a encontrar la superficie sobre la que ya
		# está apoyada la forma congelada (por diseño, es Caso C). Lo que
		# nos interesa es un cambio real, no la presencia en sí — por eso
		# esta función es deliberadamente conservadora por ahora y queda
		# como el punto exacto a refinar en Paso 4: comparar CONTRA QUÉ
		# colisiona cada vez, no solo si colisiona.
		if result.is_empty():
			return true # algo que antes estaba, ya no está — el apoyo cambió
	return false

func _sample_solver(solver: RopeCatenarySolver, count: int) -> PackedVector3Array:
	var points := PackedVector3Array()
	points.resize(count + 1)
	for i in range(count + 1):
		var t: float = float(i) / float(count)
		points[i] = solver.evaluate(t)
	return points

func _reset_stillness(p1: Vector3, p2: Vector3) -> void:
	_prev_p1 = p1
	_prev_p2 = p2
	_has_prev_points = true
	_still_frame_count = 0

## Fuerza el estado a AWAKE y limpia el tracking de quietud — para
## cuando algo externo sabe con certeza que hay que despertar (por
## ejemplo, el jugador agarra un punto en medio del tramo).
func force_wake() -> void:
	state = SleepState.AWAKE
	_has_prev_points = false
	_still_frame_count = 0

func get_classifier() -> RopeRestCaseClassifier:
	return _classifier
