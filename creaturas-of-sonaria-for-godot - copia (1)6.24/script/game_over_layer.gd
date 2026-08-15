extends CanvasLayer

@onready var retry_button: Button = $ColorRect/CenterContainer/VBoxContainer/ButtonMenu
@onready var label_time = $ColorRect/CenterContainer/VBoxContainer/LabelTime
@onready var label_growth = $ColorRect/CenterContainer/VBoxContainer/LabelGrowth

func _ready() -> void:
	visible = false 
	retry_button.pressed.connect(_on_retry_pressed)
	hide()

func show_death_screen(time_text: String, growth: float):
	# 1. PERMADEATH: Borramos el archivo de guardado inmediatamente
	InventoryManager.delete_current_save()
	
	# 2. Asignamos los textos de estadísticas
	label_time.text = "Tiempo sobrevivido: " + time_text
	label_growth.text = "Crecimiento alcanzado: " + str(int(growth * 100)) + "%"
	
	# 3. Activamos el nodo y el ratón
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	print("Partida borrada. Mostrando pantalla de muerte.")

func _on_button_menu_pressed():
	# Al volver al menú, ya no podrá cargar a esta criatura porque el archivo no existe
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func show_menu() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true 

func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ecenas/main_menu.tscn")
