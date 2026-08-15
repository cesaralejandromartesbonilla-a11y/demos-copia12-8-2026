class_name RopeVerletSolver
extends RefCounted
## Integración de Verlet + constraints de distancia. Matemática pura
## sobre un RopeState — nunca toca PhysicsDirectSpaceState3D.
##
## PASO 1 de Fase 4: usa un largo de reposo POR SEGMENTO
## (state.rest_lengths[i]) en vez de un único valor global, y respeta
## partículas pinneadas: no se integran (no se mueven por gravedad/
## velocidad), y en las constraints, si una punta no se puede mover, la
## otra recibe la corrección completa en vez de la mitad.

var gravity: Vector3 = Vector3(0, -9.8, 0)
var damping: float = 0.98 # 1.0 = sin pérdida de energía, más bajo = se frena más rápido

func integrate(state: RopeState, delta: float) -> void:
	for i in range(state.pos.size()):
		if state.pinned[i]:
			continue
		var current := state.pos[i]
		var velocity := (current - state.pos_old[i]) * damping
		var next := current + velocity + gravity * delta * delta
		state.pos_old[i] = current
		state.pos[i] = next

## Alterna el sentido de recorrido según `reverse`: sin esto, la
## corrección se propaga más rápido en un sentido que en el otro dentro
## de cada pasada (el segmento que se procesa último en una pasada recibe
## una corrección más "vieja" que el que se procesa primero). Alternar
## sentido entre pasadas es la forma estándar de evitar ese sesgo en un
## solver de cadena tipo este.
func solve_distance_constraints(state: RopeState, reverse: bool = false) -> void:
	var segment_count := state.pos.size() - 1
	for step in range(segment_count):
		var i := step if not reverse else (segment_count - 1 - step)
		var a := state.pos[i]
		var b := state.pos[i + 1]
		var delta_vec := b - a
		var dist := delta_vec.length()
		if dist < 0.00001:
			continue
		var rest: float = state.rest_lengths[i]
		var diff := (dist - rest) / dist
		var correction := delta_vec * 0.5 * diff

		var pin_a: bool = state.pinned[i]
		var pin_b: bool = state.pinned[i + 1]
		if pin_a and pin_b:
			continue
		elif pin_a:
			state.pos[i + 1] -= correction * 2.0
		elif pin_b:
			state.pos[i] += correction * 2.0
		else:
			state.pos[i] += correction
			state.pos[i + 1] -= correction
