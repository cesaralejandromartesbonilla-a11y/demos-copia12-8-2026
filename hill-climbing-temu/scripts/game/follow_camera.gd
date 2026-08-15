class_name FollowCamera
extends Camera2D

@export var base_offset: Vector2 = Vector2(100.0, 50.0)
@export var lookahead_factor: float = 0.32
@export var max_lookahead_x: float = 180.0
@export var smooth_speed: float = 0.1

var _target: Node2D
var _shake_strength: float = 0.0
var _shake_decay: float = 10.0


func _ready() -> void:
	add_to_group("follow_camera")


func setup(target: Node2D) -> void:
	_target = target
	if _target != null:
		global_position = _target.global_position + base_offset


func shake(amount: float) -> void:
	_shake_strength = maxf(_shake_strength, amount)


func _physics_process(delta: float) -> void:
	if _target == null:
		return

	var velocity := Vector2.ZERO
	if _target is RigidBody2D:
		velocity = (_target as RigidBody2D).linear_velocity

	var lookahead_x := clampf(velocity.x * lookahead_factor, 20.0, max_lookahead_x)
	var lookahead_y := clampf(velocity.y * 0.06, -40.0, 40.0)
	var lookahead := Vector2(lookahead_x, lookahead_y)

	var shake_offset := Vector2.ZERO
	if _shake_strength > 0.5:
		_shake_strength = maxf(0.0, _shake_strength - _shake_decay * delta)
		shake_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength

	var desired := _target.global_position + base_offset + lookahead + shake_offset
	global_position = global_position.lerp(desired, smooth_speed)
