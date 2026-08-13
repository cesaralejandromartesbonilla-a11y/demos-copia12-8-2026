extends StatusEffect
class_name frezzingEffect

@export var freeze_damage: float = 5.0

func apply_effect(target: Node3D):
	if target.has_method("take_damage"):
		target.take_damage(freeze_damage)
		# Aquí podrías añadir lógica para que se propague a otros
		#podria pero no
		print("congelado: -", freeze_damage)
		# Encender partículas si existen
		var freeze_particles = target.get_node_or_null("freezeParticles3D")
		if freeze_particles:
			freeze_particles.emitting = true
