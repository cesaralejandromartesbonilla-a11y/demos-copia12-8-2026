class_name RopeRestCaseClassifier
extends RefCounted
## PASO 2 de Fase 7/8. Dado un tramo de cuerda en reposo (dos puntos
## fijos + largo de arco disponible), decide si conviene representarlo
## con la catenaria analítica (RopeCatenarySolver) o si hay que congelar
## la última forma simulada sin intentar derivar una nueva.
##
## Caso HANGING_OR_TAUT (A y B del concepto original, no hace falta
## distinguirlos más — el solver ya maneja "casi tenso" como límite de
## la misma fórmula): la catenaria ideal no se mete dentro de ninguna
## superficie cercana. Es una representación válida y barata.
##
## Caso EXCESS_SLACK_ON_SURFACE (C): la catenaria ideal SÍ se mete dentro
## de algo — significa que hay más cuerda disponible de la que cabe
## colgando libre, y el exceso tiene que apilarse sobre una superficie de
## alguna manera. No hay una forma matemática única para "cómo se apila"
## (a diferencia de la catenaria, que es LA forma de equilibrio), así que
## acá no calculamos nada nuevo: quien use esto debe congelar la última
## forma que la simulación Verlet ya tenía.
##
## Standalone a propósito, como el solver: no sabe nada de Rope3D,
## RopeState, ni de wrap-anchors — solo clasifica, dado un espacio físico
## para consultar.

enum RestCase { HANGING_OR_TAUT, EXCESS_SLACK_ON_SURFACE }

var sample_count: int = 8 # cuántos puntos de la catenaria ideal se testean contra el mundo
var probe_radius: float = 0.03 # debería matchear el rope_radius real de la cuerda
var collision_mask: int = 1
var exclude_rids: Array[RID] = []

var _solver: RopeCatenarySolver = RopeCatenarySolver.new()
var _probe_shape: SphereShape3D = SphereShape3D.new()

## Clasifica el tramo. Si devuelve HANGING_OR_TAUT, el solver interno YA
## quedó resuelto para este tramo — podés llamar get_solver().evaluate(t)
## directo después, sin necesidad de resolver de nuevo.
func classify(p1: Vector3, p2: Vector3, arc_length: float, space_state: PhysicsDirectSpaceState3D) -> RestCase:
	_solver.solve(p1, p2, arc_length)
	_probe_shape.radius = probe_radius

	# Empezamos en 1 y terminamos antes de sample_count a propósito: los
	# extremos (t=0 y t=1) son los propios puntos fijos del tramo, que
	# casi siempre están pegados o muy cerca de superficies reales (ahí
	# es donde el tramo se ancló) — probarlos daría falsos positivos
	# constantes de "hay algo acá", que no dicen nada sobre el tramo en sí.
	for i in range(1, sample_count):
		var t: float = float(i) / float(sample_count)
		var point: Vector3 = _solver.evaluate(t)

		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = _probe_shape
		query.transform = Transform3D(Basis(), point)
		query.collision_mask = collision_mask
		query.exclude = exclude_rids
		query.margin = 0.01

		var result: Array = space_state.intersect_shape(query, 1)
		if not result.is_empty():
			return RestCase.EXCESS_SLACK_ON_SURFACE

	return RestCase.HANGING_OR_TAUT

## El solver queda resuelto tras classify() si el resultado fue
## HANGING_OR_TAUT — evita tener que llamar solve() dos veces para el
## mismo tramo.
func get_solver() -> RopeCatenarySolver:
	return _solver
