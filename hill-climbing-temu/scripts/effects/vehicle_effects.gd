extends Node

@export var min_landing_speed: float = 90.0

var _vehicle: VehicleController
var _was_grounded: bool = true


func _ready() -> void:
	_vehicle = get_parent() as VehicleController
	if _vehicle == null:
		return

	_vehicle.died.connect(_on_vehicle_died)


func _physics_process(_delta: float) -> void:
	if _vehicle == null or not _vehicle.is_alive:
		return

	var grounded := _vehicle.is_grounded()
	if grounded and not _was_grounded:
		var impact_speed: float = _vehicle.linear_velocity.length()
		if impact_speed >= min_landing_speed:
			_spawn_dust(impact_speed)

	_was_grounded = grounded


func _on_vehicle_died(reason: String) -> void:
	if reason != "crash":
		return

	_spawn_sparks(_vehicle.global_position)


func _spawn_dust(impact_speed: float) -> void:
	var dust := _create_dust_particles(impact_speed)
	dust.global_position = _vehicle.global_position + Vector2(-10.0, 18.0)
	get_tree().current_scene.add_child(dust)
	_cleanup_after(dust, 0.7)

	if impact_speed >= 140.0:
		var cameras := get_tree().get_nodes_in_group("follow_camera")
		if not cameras.is_empty() and cameras[0].has_method("shake"):
			cameras[0].shake(clampf(impact_speed * 0.04, 2.0, 8.0))


func _spawn_sparks(global_pos: Vector2) -> void:
	var sparks := CPUParticles2D.new()
	sparks.one_shot = true
	sparks.emitting = true
	sparks.amount = 24
	sparks.lifetime = 0.45
	sparks.explosiveness = 0.95
	sparks.direction = Vector2(0.0, -1.0)
	sparks.spread = 180.0
	sparks.gravity = Vector2(0.0, 400.0)
	sparks.initial_velocity_min = 80.0
	sparks.initial_velocity_max = 200.0
	sparks.scale_amount_min = 2.0
	sparks.scale_amount_max = 4.0
	sparks.color = Color(1.0, 0.55, 0.15, 1.0)
	sparks.global_position = global_pos + Vector2(0.0, -20.0)
	get_tree().current_scene.add_child(sparks)
	_cleanup_after(sparks, 0.6)


func _create_dust_particles(impact_speed: float) -> CPUParticles2D:
	var dust := CPUParticles2D.new()
	dust.one_shot = true
	dust.emitting = true
	dust.amount = int(clampf(impact_speed / 18.0, 6.0, 20.0))
	dust.lifetime = 0.55
	dust.explosiveness = 0.85
	dust.direction = Vector2(0.0, -1.0)
	dust.spread = 55.0
	dust.gravity = Vector2(0.0, 120.0)
	dust.initial_velocity_min = 30.0
	dust.initial_velocity_max = 80.0 + impact_speed * 0.15
	dust.scale_amount_min = 3.0
	dust.scale_amount_max = 6.0
	dust.color = Color(0.55, 0.42, 0.28, 0.8)
	return dust


func _cleanup_after(node: Node, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(node):
		node.queue_free()
