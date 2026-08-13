class_name MainMenu
extends Control

@onready var main_panel: PanelContainer = $CenterContainer/MainPanel
@onready var maps_panel: PanelContainer = $CenterContainer/MapsPanel

func _ready() -> void:
	maps_panel.hide()
	main_panel.show()

func _on_button_jugar_pressed() -> void:
	if GlobalData.current_map_path == "":
		GlobalData.current_map_path = "res://scenes/maps/map_1.tscn"
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_button_mapas_pressed() -> void:
	main_panel.hide()
	maps_panel.show()

func _on_button_volver_pressed() -> void:
	maps_panel.hide()
	main_panel.show()

func _on_button_mapa1_pressed() -> void:
	GlobalData.current_map_path = "res://scenes/maps/map_1.tscn"
	_on_button_volver_pressed()

func _on_button_mapa2_pressed() -> void:
	GlobalData.current_map_path = "res://scenes/maps/map_coast.tscn"
	_on_button_volver_pressed()
