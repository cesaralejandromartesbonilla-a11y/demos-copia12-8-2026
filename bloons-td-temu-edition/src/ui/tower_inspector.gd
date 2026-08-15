class_name TowerInspector
extends Control

signal tower_sold(refund_amount: int)

@export var selected_tower: TowerBase = null
var range_indicator: Node2D = null

@onready var panel_container: PanelContainer = $PanelContainer
@onready var label_name: Label = $PanelContainer/MarginContainer/VBoxContainer/LabelName
@onready var label_pops: Label = $PanelContainer/MarginContainer/VBoxContainer/LabelPops
@onready var label_gold: Label = $PanelContainer/MarginContainer/VBoxContainer/LabelGold
@onready var button_target: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonTarget
@onready var button_path_1: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonPath1
@onready var button_path_2: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonPath2
@onready var button_path_3: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonPath3
@onready var button_ability: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonAbility
@onready var button_sell: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonSell

func _ready() -> void:
	GameEvents.tower_selected.connect(select_tower)
	GameEvents.tower_deselected.connect(deselect)
	hide()

func _process(_delta: float) -> void:
	if not selected_tower:
		return
	_update_upgrade_buttons()
	if selected_tower.has_active_ability:
		_update_ability_button()

func select_tower(tower: TowerBase) -> void:
	selected_tower = tower
	if not selected_tower or not selected_tower.data:
		deselect()
		return
	
	label_name.text = selected_tower.data.tower_id.capitalize() + " Tower"
	_update_target_button_text()
	_update_upgrade_buttons()
	_update_ability_button()
	
	var refund = int(selected_tower.data.cost * 0.7)
	button_sell.text = "Vender ($" + str(refund) + ")"
	
	_draw_range_indicator()
	show()

func deselect() -> void:
	selected_tower = null
	if range_indicator:
		range_indicator.queue_free()
		range_indicator = null
	hide()

func _update_target_button_text() -> void:
	if not selected_tower:
		return
	var mode_name: String = ""
	match selected_tower.targeting_mode:
		GameEnums.TargetingMode.FIRST: mode_name = "Primero"
		GameEnums.TargetingMode.LAST: mode_name = "Último"
		GameEnums.TargetingMode.STRONG: mode_name = "Fuerte"
		GameEnums.TargetingMode.CLOSE: mode_name = "Cercano"
	button_target.text = "Objetivo: " + mode_name

func _update_upgrade_buttons() -> void:
	if not selected_tower or not selected_tower.data:
		return
	
	_update_path_button(button_path_1, 0, "1")
	_update_path_button(button_path_2, 1, "2")
	_update_path_button(button_path_3, 2, "3")
	
	# Actualizar label de pops y gold
	label_pops.text = "Bajas: " + str(selected_tower.pops_count)
	var gm = get_tree().root.find_child("GameManager", true, false)
	label_gold.text = "Oro: $" + str(gm.gold) if gm else ""

func _update_path_button(btn: Button, path_idx: int, label: String) -> void:
	var next = selected_tower.get_next_upgrade(path_idx)
	var tier = selected_tower.current_tiers[path_idx]
	var can = selected_tower.can_buy_upgrade(path_idx)
	var gm = get_tree().root.find_child("GameManager", true, false)
	var gold = gm.gold if gm else 0
	
	if next:
		var tier_str = str(tier) + "→" + str(tier + 1)
		btn.text = "R" + label + " [" + tier_str + "]: " + next.upgrade_name + " $" + str(next.cost)
		var affordable = gold >= next.cost
		btn.disabled = not can or not affordable
		if not can:
			btn.modulate = Color(0.5, 0.5, 0.5)
		elif not affordable:
			btn.modulate = Color(1.0, 0.4, 0.4)
		else:
			btn.modulate = Color(0.4, 1.0, 0.6)
	else:
		btn.text = "R" + label + " [MAX]"
		btn.disabled = true
		btn.modulate = Color(0.3, 0.8, 0.3)

func _update_ability_button() -> void:
	if not selected_tower or not selected_tower.has_active_ability:
		button_ability.hide()
		return
	
	button_ability.show()
	var ad = selected_tower.ability_data
	if not ad:
		return
	
	if selected_tower.ability_active:
		button_ability.text = "⚡ " + ad.ability_name + " (Activo...)"
		button_ability.disabled = true
		button_ability.modulate = Color(0.2, 0.8, 1.0)
	elif selected_tower.ability_cooldown_remaining > 0:
		var secs = int(ceil(selected_tower.ability_cooldown_remaining))
		button_ability.text = "⚡ " + ad.ability_name + " (" + str(secs) + "s)"
		button_ability.disabled = true
		button_ability.modulate = Color(0.8, 0.8, 0.3)
	else:
		button_ability.text = "⚡ " + ad.ability_name + " (Listo!)"
		button_ability.disabled = false
		button_ability.modulate = Color(1.0, 0.9, 0.2)

func _buy_upgrade(path_index: int) -> void:
	if not selected_tower:
		return
	if selected_tower.buy_upgrade(path_index):
		_update_upgrade_buttons()
		_draw_range_indicator()
		# Notificar HUD global
		GameEvents.tower_upgraded.emit(selected_tower)

func _on_button_path_1_pressed() -> void:
	_buy_upgrade(0)

func _on_button_path_2_pressed() -> void:
	_buy_upgrade(1)

func _on_button_path_3_pressed() -> void:
	_buy_upgrade(2)

func _on_button_ability_pressed() -> void:
	if selected_tower and selected_tower.has_method("activate_ability"):
		selected_tower.activate_ability()

func _on_button_target_pressed() -> void:
	if not selected_tower:
		return
	match selected_tower.targeting_mode:
		GameEnums.TargetingMode.FIRST:
			selected_tower.targeting_mode = GameEnums.TargetingMode.LAST
		GameEnums.TargetingMode.LAST:
			selected_tower.targeting_mode = GameEnums.TargetingMode.STRONG
		GameEnums.TargetingMode.STRONG:
			selected_tower.targeting_mode = GameEnums.TargetingMode.CLOSE
		GameEnums.TargetingMode.CLOSE:
			selected_tower.targeting_mode = GameEnums.TargetingMode.FIRST
	_update_target_button_text()

func _on_button_sell_pressed() -> void:
	if not selected_tower or not selected_tower.data:
		return
	var refund = int(selected_tower.data.cost * 0.7)
	
	var game_manager = get_tree().root.find_child("GameManager", true, false)
	if game_manager:
		game_manager.gold += refund
		game_manager.gold_changed.emit(game_manager.gold)
	
	GameEvents.tower_sold.emit(selected_tower)
	selected_tower.queue_free()
	deselect()

func _draw_range_indicator() -> void:
	if range_indicator:
		range_indicator.queue_free()
		
	if not selected_tower or not selected_tower.data:
		return
		
	range_indicator = Node2D.new()
	range_indicator.script = load("res://src/ui/range_indicator_draw.gd")
	range_indicator.set("radius", selected_tower.get_current_range())
	selected_tower.add_child(range_indicator)
