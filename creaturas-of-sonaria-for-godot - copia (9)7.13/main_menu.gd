extends Control

# Rutas a las escenas (Cámbialas por las tuyas reales)
@export_file("*.tscn") var world_scene_path: String = "res://ecenas/world.tscn"
@export_file("*.tscn") var creature_select_path: String = "res://ecenas/menu_principal.tscn"
@export_file("*.tscn") var creature_shopping_path: String = "res://ecenas/shop_creatures.tscn"

@onready var play_button: Button = $MarginContainer/VBoxContainer/ButtonsContainer/PlayButton
@onready var creatures_button: Button = $MarginContainer/VBoxContainer/ButtonsContainer/CreaturesButton
@onready var creatures_button2: Button = $MarginContainer/VBoxContainer/ButtonsContainer/CreaturesButton2
@onready var exit_button: Button = $MarginContainer/VBoxContainer/ButtonsContainer/ExitButton

func _ready() -> void:
	# Aseguramos que el ratón sea visible en el menú
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Conectamos las señales por código para evitar olvidos en el editor
	play_button.pressed.connect(_on_play_pressed)
	creatures_button.pressed.connect(_on_creatures_pressed)
	creatures_button2.pressed.connect(_on_creatures_pressed2)
	exit_button.pressed.connect(_on_exit_pressed)

func _on_play_pressed() -> void:
	if world_scene_path != "":
		get_tree().change_scene_to_file(world_scene_path)
	else:
		print("Error: No has asignado una escena de mundo en el inspector")

func _on_creatures_pressed() -> void:
	# Aquí es donde irías a la selección de criaturas tipo Sonaria
	if creature_select_path != "":
		get_tree().change_scene_to_file(creature_select_path)
	else:
		print("Menú de criaturas en desarrollo...")
		
func _on_creatures_pressed2() -> void:
	# Aquí es donde irías a la selección de criaturas tipo Sonaria
	if creature_shopping_path != "":
		get_tree().change_scene_to_file(creature_shopping_path)
	else:
		print("Menú de criaturas en desarrollo...")

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_delet_pressed() -> void:
	# Podrías añadir una ventana de confirmación aquí
	InventoryManager.reset_all_data()
	get_tree().reload_current_scene()
