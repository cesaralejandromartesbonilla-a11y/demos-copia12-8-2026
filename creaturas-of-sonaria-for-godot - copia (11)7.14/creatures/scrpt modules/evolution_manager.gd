extends Node
class_name EvolutionManager

@onready var model_holder = $"../ModelHolder"
@onready var ability_manager = $"../AbilityManager"
@onready var effect_manager = $"../effect_manager"
@onready var level_manager = $"../LevelManager"
# --- ESTA ES LA LÍNEA QUE FALTA ---
@onready var survival = $"../SurvivalManager" 

var current_stage_index: int = -1
var available_stages: Array[EvolutionStage] = []

func _ready():
	if level_manager:
		level_manager.leveled_up.connect(check_evolutions)

func setup_stages(stages: Array[EvolutionStage], starting_level: int = 1):
	available_stages = stages
	if available_stages.is_empty(): return
	sync_stage_to_level(starting_level)

func check_evolutions(_current_level: int = 0):
	# Ya no usamos el current_level del parámetro, leemos todo fresco
	var next_index = current_stage_index + 1
	if next_index >= available_stages.size():
		return # Ya está en la etapa máxima
		
	var next_stage = available_stages[next_index]
	
	# Leemos los stats actuales reales
	var current_lvl = level_manager.level if level_manager else 1
	var current_growth = survival.growth_percent if survival else 0.0
	
	# --- EL TRIPLE CHECK ---
	var has_level = current_lvl >= next_stage.required_level
	
	# Si tu recurso no tiene required_growth, asume 1.0 (100%) por seguridad
	var req_growth = next_stage.get("required_growth") if next_stage.get("required_growth") != null else 1.0
	var has_growth = current_growth >= req_growth
	
	var has_tag = true 
	if next_stage.special_requirement_tag != "":
		# has_tag = current_tags.has(next_stage.special_requirement_tag)
		pass

	# Solo evoluciona si CUMPLE TODO
	if has_level and has_growth and has_tag:
		evolve_to(next_index)
		
		# Vuelve a revisar por si de casualidad tiene los requisitos para la que sigue
		check_evolutions()

func evolve_to(index: int):
	current_stage_index = index
	var new_stage = available_stages[index]
	
	print("Evolucionando a etapa: ", new_stage.stage_name)
	
	for child in model_holder.get_children():
		model_holder.remove_child(child)
		child.queue_free()
		
	if new_stage.model_scene:
		var new_model = new_stage.model_scene.instantiate()
		model_holder.add_child(new_model)
		
	if ability_manager:
		for ability in new_stage.granted_abilities:
			if not ability in ability_manager.equipped_abilities:
				ability_manager.equipped_abilities.append(ability)
	
	if effect_manager:
		for immunity in new_stage.stage_immunities:
			if not immunity in effect_manager.immunities:
				effect_manager.immunities.append(immunity)
				
	var controller = get_parent()
	if "can_fly" in controller:
		controller.can_fly = new_stage.can_fly
	if "can_swim" in controller:
		controller.can_swim = new_stage.can_swim

func sync_stage_to_level(_current_level: int) -> void:
	# Ahora el sincronizador usa las mismas reglas estrictas
	if available_stages.is_empty(): return
	
	for i in range(available_stages.size()):
		var stage = available_stages[i]
		# Para sincronizar al cargar partida, asumimos que si ya lo pasó, tiene el nivel y crecimiento
		if level_manager.level >= stage.required_level:
			# Solo lo evolucionamos visualmente sin resetear el crecimiento actual del guardado
			if current_stage_index != i:
				evolve_to(i)

func _get_current_stage():
	if current_stage_index >= 0 and current_stage_index < available_stages.size():
		return available_stages[current_stage_index]
	return null
