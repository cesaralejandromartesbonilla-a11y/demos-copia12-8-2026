extends Area3D
class_name AbilityBase

@export var ability_name: String = "Habilidad Base"
@export var energy_cost: float = 15.0
@export var cooldown: float = 2.0

var caster: Node3D
var direction: Vector3

# Esta función la llamará el AbilityManager cuando se instancie la escena
func activate(user: Node3D, dir: Vector3) -> void:
	caster = user
	direction = dir
	
	# Aquí es donde las clases hijas (el fuego, el robo de vida, etc.) 
	# escribirán su propia lógica usando _execute_ability()
	_execute_ability()

# Función virtual para ser sobreescrita por las habilidades específicas
func _execute_ability() -> void:
	pass

# Función útil para que la habilidad se destruya a sí misma cuando termine
func end_ability() -> void:
	queue_free()
