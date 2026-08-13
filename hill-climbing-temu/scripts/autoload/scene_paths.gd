extends Node

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const GARAGE_MENU := "res://scenes/ui/garage_menu.tscn"
const GAME_WORLD := "res://scenes/game/game_world.tscn"
const GAME_OVER := "res://scenes/ui/game_over.tscn"
const UPGRADE_MENU := "res://scenes/ui/garage_menu.tscn"


func go_to_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


func go_to_garage() -> void:
	get_tree().change_scene_to_file(GARAGE_MENU)


func go_to_upgrades() -> void:
	go_to_garage()


func go_to_game() -> void:
	GameState.reset_run()
	get_tree().change_scene_to_file(GAME_WORLD)


func go_to_game_over() -> void:
	get_tree().change_scene_to_file(GAME_OVER)
