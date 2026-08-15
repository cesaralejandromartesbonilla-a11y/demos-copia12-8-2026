extends Node

@export var air_time_threshold: float = 0.75
@export var air_time_reward: int = 5
@export var flip_reward: int = 10

var _vehicle: VehicleController
var _air_time: float = 0.0
var _air_rotation: float = 0.0
var _air_reward_given: bool = false
var _flip_rewarded: bool = false


func _ready() -> void:
	_vehicle = get_parent() as VehicleController


func _physics_process(delta: float) -> void:
	if _vehicle == null or not _vehicle.is_alive:
		return

	if _vehicle.is_grounded():
		_reset_air_session()
		return

	_air_time += delta
	_air_rotation += absf(_vehicle.angular_velocity) * delta

	if _air_time >= air_time_threshold and not _air_reward_given:
		_air_reward_given = true
		GameState.add_run_coins(air_time_reward)

	if _air_rotation >= TAU and not _flip_rewarded:
		_flip_rewarded = true
		GameState.add_run_coins(flip_reward)


func _reset_air_session() -> void:
	_air_time = 0.0
	_air_rotation = 0.0
	_air_reward_given = false
	_flip_rewarded = false
