class_name GameManager
extends Node

signal lives_changed(new_lives: int)
signal gold_changed(new_gold: int)
signal game_over()

@export var starting_lives: int = 100
@export var starting_gold: int = 650

var lives: int
var gold: int

func _ready() -> void:
	lives = starting_lives
	gold = starting_gold
	
	call_deferred("_load_map")
	
	GameEvents.bloon_popped.connect(_on_bloon_popped)
	GameEvents.bloon_reached_end.connect(_on_bloon_reached_end)
	GameEvents.tower_placed.connect(_on_tower_placed)
	
	call_deferred("_emit_initial_stats")

func _load_map() -> void:
	if GlobalData and GlobalData.current_map_path != "":
		var map_scene = load(GlobalData.current_map_path) as PackedScene
		if map_scene:
			var map_instance = map_scene.instantiate()
			get_parent().add_child(map_instance)
			get_parent().move_child(map_instance, 0)
			
			var wave_manager = get_parent().get_node_or_null("WaveManager")
			var track = map_instance.get_node_or_null("Track")
			if wave_manager and track:
				wave_manager.path_to_follow = track

func _emit_initial_stats() -> void:
	lives_changed.emit(lives)
	gold_changed.emit(gold)

func can_afford(cost: int) -> bool:
	return gold >= cost

func _on_bloon_popped(gold_earned: int) -> void:
	gold += gold_earned
	gold_changed.emit(gold)

func _on_bloon_reached_end(damage_to_base: int) -> void:
	lives = max(0, lives - damage_to_base)
	lives_changed.emit(lives)
	
	if lives <= 0:
		game_over.emit()
		print("GAME OVER - Vidas agotadas")

func _on_tower_placed(tower_data: TowerData) -> void:
	if tower_data:
		gold -= tower_data.cost
		gold_changed.emit(gold)
