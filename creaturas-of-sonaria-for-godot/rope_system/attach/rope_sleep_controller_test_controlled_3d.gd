class_name RopeSleepControllerTestControlled3D
extends Node3D
## Segunda herramienta de prueba AISLADA para RopeSleepController.
## Complementa a RopeSleepControllerTest3D (que usaba NodePath a nodos
## reales del jugador/mundo). Esta versión NO tiene ningún NodePath —
## p1 y p2 los controla el propio script con valores exactos, frame a
## frame. El objetivo es eliminar toda fuente de ruido externo (el
## jugador, física de otros cuerpos) para poder afirmar con certeza si
## un despertar en ASLEEP_FROZEN es responsabilidad del controller o no.
##
## Motivación (ver NOTAS_PRUEBA_ROPE_SLEEP_CONTROLLER.md): en la sesión
## anterior, un drift de ~1/18m del CharacterBody3D del jugador (origen
## sin identificar, ajeno a rope_system) hizo imposible distinguir
## "despertar correcto por perturbación real" de "despertar por drift
## accidental del jugador". Acá esa variable desaparece por completo.
##
## REQUIERE: un StaticBody3D con piso en algún lugar cerca de donde este
## nodo se coloque en la escena, en Y=0 relativo a este nodo (mismo
## supuesto que la escena mínima original) — si tu piso está en otro
## lado, ajustá p1_start / p2_fixed para que la catenaria de mucho slack
## quede cerca de esa altura.
##
## MISMA LIMITACIÓN que el harness anterior sobre verlet_points (línea
## recta + proyección al piso vía raycast) — ver ese archivo para el
## detalle completo, no se repite acá.
##
## Corre una secuencia de fases, una sola vez, con logs autoexplicativos
## de tipo [OK] / [FALLO] / [AVISO] — no hace falta interpretar nada,
## cada fase dice qué esperaba y qué pasó.

@export var p1_start: Vector3 = Vector3(0, 1.0, 0)
@export var p2_fixed: Vector3 = Vector3(2.5, 1.0, 0)
@export var arc_length: float = 4.2 # slack grande a propósito: dist=2.5, ratio=1.68 -> debería caer en EXCESS_SLACK_ON_SURFACE si hay piso cerca

@export_group("Ajustes del controller (espejo de RopeSleepController)")
@export var still_frames_to_sleep: int = 30
@export var still_move_threshold: float = 0.01
@export var wake_check_interval: int = 20
@export var frozen_wake_move_threshold: float = 0.05
@export var probe_radius: float = 0.03
@export var collision_mask: int = 1

@export_group("Secuencia de prueba")
@export var stability_check_frames: int = 200 # ventana para confirmar que NO despierta solo
@export var nudge_below_threshold: float = 0.03 # debe ser MENOR a frozen_wake_move_threshold
@export var nudge_above_threshold_extra: float = 0.03 # sumado al anterior, el TOTAL debe superar frozen_wake_move_threshold

@export_group("Muestra falsa de verlet_points (ver limitación en cabecera)")
@export var fake_verlet_sample_count: int = 12
@export var fake_verlet_raycast_up: float = 0.5
@export var fake_verlet_raycast_down: float = 10.0
@export var fake_verlet_surface_offset: float = 0.03

enum TestPhase { WAIT_FIRST_SLEEP, STABILITY_CHECK, NUDGE_BELOW, NUDGE_ABOVE, DONE }

var _controller: RopeSleepController
var _p1_current: Vector3
var _frame_count: int = 0
var _phase: TestPhase = TestPhase.WAIT_FIRST_SLEEP
var _phase_frame_start: int = 0

func _ready() -> void:
	_p1_current = p1_start
	_controller = RopeSleepController.new()
	_controller.still_frames_to_sleep = still_frames_to_sleep
	_controller.still_move_threshold = still_move_threshold
	_controller.wake_check_interval = wake_check_interval
	_controller.frozen_wake_move_threshold = frozen_wake_move_threshold
	_controller.probe_radius = probe_radius
	_controller.collision_mask = collision_mask

	if nudge_below_threshold >= frozen_wake_move_threshold:
		push_warning("[RopeSleepControllerTestControlled3D] nudge_below_threshold (%.3f) debería ser MENOR a frozen_wake_move_threshold (%.3f) — ajustá los exports." % [nudge_below_threshold, frozen_wake_move_threshold])
	var total_nudge: float = nudge_below_threshold + nudge_above_threshold_extra
	if total_nudge <= frozen_wake_move_threshold:
		push_warning("[RopeSleepControllerTestControlled3D] nudge_below_threshold + nudge_above_threshold_extra (%.3f) debería ser MAYOR a frozen_wake_move_threshold (%.3f) — ajustá los exports." % [total_nudge, frozen_wake_move_threshold])

	print("[RopeSleepControllerTestControlled3D] listo | sin NodePath externo, p1/p2 100%% controlados por código | frozen_wake_move_threshold=%.3f" % frozen_wake_move_threshold)

func _physics_process(_delta: float) -> void:
	_frame_count += 1
	var p1: Vector3 = _p1_current
	var p2: Vector3 = p2_fixed
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	var state_before: RopeSleepController.SleepState = _controller.state

	if _controller.state == RopeSleepController.SleepState.AWAKE:
		var fake_verlet_points: PackedVector3Array = _sample_fake_verlet(p1, p2, space_state)
		_controller.update_awake(p1, p2, arc_length, space_state, fake_verlet_points)
	else:
		_controller.update_asleep(p1, p2, arc_length, space_state)

	_log_if_changed(state_before, p1, p2)
	_drive_test_sequence()

