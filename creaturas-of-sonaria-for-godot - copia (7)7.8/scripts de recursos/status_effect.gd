extends Resource
class_name StatusEffect

@export var effect_name: String = "Efecto"
@export var duration: float = 5.0
@export var tick_interval: float = 1.0 # Cada cuánto tiempo hace efecto

# Esta función se ejecutará en la criatura
func apply_effect(_target: Node3D):
	pass # Se sobrescribe en los hijos
