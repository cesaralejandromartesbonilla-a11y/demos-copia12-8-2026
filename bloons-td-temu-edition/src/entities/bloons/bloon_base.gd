class_name BloonBase
extends PathFollow2D

@export var data: BloonData
var current_health: int
var is_camo: bool = false
var is_regrow: bool = false
var max_health: int = 1
var stun_timer: float = 0.0

const BLOON_BASE_SCENE: String = "res://scenes/entities/bloons/bloon_base.tscn"

func _ready() -> void:
	add_to_group("enemigo")
	if has_node("Hitbox"):
		var hitbox: Area2D = $Hitbox
		hitbox.collision_layer = 2 # Layer 2: bloons
		hitbox.collision_mask = 4  # Layer 3: projectiles
		hitbox.add_to_group("enemigo")

func setup(bloon_data: BloonData) -> void:
	data = bloon_data
	if data:
		current_health = data.health
		max_health = data.health
		is_camo = data.is_camo
		is_regrow = data.is_regrow
		
		if is_camo:
			add_to_group("camo")
			modulate = data.color_tint * Color(0.6, 0.6, 1.0, 0.8) # Tinte distintivo para bloons camuflados
		else:
			modulate = data.color_tint
			
		scale = Vector2(data.scale_multiplier, data.scale_multiplier)
			
		if has_node("Sprite2D") and data.bloon_texture:
			$Sprite2D.texture = data.bloon_texture

func get_health() -> int:
	return current_health

func _process(delta: float) -> void:
	if not data:
		return
		
	if stun_timer > 0.0:
		stun_timer -= delta
		return
		
	progress += data.speed * delta
	
	if progress_ratio >= 1.0:
		GameEvents.bloon_reached_end.emit(current_health)
		queue_free()

func stun(duration: float) -> void:
	if stun_timer < duration:
		stun_timer = duration

func knockback(distance: float) -> void:
	progress = max(0.0, progress - distance)


func take_damage(amount: int, damage_type: GameEnums.DamageType = GameEnums.DamageType.SHARP) -> bool:
	if data and data.immunities.has(damage_type):
		# El globo es inmune a este tipo de daño (ej. Plomo inmune a Dardo afilado)
		print("¡Impacto ineficaz! El globo ", data.bloon_id, " es inmune al daño tipo: ", damage_type)
		return false
		
	current_health -= amount
	
	if current_health <= 0:
		pop()
	return true

func pop() -> void:
	if data:
		GameEvents.bloon_popped.emit(data.reward_money)
		
		if data.children_on_pop.size() > 0:
			var parent_node = get_parent()
			if parent_node:
				for i in range(data.children_on_pop.size()):
					var child_data = data.children_on_pop[i]
					var new_bloon: BloonBase = load(BLOON_BASE_SCENE).instantiate()
					parent_node.call_deferred("add_child", new_bloon)
					new_bloon.setup(child_data)
					new_bloon.progress = self.progress - (i * 15.0)
				
	queue_free()
