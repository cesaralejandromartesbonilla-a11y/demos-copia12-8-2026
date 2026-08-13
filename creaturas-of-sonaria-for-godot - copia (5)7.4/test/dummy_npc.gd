extends StaticBody3D

@export var max_health: float = 50.0
var current_health: float

@onready var effect_manager = $effect_manager
@onready var damage_label_scene = preload("res://test/damage_label.tscn")
@export var xp_reward: float = 25.0

func _ready():
	current_health = max_health

func take_damage(amount: float):
	current_health -= amount
	_spawn_damage_label(amount, Color.WHITE)
	
	if current_health <= 0:
		die()

func die():
	# Buscamos al jugador para darle la XP antes de desaparecer
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var lv = player.get_node_or_null("LevelManager")
		if lv: lv.add_xp(xp_reward)
	
	print("Dummy destruido. XP entregada.")
	queue_free()

func apply_status_effect(effect: StatusEffect):
	if effect_manager:
		effect_manager.add_status_effect(effect)
		var d = effect.get("damage")
		if d: _spawn_damage_label(d, Color.ORANGE)
		
func _spawn_damage_label(amount: float, color: Color):
	var label = damage_label_scene.instantiate()
	get_tree().root.add_child(label) # Lo añadimos al mundo, no al dummy, para que no se mueva con él
	label.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 2.0, randf_range(-0.5, 0.5))
	label.display(amount, color)
