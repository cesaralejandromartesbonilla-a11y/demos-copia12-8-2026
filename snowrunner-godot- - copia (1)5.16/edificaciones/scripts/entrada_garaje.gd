extends Area3D

var camion_en_zona: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugador"):
		camion_en_zona = true
		print("Presiona ENTER para entrar al Garaje") # Aquí luego pondremos un texto en la UI

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("jugador"):
		camion_en_zona = false

func _process(_delta: float) -> void:
	if camion_en_zona and Input.is_action_just_pressed("ui_accept"): # ui_accept suele ser ENTER
		# Viajamos a la escena del garaje
		get_tree().change_scene_to_file("res://ecenas/garaje_manager.tscn")
