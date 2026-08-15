extends Node
class_name LevelManager

signal leveled_up(new_level: int)
signal xp_changed(current: float, required: float)

@export var level: int = 1
@export var current_xp: float = 0.0
@export var xp_requirement_base: float = 100.0

func _ready():
	# XP pasiva por sobrevivir (cada 10 segundos ganas 5 de XP)
	var timer = Timer.new()
	timer.wait_time = 10.0
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(func(): add_xp(5.0))

func add_xp(amount: float):
	current_xp += amount
	var required = get_required_xp()
	
	while current_xp >= required:
		current_xp -= required
		level_up()
		required = get_required_xp()
	
	xp_changed.emit(current_xp, required)

func level_up():
	level += 1
	leveled_up.emit(level)
	print("¡Subiste al nivel ", level, "!")

func get_required_xp() -> float:
	return xp_requirement_base * pow(level, 1.5) # Escala de dificultad
