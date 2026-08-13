extends Control

@onready var coins_label: Label = %CoinsLabel
@onready var engine_label: Label = %EngineLabel
@onready var engine_button: Button = %EngineButton
@onready var suspension_label: Label = %SuspensionLabel
@onready var suspension_button: Button = %SuspensionButton
@onready var tank_label: Label = %TankLabel
@onready var tank_button: Button = %TankButton
@onready var back_button: Button = %BackButton


func _ready() -> void:
	engine_button.pressed.connect(_on_engine_pressed)
	suspension_button.pressed.connect(_on_suspension_pressed)
	tank_button.pressed.connect(_on_tank_pressed)
	back_button.pressed.connect(_on_back_pressed)
	GameState.garage_changed.connect(_refresh_ui)
	_refresh_ui()


func _refresh_ui() -> void:
	coins_label.text = "Monedas: %d" % GameState.total_coins
	_update_row(
		UpgradeDefs.Type.ENGINE,
		engine_label,
		engine_button,
	)
	_update_row(
		UpgradeDefs.Type.SUSPENSION,
		suspension_label,
		suspension_button,
	)
	_update_row(
		UpgradeDefs.Type.TANK,
		tank_label,
		tank_button,
	)


func _update_row(type: UpgradeDefs.Type, info_label: Label, buy_button: Button) -> void:
	var level := GameState.get_upgrade_level(type)
	var max_level := UpgradeDefs.MAX_LEVEL
	var cost := GameState.get_upgrade_cost(type)

	info_label.text = "%s  ·  Nivel %d/%d\n%s" % [
		UpgradeDefs.get_display_name(type),
		level,
		max_level,
		UpgradeDefs.get_description(type),
	]

	if cost < 0:
		buy_button.text = "Nivel máximo"
		buy_button.disabled = true
		return

	buy_button.text = "Mejorar (%d)" % cost
	buy_button.disabled = not GameState.can_purchase_upgrade(type)


func _on_engine_pressed() -> void:
	GameState.purchase_upgrade(UpgradeDefs.Type.ENGINE)


func _on_suspension_pressed() -> void:
	GameState.purchase_upgrade(UpgradeDefs.Type.SUSPENSION)


func _on_tank_pressed() -> void:
	GameState.purchase_upgrade(UpgradeDefs.Type.TANK)


func _on_back_pressed() -> void:
	ScenePaths.go_to_main_menu()
