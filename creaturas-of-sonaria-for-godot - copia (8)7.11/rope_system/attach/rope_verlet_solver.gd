class_name RopeVerletSolver
extends RefCounted
## Integración de Verlet + constraints de distancia. Matemática pura
## sobre un RopeState — esta clase nunca toca PhysicsDirectSpaceState3D
## ni sabe que existe un mundo físico afuera.
##
## FASE 3: constraints uniformes (mismo largo de reposo para todos los
## segmentos, sin pinneo intermedio). El tope duro de elongación no
## existe todavía — llega en una fase posterior.

var gravity: Vector3 = Vector3(0, -9.8, 0)
var damping: float = 0.98 # 1.0 = sin pérdida de energía, más bajo = se frena más rápido
var constraint_iterations: int = 8 # más iteraciones = cuerda más "rígida" y estable

func integrate(state: RopeState, delta: float) -> void:
	for i in range(state.pos.size()):
		var current := state.pos[i]
		var velocity := (current - state.pos_old[i]) * damping
		var next := current + velocity + gravity * delta * delta
		state.pos_old[i] = current
		state.pos[i] = next

func solve_distance_constraints(state: RopeState) -> void:
	for i in range(state.pos.size() - 1):
		var a := state.pos[i]
		var b := state.pos[i + 1]
		var delta_vec := b - a
		var dist := delta_vec.length()
		if dist < 0.00001:
			continue
		var diff := (dist - state.segment_length) / dist
		var correction := delta_vec * 0.5 * diff
		state.pos[i] += correction
		state.pos[i + 1] -= correction
