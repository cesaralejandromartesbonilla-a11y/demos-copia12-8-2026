extends StatusEffect
class_name PoisonEffect

@export var damage_per_tick: float = 2.0

func apply_effect(target: Node3D):
	if target.has_method("take_damage"):
		target.take_damage(damage_per_tick)
		print("Envenenado: -", damage_per_tick)
