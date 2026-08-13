extends Area3D

@export var effects_to_trigger: Array[StatusEffect] = []
@export var tick_rate: float = 1.0 # Cada cuánto tiempo aplica/refresca el efecto

func _ready():
	var timer = Timer.new()
	timer.wait_time = tick_rate
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(_refresh_effects)

func _refresh_effects():
	for body in get_overlapping_bodies():
		if body.has_method("apply_status_effect"):
			for effect in effects_to_trigger:
				# Enviamos el efecto; el Manager se encargará de resetear el tiempo
				body.apply_status_effect(effect.duplicate())
