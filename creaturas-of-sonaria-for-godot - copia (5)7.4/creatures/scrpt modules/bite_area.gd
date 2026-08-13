extends Area3D
class_name MeleeManager

@onready var evo_manager = $"../EvolutionManager"
var can_bite: bool = true

func _ready():
	monitoring = false # Apagado por defecto para no dañar al caminar

func bite():
	if not can_bite: return
	
	# Obtenemos los datos de la etapa actual
	var current_stage = _get_current_stage_data()
	if not current_stage: return
	
	print("¡Mordisco! Daño: ", current_stage.bite_damage)
	
	# Activamos la hitbox brevemente
	monitoring = true
	can_bite = false
	
	# Aquí reproducirías la animación de morder de tu modelo
	
	# Apagamos la hitbox rápido (0.2s) para que no sea un rayo láser continuo
	await get_tree().create_timer(0.2).timeout
	monitoring = false
	
	# Esperamos el tiempo de recarga de la etapa antes de poder morder otra vez
	await get_tree().create_timer(current_stage.bite_cooldown).timeout
	can_bite = true

func _on_body_entered(body: Node3D):
	# Evitar morderse a sí mismo
	if body == get_parent(): return 
	
	var current_stage = _get_current_stage_data()
	
	if body.has_method("take_damage"):
		body.take_damage(current_stage.bite_damage)
		
	if body.has_method("apply_status_effect") and current_stage.bite_effect != null:
		body.apply_status_effect(current_stage.bite_effect)

func _get_current_stage_data() -> EvolutionStage:
	if evo_manager and evo_manager.current_stage_index != -1:
		return evo_manager.available_stages[evo_manager.current_stage_index]
	return null
