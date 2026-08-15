class_name UpgradeOverlay
extends CanvasLayer

signal upgrade_purchased()

var tower: TowerBase
@onready var paths_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/PathsContainer
@onready var btn_close: Button = $Panel/MarginContainer/VBoxContainer/Header/BtnClose
@onready var label_gold: Label = $Panel/MarginContainer/VBoxContainer/Header/LabelGold

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	btn_close.pressed.connect(close)
	_update_gold_label()
	
func setup(t: TowerBase) -> void:
	tower = t
	_build_ui()
	
func _build_ui() -> void:
	for child in paths_container.get_children():
		child.queue_free()
		
	if not tower or not tower.data:
		return
		
	_build_path_row(0, "Rama 1", tower.data.path_1_upgrades)
	_build_path_row(1, "Rama 2", tower.data.path_2_upgrades)
	_build_path_row(2, "Rama 3", tower.data.path_3_upgrades)

func _build_path_row(path_index: int, path_name: String, upgrades: Array[UpgradeData]) -> void:
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	paths_container.add_child(row)
	
	var label = Label.new()
	label.text = path_name
	label.custom_minimum_size = Vector2(100, 0)
	row.add_child(label)
	
	var current_tier = tower.current_tiers[path_index]
	var game_manager = get_tree().root.find_child("GameManager", true, false)
	var current_gold = game_manager.gold if game_manager else 0
	
	for tier_idx in range(upgrades.size()):
		var upgrade = upgrades[tier_idx]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(180, 100)
		
		var txt = upgrade.upgrade_name + "\n$" + str(upgrade.cost)
		btn.text = txt
		
		if tier_idx < current_tier:
			btn.modulate = Color(0.5, 1.0, 0.5)
			btn.disabled = true
			btn.text += "\n(Comprado)"
		elif tier_idx == current_tier:
			var can_buy = tower.can_buy_upgrade(path_index)
			if can_buy and current_gold >= upgrade.cost:
				btn.modulate = Color(1.0, 1.0, 1.0)
				btn.disabled = false
			else:
				btn.modulate = Color(1.0, 0.5, 0.5)
				btn.disabled = true
				if not can_buy:
					btn.text += "\n(Bloqueado)"
				else:
					btn.text += "\n(Falta Oro)"
			
			if not btn.disabled:
				btn.pressed.connect(func(): _on_buy_upgrade(path_index))
		else:
			btn.modulate = Color(0.4, 0.4, 0.4)
			btn.disabled = true
			
		row.add_child(btn)

func _on_buy_upgrade(path_index: int) -> void:
	if tower.buy_upgrade(path_index):
		upgrade_purchased.emit()
		_update_gold_label()
		_build_ui()

func _update_gold_label() -> void:
	var game_manager = get_tree().root.find_child("GameManager", true, false)
	if game_manager and label_gold:
		label_gold.text = "Oro: $" + str(game_manager.gold)

func close() -> void:
	get_tree().paused = false
	queue_free()
