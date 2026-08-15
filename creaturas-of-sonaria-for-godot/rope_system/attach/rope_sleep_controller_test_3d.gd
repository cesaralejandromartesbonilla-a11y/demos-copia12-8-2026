class_name RopeSleepControllerTest3D
extends Node3D
## Herramienta de prueba AISLADA para RopeSleepController (Paso 3 de
## Fase 7/8) — DESCARTABLE, no es parte del sistema de cuerdas en sí.
## Sigue el mismo patrón que RopeCatenaryPreview3D: cero configuración
## para correrlo solo (usa fallback_offset), o enganchado vía NodePath a
## nodos que YA se mueven en otras escenas de prueba (attach_marker,
## bridge, etc.) para ejercitar las transiciones de dormir/despertar con
## movimiento real en vez de puntos fijos.
##
## PRIMERA PASADA (esta): solo logs en consola cada vez que el ESTADO
## CAMBIA (no cada frame) — mismo orden que se usó en Fase 4 y en
## RopeCatenaryPreview3D: logs primero, dibujo 3D después, una vez que el
## comportamiento en consola ya se validó.
##
## LIMITACIÓN CONOCIDA de este harness: RopeSleepController.update_awake()
## espera `verlet_points` reales (los que la simulación ya tenía) para
## poder congelar una forma al entrar en Caso C (EXCESS_SLACK_ON_SURFACE).
## Acá no hay Rope3D corriendo Verlet de verdad, así que se arma un
## placeholder: línea recta entre p1 y p2, con cada punto interior
## proyectado hacia abajo (raycast) contra el mundo real, para que quede
## apoyado sobre la superficie de verdad en vez de flotar. Esto ya
## corrigió un falso positivo real (ver historial: ASLEEP_FROZEN
## despertaba solo a los 20 frames con p1/p2 estáticos, porque los
## puntos rectos no tocaban el piso y _frozen_shape_perturbed() los
## marcaba como "ya no están"). Sigue siendo una aproximación: NO es la
## forma que Verlet real dejaría (no desliza lateralmente sobre la
## superficie, no respeta el arc_length real, es solo "línea recta +
## caer al piso más cercano"). Sirve para validar la MÁQUINA DE ESTADOS
## con datos que sí tocan geometría real — la fidelidad visual de la
## forma congelada solo se valida integrado en Rope3D, paso futuro.

@export var start_point_path: NodePath
@export var end_point_path: NodePath
@export var fallback_offset: Vector3 = Vector3(4, 0, 0)
@export var arc_length: float = 4.2 # default pensado para el fallback: dist recta 4m, poco slack -> HANGING_OR_TAUT

@export_group("Ajustes del controller (espejo de RopeSleepController)")
@export var still_frames_to_sleep: int = 30
@export var still_move_threshold: float = 0.01
@export var wake_check_interval: int = 20
@export var frozen_wake_move_threshold: float = 0.05
@export var probe_radius: float = 0.03
@export var collision_mask: int = 1

@export_group("Muestra falsa de verlet_points (ver limitación en cabecera)")
@export var fake_verlet_sample_count: int = 12
@export var fake_verlet_raycast_up: float = 0.5 # cuánto subir el origen del rayo antes de tirarlo hacia abajo
@export var fake_verlet_raycast_down: float = 10.0 # hasta dónde buscar piso hacia abajo
@export var fake_verlet_surface_offset: float = 0.03 # separación de la superficie (matchear con rope_radius real), no el centro — misma lección que wrap-anchors

var _controller: RopeSleepController
var _frame_count: int = 0

func _ready() -> void:
	_controller = RopeSleepController.new()
	_controller.still_frames_to_sleep = still_frames_to_sleep
	_controller.still_move_threshold = still_move_threshold
	_controller.wake_check_interval = wake_check_interval
	_controller.frozen_wake_move_threshold = frozen_wake_move_threshold
	_controller.probe_radius = probe_radius
	_controller.collision_mask = collision_mask
	print("[RopeSleepControllerTest3D] listo | still_frames_to_sleep=%d wake_check_interval=%d frozen_wake_move_threshold=%.3f" % [
		still_frames_to_sleep, wake_check_interval, frozen_wake_move_threshold
	])

func _get_point(path: NodePath, fallback: Vector3) -> Vector3:
	if path != NodePath():
		var n: Node = get_node_or_null(path)
		if n is Node3D:
			return (n as Node3D).global_position
	return fallback

func _physics_process(_delta: float) -> void:
	_frame_count += 1
	var p1: Vector3 = _get_point(start_point_path, global_position)
	var p2: Vector3 = _get_point(end_point_path, global_position + fallback_offset)
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	var state_before: RopeSleepController.SleepState = _controller.state

	if _controller.state == RopeSleepController.SleepState.AWAKE:
		var fake_verlet_points: PackedVector3Array = _sample_fake_verlet(p1, p2, space_state)
		_controller.update_awake(p1, p2, arc_length, space_state, fake_verlet_points)
	else:
		_controller.update_asleep(p1, p2, arc_length, space_state)

	_log_if_changed(state_before, p1, p2)

## Placeholder deliberado — ver LIMITACIÓN en la cabecera del archivo.
## Los extremos (t=0, t=1) quedan exactos en p1/p2 — misma razón que en
## RopeRestCaseClassifier: son los puntos de anclaje reales, no hace
## falta ni conviene proyectarlos.
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

## Tira un rayo hacia abajo desde `point` (levantado un poco primero, por
## si `point` ya está justo debajo de la superficie) y devuelve el punto
## de apoyo real, separado de la superficie por fake_verlet_surface_offset
## a lo largo de la normal — superficie, no centro, misma lección que
## wrap-anchors. Si no encuentra nada, devuelve el punto recto original
## sin modificar (fallback explícito, no hay piso que usar).
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
	var ratio: float = arc_length / straight_dist if straight_dist > 0.001 else -1.0
#	print("[RopeSleepControllerTest3D] frame=%d | %s -> %s | p1=%s p2=%s | dist_recta=%.3f arc_length=%.3f ratio=%.4f" % [
#		_frame_count,
#		RopeSleepController.SleepState.keys()[state_before],
#		RopeSleepController.SleepState.keys()[_controller.state],
#		p1, p2, straight_dist, arc_length, ratio
#	])

func get_controller() -> RopeSleepController:
	return _controller
