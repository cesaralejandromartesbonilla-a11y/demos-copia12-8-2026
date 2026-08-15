extends StatusEffect
class_name BurnEffect

@export var fire_damage: float = 5.0

func apply_effect(target: Node3D):
	if target.has_method("take_damage"):
		target.take_damage(fire_damage)
		# Aquí podrías añadir lógica para que se propague a otros
		#podria pero no
		print("quemado: -", fire_damage)
		# Encender partículas si existen
		var fire_particles = target.get_node_or_null("FireParticles3D")
		if fire_particles:
			fire_particles.emitting = true
