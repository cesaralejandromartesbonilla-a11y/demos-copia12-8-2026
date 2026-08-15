extends Button

const COIN_SCENE: PackedScene = preload("res://auto.tscn")

func _ready():
	COIN_SCENE.instantiate()
