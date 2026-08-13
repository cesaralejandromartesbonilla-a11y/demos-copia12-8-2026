class_name RopeCatenarySolver
extends RefCounted
## Resuelve la forma de equilibrio de un tramo de cuerda entre dos puntos
## fijos, dado el largo de arco disponible — sin simular ninguna
## partícula. Standalone a propósito (Paso 1 de Fase 7/8): no sabe nada
## de Rope3D, RopeState, ni de wrap-anchors, solo resuelve la matemática
## y deja evaluarla en cualquier fracción de arco. Validado numéricamente
## contra un prototipo en Python antes de escribir esta versión (6 casos:
## horizontal simétrico, asimétrico, casi tenso, vertical, vertical con
## mucha holgura, y 3D fuera de eje — todos con error de posición y de
## largo de arco menor a 1cm, la mayoría prácticamente cero).
##
## La curva es y = a*cosh(u/a) + c en el plano vertical que contiene a
## los dos puntos, donde `a` controla la curvatura (chico = cuelga
## mucho, grande = casi recto) y `u` es la coordenada horizontal dentro
## de ese plano. Dado el largo real entre los dos puntos (h horizontal,
## v vertical) y el largo de arco disponible L, existe una identidad
## conocida: L² - v² = 4a²·sinh²(h/2a) — la resolvemos para `a` con
## bisección (más lenta que Newton, pero no puede divergir; esto se
## llama poco seguido, no cada frame, así que la velocidad no es lo
## crítico).

var gravity_dir: Vector3 = Vector3.DOWN

var _a: float = 0.0
var _u1: float = 0.0
var _c_offset: float = 0.0
var _p1: Vector3 = Vector3.ZERO
var _p2: Vector3 = Vector3.ZERO
var _up: Vector3 = Vector3.UP
var _horizontal_dir: Vector3 = Vector3.RIGHT
var _arc_length: float = 0.0
var _is_straight: bool = true

const MAX_BISECTION_ITERATIONS: int = 60
const MAX_GROWTH_ITERATIONS: int = 60

# Histéresis para la transición recta↔curva: sin esto, un ancla real con
# apenas milímetros de jitter de física puede cruzar un umbral único
# varias veces por segundo, generando saltos visibles entre "recta" y
# "curva" cada vez que cambia de lado. Con dos umbrales distintos según
# el estado anterior, hace falta un cambio más franco para cruzar. Se
# confirmó con una simulación: mismo jitter, 9 cambios de estado en 20
# frames con un solo umbral, 1 solo cambio con histéresis.
const STRAIGHT_ENTER_RATIO: float = 1.0005 # por debajo de esto, pasa a "recta"
const STRAIGHT_EXIT_RATIO: float = 1.002 # por encima de esto, pasa a "curva" (si ya estaba recta)

## Resuelve la curva para estos dos puntos y este largo de arco. Barato:
## solo hace falta llamarlo cuando el tramo se duerme, o cuando alguno
## de sus extremos se movió — no cada frame de una simulación activa.
func solve(p1: Vector3, p2: Vector3, arc_length: float) -> void:
	_p1 = p1
	_p2 = p2
	_up = -gravity_dir.normalized()

	var delta: Vector3 = p2 - p1
	var v: float = delta.dot(_up)
	var horizontal_vec: Vector3 = delta - _up * v
	var h: float = horizontal_vec.length()

	var straight_dist: float = sqrt(h * h + v * v)
	_arc_length = max(arc_length, straight_dist)

	var ratio: float = _arc_length / straight_dist if straight_dist > 0.0001 else 1.0
	var straight_threshold: float = STRAIGHT_EXIT_RATIO if _is_straight else STRAIGHT_ENTER_RATIO
	if ratio <= straight_threshold:
		# Prácticamente tenso: una catenaria con esta proporción necesita
		# un "a" gigante, y ahí sinh/cosh se ponen numéricamente feos. En
		# el límite es indistinguible de una recta, así que directamente
		# usamos una recta y nos salteamos el solver.
		_is_straight = true
		return

	# Separación horizontal ~0 (cuelga derecho): no hay un plano bien
	# definido para la catenaria. Elegimos una dirección horizontal
	# arbitraria pero FIJA (no aleatoria) para que la forma no rote de
	# orientación entre llamadas sucesivas.
	if h < 0.001:
		_horizontal_dir = Vector3.RIGHT
		if abs(_up.dot(_horizontal_dir)) > 0.99:
			_horizontal_dir = Vector3.FORWARD
		_horizontal_dir = (_horizontal_dir - _up * _horizontal_dir.dot(_up)).normalized()
		h = 0.001
	else:
		_horizontal_dir = horizontal_vec / h

	_is_straight = false
	_a = _solve_for_a(h, v, _arc_length)

	var denom: float = 2.0 * _a * sinh(h / (2.0 * _a))
	var sum_u: float = 2.0 * _a * _asinh(v / denom)
	_u1 = (sum_u - h) * 0.5
	_c_offset = _p1.dot(_up) - _a * cosh(_u1 / _a)

	# Red de seguridad: si algún caso extremo de la bisección produjo
	# NaN/Inf (no debería, pero mejor no propagar basura a la posición
	# de una cuerda visible), caemos a línea recta en vez de mostrar algo
	# roto.
	if not (is_finite(_a) and is_finite(_u1) and is_finite(_c_offset)):
		_is_straight = true

