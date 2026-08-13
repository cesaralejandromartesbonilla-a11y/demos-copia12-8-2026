extends Control

@onready var play_button: Button = %PlayButton
@onready var garage_button: Button = %GarageButton
@onready var best_distance_label: Label = %BestDistanceLabel
@onready var total_coins_label: Label = %TotalCoinsLabel
@onready var loadout_label: Label = %LoadoutLabel


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	garage_button.pressed.connect(_on_garage_pressed)
	visibility_changed.connect(_on_visibility_changed)
	_update_stats()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_update_stats()


func _update_stats() -> void:
	best_distance_label.text = "Récord: %d m" % int(GameState.best_distance)
	total_coins_label.text = "Monedas: %d" % GameState.total_coins

	var vehicle_def := GameState.get_selected_vehicle()
	var map_def := GameState.get_selected_map()
	var vehicle_name := vehicle_def.display_name if vehicle_def else "?"
	var map_name := map_def.display_name if map_def else "?"
	loadout_label.text = "%s  ·  %s" % [vehicle_name, map_name]


func _on_play_pressed() -> void:
	ScenePaths.go_to_game()


func _on_garage_pressed() -> void:
	ScenePaths.go_to_garage()
