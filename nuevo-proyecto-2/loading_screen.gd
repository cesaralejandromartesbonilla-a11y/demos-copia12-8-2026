extends CanvasLayer

@onready var label = $ColorRect/Label

func _ready():
	hide() # Empieza oculta

func show_message(text: String):
	label.text = text
	show()

func hide_screen():
	hide()