func _drive_test_sequence() -> void:
	match _phase:
		TestPhase.WAIT_FIRST_SLEEP:
			if _controller.state == RopeSleepController.SleepState.ASLEEP_FROZEN:
				print("[TEST][OK] frame=%d entró en ASLEEP_FROZEN como se esperaba (mucho slack cerca de piso). Empieza ventana de estabilidad de %d frames con p1/p2 100%% estáticos." % [_frame_count, stability_check_frames])
				_phase = TestPhase.STABILITY_CHECK
				_phase_frame_start = _frame_count
			elif _controller.state == RopeSleepController.SleepState.ASLEEP_ANALYTICAL:
				print("[TEST][AVISO] frame=%d clasificó ASLEEP_ANALYTICAL en vez de ASLEEP_FROZEN. La geometría de este test (p1_start/p2_fixed/arc_length + posición del piso) no está generando el caso EXCESS_SLACK_ON_SURFACE esperado — revisar posición del piso relativa a este nodo antes de seguir. Secuencia abortada." % _frame_count)
				_phase = TestPhase.DONE

		TestPhase.STABILITY_CHECK:
			if _controller.state == RopeSleepController.SleepState.AWAKE:
				print("[TEST][FALLO] frame=%d despertó solo, con p1/p2 perfectamente estáticos (0 drift, sin jugador de por medio). Esto SÍ es una señal real a investigar en _frozen_shape_perturbed — no hay ninguna variable externa que lo explique acá." % _frame_count)
				_phase = TestPhase.DONE
			elif _frame_count - _phase_frame_start >= stability_check_frames:
				print("[TEST][OK] se mantuvo ASLEEP_FROZEN durante %d frames con 0 drift real. Aplicando nudge de %.3f (por debajo del umbral %.3f) — NO debería despertar." % [stability_check_frames, nudge_below_threshold, frozen_wake_move_threshold])
				_p1_current += Vector3(nudge_below_threshold, 0, 0)
				_phase = TestPhase.NUDGE_BELOW
				_phase_frame_start = _frame_count

		TestPhase.NUDGE_BELOW:
			if _controller.state == RopeSleepController.SleepState.AWAKE:
				print("[TEST][FALLO] frame=%d despertó con un nudge de %.3f, que está por debajo de frozen_wake_move_threshold=%.3f. Revisar la comparación de distancia en _update_frozen." % [_frame_count, nudge_below_threshold, frozen_wake_move_threshold])
				_phase = TestPhase.DONE
			elif _frame_count - _phase_frame_start >= stability_check_frames:
				var total_nudge: float = nudge_below_threshold + nudge_above_threshold_extra
				print("[TEST][OK] no despertó tras nudge de %.3f, correcto. Aplicando nudge adicional de %.3f (desplazamiento TOTAL desde el punto congelado = %.3f, por encima del umbral %.3f) — SÍ debería despertar." % [nudge_below_threshold, nudge_above_threshold_extra, total_nudge, frozen_wake_move_threshold])
				_p1_current += Vector3(nudge_above_threshold_extra, 0, 0)
				_phase = TestPhase.NUDGE_ABOVE
				_phase_frame_start = _frame_count

		TestPhase.NUDGE_ABOVE:
			if _controller.state == RopeSleepController.SleepState.AWAKE:
				print("[TEST][OK] frame=%d despertó tras superar el umbral acumulado, como se esperaba. Secuencia completa: máquina de estados de ASLEEP_FROZEN validada sin ruido externo." % _frame_count)
				_phase = TestPhase.DONE
			elif _frame_count - _phase_frame_start >= stability_check_frames * 2:
				print("[TEST][FALLO] frame=%d no despertó incluso %d frames después de superar el umbral acumulado. Revisar _update_frozen." % [_frame_count, stability_check_frames * 2])
				_phase = TestPhase.DONE

		TestPhase.DONE:
			pass

func _sample_fake_verlet(p1: Vector3, p2: Vector3, space_state: PhysicsDirectSpaceState3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	points.resize(fake_verlet_sample_count + 1)
	for i in range(fake_verlet_sample_count + 1):
		var t: float = float(i) / float(fake_verlet_sample_count)
		if i == 0:
			points[i] = p1
		elif i == fake_verlet_sample_count:
			points[i] = p2
		else:
			var straight_point: Vector3 = p1.lerp(p2, t)
			points[i] = _drop_to_floor(straight_point, space_state)
	return points

func _drop_to_floor(point: Vector3, space_state: PhysicsDirectSpaceState3D) -> Vector3:
	var from: Vector3 = point + Vector3.UP * fake_verlet_raycast_up
	var to: Vector3 = point + Vector3.DOWN * fake_verlet_raycast_down
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = collision_mask
	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		return point
	var hit_position: Vector3 = result["position"]
	var hit_normal: Vector3 = result["normal"]
	return hit_position + hit_normal * fake_verlet_surface_offset

func _log_if_changed(state_before: RopeSleepController.SleepState, p1: Vector3, p2: Vector3) -> void:
	if _controller.state == state_before:
		return
	var straight_dist: float = p1.distance_to(p2)
	print("[RopeSleepControllerTestControlled3D] frame=%d | %s -> %s | p1=%s p2=%s | dist_recta=%.3f arc_length=%.3f" % [
		_frame_count,
		RopeSleepController.SleepState.keys()[state_before],
		RopeSleepController.SleepState.keys()[_controller.state],
		p1, p2, straight_dist, arc_length
	])
