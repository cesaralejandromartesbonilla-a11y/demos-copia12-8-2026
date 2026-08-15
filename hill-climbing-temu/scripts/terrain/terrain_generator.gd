class_name TerrainGenerator
extends Node2D

@export var chunk_width: float = 2000.0
@export var sample_step: float = 40.0
@export var base_height: float = 220.0
@export var flat_spawn_length: float = 350.0
@export var spawn_blend_length: float = 280.0
@export var chunks_ahead: int = 4
@export var chunks_behind: int = 2
@export var max_slope: float = 0.38
@export var max_slope_late: float = 0.52
@export var smooth_passes: int = 3
@export var difficulty_ramp_distance: float = 9000.0

var _noise: FastNoiseLite
var _detail_noise: FastNoiseLite
var _chunks: Dictionary = {}
var _chunk_scene: PackedScene = preload("res://scenes/game/terrain_chunk.tscn")
var _ground_color: Color = Color(0.35, 0.55, 0.22)
var _active_map_id: String = "countryside"


func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.seed = randi()
	_noise.frequency = 0.55
	_noise.fractal_octaves = 3
	_noise.fractal_lacunarity = 2.0
	_noise.fractal_gain = 0.45

	_detail_noise = FastNoiseLite.new()
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail_noise.seed = _noise.seed + 97
	_detail_noise.frequency = 0.9
	_detail_noise.fractal_octaves = 2
	_detail_noise.fractal_gain = 0.5


func apply_map(map_def: MapDef) -> void:
	if map_def == null:
		return

	_active_map_id = map_def.id
	base_height = map_def.base_height
	difficulty_ramp_distance = map_def.difficulty_ramp_distance
	_ground_color = map_def.ground_color


func get_active_map_id() -> String:
	return _active_map_id


func get_difficulty(world_x: float) -> float:
	if world_x <= flat_spawn_length:
		return 0.0

	var ramp_x := maxf(world_x - flat_spawn_length, 0.0)
	return clampf(ramp_x / difficulty_ramp_distance, 0.0, 1.0)


func get_height_at(world_x: float) -> float:
	var varied_height := _get_varied_height(world_x)

	if world_x <= flat_spawn_length:
		return base_height

	if world_x < flat_spawn_length + spawn_blend_length:
		var blend_t := (world_x - flat_spawn_length) / spawn_blend_length
		blend_t = smoothstep(0.0, 1.0, blend_t)
		return lerpf(base_height, varied_height, blend_t)

	return varied_height


func get_spawn_position(spawn_x: float = 120.0) -> Vector2:
	var ground_y := get_height_at(spawn_x)
	return Vector2(spawn_x, ground_y - 42.0)


func update_for_position(world_x: float) -> void:
	var center_index := int(floor(world_x / chunk_width))

	for index in range(center_index - chunks_behind, center_index + chunks_ahead + 1):
		if not _chunks.has(index):
			_spawn_chunk(index)

	var indices_to_remove: Array[int] = []
	for index: int in _chunks.keys():
		if index < center_index - chunks_behind or index > center_index + chunks_ahead:
			indices_to_remove.append(index)

	for index: int in indices_to_remove:
		var chunk: TerrainChunk = _chunks[index]
		chunk.queue_free()
		_chunks.erase(index)


func _get_varied_height(world_x: float) -> float:
	var difficulty := get_difficulty(world_x)
	var amplitude_mult := lerpf(1.0, 2.6, difficulty)
	var freq_mult := lerpf(1.0, 1.4, difficulty)

	var noise_height := _noise.get_noise_1d(world_x * 0.0018 * freq_mult) * lerpf(32.0, 72.0, difficulty)
	noise_height *= amplitude_mult

	var detail := _detail_noise.get_noise_1d(world_x * 0.0045 * freq_mult) * lerpf(0.0, 28.0, difficulty)

	var wave_a := sin(world_x * 0.0035 * freq_mult) * lerpf(12.0, 38.0, difficulty)
	var wave_b := sin(world_x * 0.009 * freq_mult + 1.4) * lerpf(5.0, 20.0, difficulty)
	var wave_c := sin(world_x * 0.016 * freq_mult + 0.6) * lerpf(0.0, 16.0, difficulty)

	return base_height + noise_height + detail + wave_a + wave_b + wave_c


func _get_max_slope_at(world_x: float) -> float:
	return lerpf(max_slope, max_slope_late, get_difficulty(world_x))


func _spawn_chunk(index: int) -> void:
	var chunk: TerrainChunk = _chunk_scene.instantiate() as TerrainChunk
	chunk.position.x = index * chunk_width
	add_child(chunk)

	var chunk_start_x := chunk.position.x
	var extended_points := PackedVector2Array()
	var local_x := -sample_step
	while local_x <= chunk_width + sample_step + 0.01:
		extended_points.append(Vector2(local_x, get_height_at(chunk_start_x + local_x)))
		local_x += sample_step

	var smoothed := _smooth_surface_points(extended_points, chunk_start_x)
	var surface_points := PackedVector2Array()
	for point_index in range(1, smoothed.size() - 1):
		surface_points.append(smoothed[point_index])

	chunk.setup(surface_points)
	chunk.ground_color = _ground_color
	_chunks[index] = chunk


func _smooth_surface_points(points: PackedVector2Array, chunk_start_x: float) -> PackedVector2Array:
	if points.size() < 3:
		return points

	var smoothed := points.duplicate()
	var working := points.duplicate()

	for _pass_index in smooth_passes:
		working = smoothed.duplicate()
		for point_index in range(1, smoothed.size() - 1):
			var prev_y: float = working[point_index - 1].y
			var curr_y: float = working[point_index].y
			var next_y: float = working[point_index + 1].y
			smoothed[point_index].y = prev_y * 0.2 + curr_y * 0.6 + next_y * 0.2

	_limit_slope(smoothed, chunk_start_x)
	return smoothed


func _limit_slope(points: PackedVector2Array, chunk_start_x: float) -> void:
	for point_index in range(1, points.size()):
		var world_x: float = chunk_start_x + points[point_index].x
		var max_delta: float = sample_step * _get_max_slope_at(world_x)
		var delta_y: float = points[point_index].y - points[point_index - 1].y
		if absf(delta_y) > max_delta:
			points[point_index].y = points[point_index - 1].y + signf(delta_y) * max_delta

	for point_index in range(points.size() - 2, -1, -1):
		var world_x: float = chunk_start_x + points[point_index].x
		var max_delta: float = sample_step * _get_max_slope_at(world_x)
		var delta_y: float = points[point_index].y - points[point_index + 1].y
		if absf(delta_y) > max_delta:
			points[point_index].y = points[point_index + 1].y + signf(delta_y) * max_delta
