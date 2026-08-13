#creature_select
extends Control

@onready var list_container = $MarginContainer/VBoxContainer/ButtonsContainer/CreatureListContainer

func _ready():
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
			
		btn.text = data.creature_name + " ID: " + instance["instance_id"].right(4) + status
		btn.pressed.connect(func(): _on_select_instance(instance))
		list_container.add_child(btn)

func _on_select_instance(instance: Dictionary):
	InventoryManager.set_selected_instance(instance)
	get_tree().change_scene_to_file("res://ecenas/world.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ecenas/main_menu.tscn")