## Bisección sobre f(a) = 4a²·sinh²(h/2a) - (L² - v²). f es monótona
## decreciente: en a chico (relativo a h) es enorme (sinh crece
## exponencial), en a grande tiende a h² - (L²-v²) ≤ 0.
func _solve_for_a(h: float, v: float, arc_length: float) -> float:
	var target: float = arc_length * arc_length - v * v

	# a_low tiene que ser chico EN RELACIÓN A h (no un valor fijo), para
	# garantizar que h/(2*a_low) sea grande y f(a_low) sea genuinamente
	# enorme — con h muy chico, un a_low fijo no alcanza a estar "lo
	# bastante cerca de cero" en términos relativos.
	var a_low: float = max(h / 40.0, 0.00001)
	var a_high: float = max(h, 1.0)

	var growth_guard: int = 0
	while _catenary_f(a_high, h) - target > 0.0 and growth_guard < MAX_GROWTH_ITERATIONS:
		a_high *= 2.0
		growth_guard += 1

	var tolerance: float = max(target * 0.000001, 0.0000001)
	for i in range(MAX_BISECTION_ITERATIONS):
		var a_mid: float = (a_low + a_high) * 0.5
		var f_mid: float = _catenary_f(a_mid, h) - target
		if abs(f_mid) < tolerance:
			return a_mid
		if f_mid > 0.0:
			a_low = a_mid
		else:
			a_high = a_mid

	return (a_low + a_high) * 0.5

func _catenary_f(a: float, h: float) -> float:
	var s: float = sinh(h / (2.0 * a))
	return 4.0 * a * a * s * s

## GDScript no tiene asinh nativo (sí tiene sinh/cosh/tanh, pero no sus
## inversas hiperbólicas) — se implementa a mano con la identidad
## estándar asinh(x) = ln(x + sqrt(x²+1)).
func _asinh(x: float) -> float:
	return log(x + sqrt(x * x + 1.0))

## Evalúa la curva en la fracción de ARCO t (0 = p1, 1 = p2) — de largo
## de arco, no de posición horizontal, para que quede espaciado igual
## que como estarían las partículas de una cuerda simulada de verdad.
func evaluate(t: float) -> Vector3:
	t = clampf(t, 0.0, 1.0)

	if _is_straight:
		return _p1.lerp(_p2, t)

	var target_arc: float = t * _arc_length
	var u: float = _a * _asinh(sinh(_u1 / _a) + target_arc / _a)

	var horizontal_offset: float = u - _u1
	var height: float = _a * cosh(u / _a) + _c_offset

	var base_horizontal: Vector3 = _p1 - _up * _p1.dot(_up)
	var pos_horizontal: Vector3 = base_horizontal + _horizontal_dir * horizontal_offset
	return pos_horizontal + _up * height

func is_straight() -> bool:
	return _is_straight

## Para debug/inspección — qué tan curvada quedó la solución.
func get_curvature_param() -> float:
	return _a
