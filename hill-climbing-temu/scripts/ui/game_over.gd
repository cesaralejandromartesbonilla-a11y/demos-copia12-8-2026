extends Control

@onready var title_label: Label = %TitleLabel
@onready var reason_label: Label = %ReasonLabel
@onready var distance_label: Label = %DistanceLabel
@onready var coins_label: Label = %CoinsLabel
@onready var total_coins_label: Label = %TotalCoinsLabel
@onready var best_label: Label = %BestLabel
@onready var retry_button: Button = %RetryButton
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	_update_results()


func _update_results() -> void:
	var distance := int(GameState.current_run_distance)
	var coins := GameState.current_run_coins
	var best := int(GameState.best_distance)
	var total := GameState.total_coins

	title_label.text = "Fin de partida"
	reason_label.text = _death_reason_text(GameState.death_reason)
	distance_label.text = "Distancia: %d m" % distance
	coins_label.text = "Monedas ganadas: %d" % coins
	total_coins_label.text = "Total acumulado: %d" % total
	best_label.text = "Récord: %d m" % best


func _death_reason_text(reason: String) -> String:
	match reason:
		"fuel":
			return "Te quedaste sin combustible"
		"crash":
			return "¡Te rompiste el cuello!"
		"quit":
			return "Partida terminada"
		_:
			return ""


func _on_retry_pressed() -> void:
	ScenePaths.go_to_game()


func _on_menu_pressed() -> void:
	ScenePaths.go_to_main_menu()
