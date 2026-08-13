class_name PickupManager
extends Node2D

@export var min_spacing: float = 750.0
@export var max_spacing: float = 1050.0
@export var spawn_start_x: float = 550.0
@export var spawn_ahead_distance: float = 3500.0
@export var cull_behind_distance: float = 900.0
@export var coins_per_segment_min: int = 2
@export var coins_per_segment_max: int = 5
@export var air_coin_chance: float = 0.35

var _terrain: TerrainGenerator
var _fuel_restore_amount: float = 40.0
var _fuel_scene: PackedScene = preload("res://scenes/pickups/fuel_can.tscn")
var _coin_scene: PackedScene = preload("res://scenes/pickups/coin.tscn")
var _spawn_cursor_x: float = 0.0


func setup(terrain: TerrainGenerator, fuel_restore_amount: float) -> void:
	_terrain = terrain
	_fuel_restore_amount = fuel_restore_amount
	_spawn_cursor_x = spawn_start_x


func update_for_position(world_x: float) -> void:
	_spawn_until(world_x + spawn_ahead_distance)
	_cull_behind(world_x - cull_behind_distance)


func _spawn_until(target_x: float) -> void:
	while _spawn_cursor_x < target_x:
		_spawn_segment(_spawn_cursor_x)
		_spawn_cursor_x += randf_range(min_spacing, max_spacing)


func _spawn_segment(world_x: float) -> void:
	_spawn_fuel_can(world_x)

	var coin_count := randi_range(coins_per_segment_min, coins_per_segment_max)
	for _i in coin_count:
		var offset_x := randf_range(-120.0, 120.0)
		_spawn_coin(world_x + offset_x)


func _spawn_fuel_can(world_x: float) -> void:
	var can: FuelCan = _fuel_scene.instantiate() as FuelCan
	var ground_y: float = _terrain.get_height_at(world_x)
	can.global_position = Vector2(world_x, ground_y - 30.0)
	can.restore_amount = _fuel_restore_amount
	add_child(can)


func _spawn_coin(world_x: float) -> void:
	var coin: Coin = _coin_scene.instantiate() as Coin
	var ground_y: float = _terrain.get_height_at(world_x)
	var spawn_y: float

	if randf() < air_coin_chance:
		spawn_y = ground_y - randf_range(70.0, 130.0)
	else:
		spawn_y = ground_y - randf_range(22.0, 36.0)

	coin.global_position = Vector2(world_x, spawn_y)
	add_child(coin)


func _cull_behind(world_x: float) -> void:
	for child: Node in get_children():
		if (child is FuelCan or child is Coin) and child.global_position.x < world_x:
			child.queue_free()
