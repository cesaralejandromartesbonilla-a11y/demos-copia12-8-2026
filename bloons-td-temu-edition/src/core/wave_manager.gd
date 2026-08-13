class_name WaveManager
extends Node

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal all_waves_completed()

@export var waves: Array[WaveData] = []
@export var path_to_follow: Path2D
@export var bloon_scene: PackedScene

var current_wave_index: int = 0
var is_wave_active: bool = false
var active_bloons_count: int = 0

func _ready() -> void:
	GameEvents.bloon_popped.connect(_on_bloon_popped)
	GameEvents.bloon_reached_end.connect(_on_bloon_reached_end)
	
	# Wait for manual start
	pass

func start_next_wave() -> void:
	if is_wave_active:
		return
		
	if current_wave_index < waves.size():
		is_wave_active = true
		wave_started.emit(current_wave_index + 1)
		GameEvents.wave_started.emit(current_wave_index + 1)
		
		var wave = waves[current_wave_index]
		await process_wave(wave)
		
		# Esperar a que todos los globos sean destruidos
		while active_bloons_count > 0:
			await get_tree().create_timer(0.5).timeout
			
		is_wave_active = false
		wave_completed.emit(current_wave_index + 1)
		GameEvents.wave_finished.emit()
		
		current_wave_index += 1
		if current_wave_index >= waves.size():
			all_waves_completed.emit()

func process_wave(wave_data: WaveData) -> void:
	if not wave_data:
		return
		
	for group in wave_data.groups:
		if not group:
			continue
			
		if group.initial_delay > 0:
			await get_tree().create_timer(group.initial_delay).timeout
		
		for i in range(group.count):
			spawn_bloon(group.bloon_type)
			await get_tree().create_timer(group.interval).timeout

func spawn_bloon(type: BloonData) -> void:
	if not bloon_scene or not path_to_follow or not type:
		return
		
	active_bloons_count += 1
	var new_bloon = bloon_scene.instantiate()
	path_to_follow.add_child(new_bloon)
	
	if new_bloon.has_method("setup"):
		new_bloon.setup(type)

func _on_bloon_popped(_gold: int) -> void:
	active_bloons_count = max(0, active_bloons_count - 1)

func _on_bloon_reached_end(_damage: int) -> void:
	active_bloons_count = max(0, active_bloons_count - 1)
