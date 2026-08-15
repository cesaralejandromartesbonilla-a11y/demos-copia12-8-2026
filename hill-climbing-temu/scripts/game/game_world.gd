extends Node2D

@onready var distance_label: Label = %DistanceLabel
@onready var coins_label: Label = %CoinsLabel
@onready var fuel_bar: ProgressBar = %FuelBar
@onready var end_run_button: Button = %EndRunButton
@onready var camera: FollowCamera = $Camera2D
@onready var terrain_generator: TerrainGenerator = $TerrainGenerator
@onready var pickup_manager: PickupManager = $PickupManager
@onready var parallax: GameParallax = $ParallaxBackground
@onready var vehicle_spawn: Marker2D = $VehicleSpawn

const PIXELS_PER_METER := 10.0

var vehicle: VehicleController
var _start_x: float = 0.0
var _run_finished: bool = false


func _ready() -> void:
	var map_def := GameState.get_selected_map()
	var vehicle_def := GameState.get_selected_vehicle()

	if map_def != null:
		terrain_generator.apply_map(map_def)
		parallax.apply_map(map_def)

	_spawn_vehicle(vehicle_def)
	var run_stats := GameState.build_vehicle_stats()
	vehicle.apply_stats(run_stats)

	var spawn_pos := terrain_generator.get_spawn_position()
	vehicle.global_position = spawn_pos
	_start_x = spawn_pos.x

	terrain_generator.update_for_position(vehicle.global_position.x)
	pickup_manager.setup(terrain_generator, run_stats.fuel_can_restore)

	camera.setup(vehicle)

	vehicle.died.connect(_on_vehicle_died)
	vehicle.fuel_changed.connect(_on_fuel_changed)
	GameState.run_coins_changed.connect(_on_run_coins_changed)
	end_run_button.pressed.connect(_on_end_run_pressed)

	_on_fuel_changed(vehicle.fuel_current, vehicle.fuel_max)
	_on_run_coins_changed(GameState.current_run_coins)


func _spawn_vehicle(vehicle_def: VehicleDef) -> void:
	var scene_path := "res://scenes/game/vehicle.tscn"
	if vehicle_def != null and not vehicle_def.scene_path.is_empty():
		scene_path = vehicle_def.scene_path

	var vehicle_scene: PackedScene = load(scene_path) as PackedScene
	vehicle = vehicle_scene.instantiate() as VehicleController
	add_child(vehicle)


func _physics_process(_delta: float) -> void:
	if _run_finished or vehicle == null:
		return

	terrain_generator.update_for_position(vehicle.global_position.x)
	pickup_manager.update_for_position(vehicle.global_position.x)

	var distance_m := maxf(0.0, (vehicle.global_position.x - _start_x) / PIXELS_PER_METER)
	GameState.current_run_distance = distance_m
	distance_label.text = "Distancia: %d m" % int(distance_m)


func _on_fuel_changed(current: float, max_value: float) -> void:
	fuel_bar.max_value = max_value
	fuel_bar.value = current


func _on_run_coins_changed(amount: int) -> void:
	coins_label.text = "Monedas: %d" % amount


func _on_vehicle_died(reason: String) -> void:
	if _run_finished:
		return

	GameState.death_reason = reason

	if reason == "crash":
		camera.shake(14.0)
	elif reason == "fuel":
		camera.shake(6.0)

	await get_tree().create_timer(0.6).timeout
	_finish_run()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _run_finished:
		GameState.death_reason = "quit"
		_finish_run()


func _on_end_run_pressed() -> void:
	if _run_finished:
		return

	GameState.death_reason = "quit"
	_finish_run()


func _finish_run() -> void:
	if _run_finished:
		return

	_run_finished = true
	var distance_m := maxf(0.0, (vehicle.global_position.x - _start_x) / PIXELS_PER_METER)
	GameState.end_run(distance_m, GameState.current_run_coins)
	ScenePaths.go_to_game_over()
