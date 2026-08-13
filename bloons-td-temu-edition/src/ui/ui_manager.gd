class_name UIManager
extends CanvasLayer

@export var dart_monkey_data: TowerData
@export var tack_shooter_data: TowerData
@export var sniper_monkey_data: TowerData
@export var ninja_monkey_data: TowerData
@export var banana_farm_data: TowerData
@export var buccaneer_data: TowerData

@onready var label_lives: Label = $HUD/PanelTop/HBoxContainer/LabelLives
@onready var label_gold: Label = $HUD/PanelTop/HBoxContainer/LabelGold
@onready var label_wave: Label = $HUD/PanelTop/HBoxContainer/LabelWave
@onready var btn_start_wave: Button = $HUD/PanelTop/HBoxContainer/ButtonStartWave
@onready var btn_speed: Button = $HUD/PanelTop/HBoxContainer/ButtonSpeed
@onready var hbox_abilities: HBoxContainer = $HUD/PanelAbilities/HBoxAbilities

const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 2.0, 3.0, 4.0, 5.0, 10.0]
var current_speed_index: int = 2
var wave_manager: WaveManager

# Diccionario de botones de habilidad en HUD {tower: Button}
var ability_buttons: Dictionary = {}

func _ready() -> void:
	GameEvents.bloon_popped.connect(_on_bloon_popped)
	GameEvents.bloon_reached_end.connect(_on_bloon_reached_end)
	GameEvents.wave_started.connect(_on_wave_started)
	GameEvents.wave_finished.connect(_on_wave_finished)
	GameEvents.tower_upgraded.connect(_on_tower_upgraded)
	GameEvents.tower_sold.connect(_on_tower_sold)
	
	var game_manager = get_tree().root.find_child("GameManager", true, false)
	if game_manager:
		game_manager.lives_changed.connect(update_lives)
		game_manager.gold_changed.connect(update_gold)
		update_lives(game_manager.lives)
		update_gold(game_manager.gold)
	
	wave_manager = get_tree().root.find_child("WaveManager", true, false)
	if wave_manager:
		_update_wave_label()

func _on_dart_button_pressed() -> void:
	if dart_monkey_data:
		GameEvents.request_tower_placement.emit(dart_monkey_data)

func _on_tack_button_pressed() -> void:
	if tack_shooter_data:
		GameEvents.request_tower_placement.emit(tack_shooter_data)

func _on_sniper_button_pressed() -> void:
	if sniper_monkey_data:
		GameEvents.request_tower_placement.emit(sniper_monkey_data)

func _on_ninja_button_pressed() -> void:
	if ninja_monkey_data:
		GameEvents.request_tower_placement.emit(ninja_monkey_data)

func _on_farm_button_pressed() -> void:
	if banana_farm_data:
		GameEvents.request_tower_placement.emit(banana_farm_data)

func _on_buccaneer_button_pressed() -> void:
	if buccaneer_data:
		GameEvents.request_tower_placement.emit(buccaneer_data)

func _on_start_wave_pressed() -> void:
	if wave_manager and not wave_manager.is_wave_active:
		wave_manager.start_next_wave()
		btn_start_wave.disabled = true

func _on_speed_pressed() -> void:
	current_speed_index = (current_speed_index + 1) % SPEEDS.size()
	var new_speed = SPEEDS[current_speed_index]
	Engine.time_scale = new_speed
	btn_speed.text = "x" + str(new_speed)

func _update_wave_label() -> void:
	if wave_manager and label_wave:
		var current = min(wave_manager.current_wave_index + 1, wave_manager.waves.size())
		var total = wave_manager.waves.size()
		label_wave.text = "Oleada: " + str(current) + "/" + str(total)

func _on_wave_started(wave_num: int) -> void:
	_update_wave_label()
	if btn_start_wave:
		btn_start_wave.disabled = true

func _on_wave_finished() -> void:
	if wave_manager and wave_manager.current_wave_index < wave_manager.waves.size():
		if btn_start_wave:
			btn_start_wave.disabled = false

func update_lives(amount: int) -> void:
	if label_lives:
		label_lives.text = "Vidas: " + str(amount)

func update_gold(amount: int) -> void:
	if label_gold:
		label_gold.text = "Oro: $" + str(amount)

func _on_bloon_popped(_gold_earned: int) -> void:
	pass

func _on_bloon_reached_end(_damage: int) -> void:
	pass

func _on_tower_upgraded(tower: TowerBase) -> void:
	# Si la torre ahora tiene habilidad activa, registrar botón en HUD
	if tower.has_active_ability and not ability_buttons.has(tower):
		_register_ability_button(tower)

func _on_tower_sold(tower: TowerBase) -> void:
	if ability_buttons.has(tower):
		var btn: Button = ability_buttons[tower]
		btn.queue_free()
		ability_buttons.erase(tower)

func _register_ability_button(tower: TowerBase) -> void:
	if not tower.ability_data:
		return
	var btn = Button.new()
	btn.text = "⚡ " + tower.ability_data.ability_name
	btn.custom_minimum_size = Vector2(140, 40)
	btn.pressed.connect(func(): tower.activate_ability(); _refresh_ability_button(tower))
	ability_buttons[tower] = btn
	if hbox_abilities:
		hbox_abilities.add_child(btn)

func _refresh_ability_button(tower: TowerBase) -> void:
	if not ability_buttons.has(tower):
		return
	var btn: Button = ability_buttons[tower]
	if tower.ability_active:
		btn.text = "⚡ " + tower.ability_data.ability_name + " (Activo)"
		btn.disabled = true
	elif tower.ability_cooldown_remaining > 0:
		btn.text = "⚡ " + tower.ability_data.ability_name + " (" + str(int(ceil(tower.ability_cooldown_remaining))) + "s)"
		btn.disabled = true
	else:
		btn.text = "⚡ " + tower.ability_data.ability_name
		btn.disabled = false

func _process(_delta: float) -> void:
	# Refrescar todos los botones de habilidad en el HUD
	for tower in ability_buttons:
		if is_instance_valid(tower):
			_refresh_ability_button(tower)
		else:
			var btn: Button = ability_buttons[tower]
			btn.queue_free()
			ability_buttons.erase(tower)
			break
