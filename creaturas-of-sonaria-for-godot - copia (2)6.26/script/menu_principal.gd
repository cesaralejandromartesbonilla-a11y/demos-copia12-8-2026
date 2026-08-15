#menu_principal
extends Control

@onready var list_container = $MarginContainer/HBoxContainer
@onready var stats_label = $MarginContainer/HBoxContainer/ButtonsContainer/StatsLabel
@onready var btn_play = $MarginContainer/HBoxContainer/ButtonsContainer/PlayButton
@onready var exit_button: Button = $MarginContainer/HBoxContainer/ButtonsContainer/ExitButton

var currently_selected_instance: Dictionary = {}

func _ready():
	btn_play.disabled = true
	btn_play.pressed.connect(_on_play_pressed)
	exit_button.pressed.connect(_on_back_pressed)
	update_inventory()

func update_inventory():
	for child in list_container.get_children(): 
		if child is Button: child.queue_free()
	
	for instance in InventoryManager.player_data.owned_instances:
		var data = load(instance["creature_path"]) as CreatureData
		var btn = Button.new()
		
		var status = " (Nuevo)"
		if InventoryManager.has_save_file(instance["instance_id"]):
			status = " (Continuar)"
			
		btn.text = data.creature_name + status
		btn.pressed.connect(func(): _on_select_instance(instance, data))
		list_container.add_child(btn)

func _on_select_instance(instance: Dictionary, data: CreatureData):
	currently_selected_instance = instance
	btn_play.disabled = false
	
	# Revisamos si hay partida guardada para mostrar stats actuales
	if InventoryManager.has_save_file(instance["instance_id"]):
		var save = load(InventoryManager._get_save_path_by_id(instance["instance_id"]))
		stats_label.text = "Criatura: " + data.creature_name + "\n"
		stats_label.text += "Nivel: " + str(save.level) + "\n"
		stats_label.text += "Vida Guardada: " + str(save.current_health) + "\n"
		stats_label.text += "Estado: Viva"
	else:
		stats_label.text = "Criatura: " + data.creature_name + "\n"
		stats_label.text += "Estado: Sin empezar (Nivel 1)"

func _on_play_pressed():
	if not currently_selected_instance.is_empty():
		InventoryManager.set_selected_instance(currently_selected_instance)
		get_tree().change_scene_to_file("res://ecenas/world.tscn")

func _on_shop_pressed():
	get_tree().change_scene_to_file("res://ecenas/shop.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ecenas/main_menu.tscn")
