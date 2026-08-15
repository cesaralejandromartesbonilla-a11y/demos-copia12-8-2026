extends Control

@onready var overlay = $Overlay
@onready var label = $Label
@onready var icon = $TextureRect

var ability_index: int = 0
var ability_manager: AbilityManager

func setup(index: int, manager: AbilityManager):
	ability_index = index
	ability_manager = manager

func _process(_delta):
	if not ability_manager: return
	
	# 1. Comprobar si está bloqueada por nivel
	var lv = ability_manager.level_manager.level
	if lv < (ability_index + 1):
		modulate = Color(0.2, 0.2, 0.2, 1.0) # Oscuro (bloqueado)
		label.text = "Lvl " + str(ability_index + 1)
		overlay.visible = false
		return
	else:
		modulate = Color(1, 1, 1, 1) # Color normal (desbloqueado)

	# 2. Comprobar Cooldown
	if ability_manager.current_cooldowns.has(ability_index):
		overlay.visible = true
		var time_left = ability_manager.current_cooldowns[ability_index]
		label.text = str(snapped(time_left, 0.1))
		# Hacer que el overlay baje según el tiempo (opcional)
		overlay.scale.y = time_left / 5.0 # Suponiendo cooldown de 5s
	else:
		overlay.visible = false
		label.text = str(ability_index + 1) # Muestra la tecla (1, 2, 3)
