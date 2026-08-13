extends Node
class_name AbilityManager

# Aquí arrastras las escenas de las habilidades (.tscn) desde el Inspector
@export var equipped_abilities: Array[PackedScene] = []

@onready var survival = get_parent().get_node_or_null("SurvivalManager")
@onready var controller = get_parent()
@onready var level_manager = get_parent().get_node_or_null("LevelManager")

# Diccionario para rastrear los tiempos de recarga: { indice_habilidad : tiempo_restante }
var current_cooldowns: Dictionary = {}

func _process(delta: float) -> void:
	# Reducir los tiempos de recarga activos
	var keys = current_cooldowns.keys()
	for i in keys:
		current_cooldowns[i] -= delta
		if current_cooldowns[i] <= 0:
			current_cooldowns.erase(i)

func try_use_ability(index: int) -> void:
	# --- NUEVA REGLA: Bloqueo por nivel ---
	if level_manager and level_manager.level < (index + 1):
		print("Nivel insuficiente. Necesitas nivel ", index + 1)
		return
	# Validaciones de seguridad
	if index >= equipped_abilities.size() or equipped_abilities[index] == null:
		return
		
	if current_cooldowns.has(index):
		print("Habilidad ", index, " en recarga.")
		return
		
	if survival and survival.is_dead:
		return

	# Instanciar la escena de la habilidad
	var ability_scene = equipped_abilities[index]
	var ability_instance = ability_scene.instantiate()
	
	if ability_instance is AbilityBase:
		# Comprobar si hay energía suficiente
		if survival and survival.current_energy < ability_instance.energy_cost:
			print("Energía insuficiente para: ", ability_instance.ability_name)
			ability_instance.queue_free()
			return
			
		# Cobrar el coste de energía
		if survival:
			survival.current_energy -= ability_instance.energy_cost
			
		# Registrar el tiempo de recarga
		current_cooldowns[index] = ability_instance.cooldown
		
		# Añadir la habilidad al MUNDO, no a la criatura.
		# Esto evita que un proyectil de fuego se mueva si la criatura da un paso atrás.
		get_tree().root.add_child(ability_instance)
		
		# Calcular posición y dirección (asumiendo que sale del centro de la criatura)
		ability_instance.global_position = controller.global_position + Vector3(0, 1.0, 0) # Un poco elevado
		var forward_dir = -controller.global_transform.basis.z.normalized()
		
		# ¡Fuego!
		ability_instance.activate(controller, forward_dir)
		print("Habilidad activada: ", ability_instance.ability_name)
