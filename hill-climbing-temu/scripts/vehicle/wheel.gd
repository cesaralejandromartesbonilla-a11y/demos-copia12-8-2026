class_name VehicleWheel
extends Node2D

@export var rest_length: float = 16.0
@export var radius: float = 14.0
@export var spring_strength: float = 14000.0
@export var damping: float = 400.0
@export var drive_share: float = 0.5

var is_grounded: bool = false

@onready var _ray: RayCast2D = $RayCast2D
@onready var _visual: Node2D = $WheelVisual


func _ready() -> void:
	_ray.target_position = Vector2(0.0, rest_length + radius)
	_ray.enabled = true
	_ray.collide_with_areas = false


func apply_from_stats(stats: VehicleStats) -> void:
	rest_length = stats.suspension_rest_length
	radius = stats.wheel_radius
	spring_strength = stats.suspension_stiffness
	damping = stats.suspension_damping
	_ray.target_position = Vector2(0.0, rest_length + radius)


func update_physics(
	body: RigidBody2D,
	gas: float,
	brake: float,
	engine_force: float,
	brake_force: float,
	grip: float,
) -> void:
	is_grounded = _ray.is_colliding()

	if not is_grounded:
		_visual.position = Vector2(0.0, rest_length)
		return

	var contact_point := _ray.get_collision_point()
	var ground_normal := _ray.get_collision_normal()
	var ray_origin := _ray.global_position
	var ground_distance := ray_origin.distance_to(contact_point) - radius
	var compression := clampf(rest_length - ground_distance, 0.0, rest_length)

	var contact_velocity: Vector2 = _get_velocity_at_point(body, contact_point)
	var normal_velocity: float = contact_velocity.dot(ground_normal)
	var spring_force := compression * spring_strength
	var damp_force: float = normal_velocity * damping
	body.apply_force(ground_normal * (spring_force + damp_force), contact_point - body.global_position)

	var tangent := ground_normal.orthogonal()
	if tangent.dot(body.global_transform.x) < 0.0:
		tangent = -tangent

	var drive_input := gas - brake
	if not is_zero_approx(drive_input):
		var force_amount := engine_force * gas - brake_force * brake
		body.apply_force(tangent * force_amount * drive_share * grip, contact_point - body.global_position)

	var lateral_velocity: Vector2 = contact_velocity - tangent * contact_velocity.dot(tangent)
	body.apply_force(-lateral_velocity * grip * body.mass * 8.0, contact_point - body.global_position)

	var local_contact := to_local(contact_point)
	_visual.position = Vector2(0.0, local_contact.y + radius * 0.5)


func _get_velocity_at_point(body: RigidBody2D, global_point: Vector2) -> Vector2:
	var offset := global_point - body.global_position
	if body.center_of_mass_mode == RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM:
		offset -= body.center_of_mass.rotated(body.rotation)
	return body.linear_velocity + Vector2(-offset.y, offset.x) * body.angular_velocity
