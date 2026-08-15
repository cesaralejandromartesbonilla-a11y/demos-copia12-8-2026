class_name Track
extends Path2D

@export var test_bloon_data: BloonData

const BLOON_BASE_SCENE: String = "res://scenes/entities/bloons/bloon_base.tscn"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"): # Spacebar test spawn
		var bloon_scene = load(BLOON_BASE_SCENE)
		if bloon_scene:
			var new_bloon: BloonBase = bloon_scene.instantiate()
			add_child(new_bloon)
			new_bloon.setup(test_bloon_data)
			new_bloon.progress = 0
