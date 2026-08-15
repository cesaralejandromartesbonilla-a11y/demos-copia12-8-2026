extends Button

@export var action_name: StringName = &"gas"
@export var pressed_scale: Vector2 = Vector2(0.94, 0.94)
@export var pressed_modulate: Color = Color(0.78, 0.78, 0.78, 1.0)

var _base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	_base_scale = scale
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	focus_exited.connect(_on_button_up)


func _on_button_down() -> void:
	Input.action_press(action_name)
	scale = _base_scale * pressed_scale
	modulate = pressed_modulate


func _on_button_up() -> void:
	Input.action_release(action_name)
	scale = _base_scale
	modulate = Color.WHITE
