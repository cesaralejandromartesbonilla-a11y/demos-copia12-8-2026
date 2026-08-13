class_name HealthComponent extends Node

signal health_changed(current: float, maximum: float)
signal damage_taken(amount: float, wear_percentage: float)
signal died

@export var max_health: float = 100.0
var current_health: float

func _ready():
	# Inicializamos la vida al máximo al empezar
	current_health = max_health

func take_damage(amount: float):
	if current_health <= 0:
		return # Evita recibir daño si ya está a 0
		
	current_health -= amount
	current_health = clamp(current_health, 0.0, max_health)
	
	print("Componente de Vida: Vida actual: ", current_health)
	
	# Calculamos el desgaste visual (0.0 a 1.0)
	var wear = 1.0 - (current_health / max_health)
	
	# Emitimos las señales para que quien quiera escucharlas, reaccione
	health_changed.emit(current_health, max_health)
	damage_taken.emit(amount, wear)
	
	if current_health <= 0:
		print("Componente de Vida: ¡Salud agotada!")
		died.emit()

# Extra: Ya que es un módulo dedicado, le añadimos la función de curar
func heal(amount: float):
	if current_health <= 0:
		return # No puedes curar a alguien muerto (a menos que sea otra mecánica)
		
	current_health += amount
	current_health = clamp(current_health, 0.0, max_health)
	
	health_changed.emit(current_health, max_health)
