#shop_creature
extends Control

@export var catalog: Array[CreatureData] = [] # Pon todas las criaturas aquí
@onready var list_container = $MarginContainer/VBoxContainer/HScrollBar/VBoxContainer
@onready var coin_label = $"coin label"

func _ready():
	update_shop()

func update_shop():
	coin_label.text = "Monedas: " + str(InventoryManager.player_data.coins)
	for child in list_container.get_children(): child.queue_free()
	
	for creature in catalog:
		# SOLO mostramos las que NO están compradas
		# Si quieres que se pueda comprar infinitamente la misma:
		var btn = Button.new()
		btn.text = "Comprar " + creature.creature_name + " ($" + str(creature.price) + ")"
		btn.pressed.connect(func(): _on_buy(creature))
		list_container.add_child(btn)

func _on_buy(creature: CreatureData):
	if InventoryManager.buy_creature(creature):
		update_shop()
	else:
		print("Dinero insuficiente")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://ecenas/main_menu.tscn")
