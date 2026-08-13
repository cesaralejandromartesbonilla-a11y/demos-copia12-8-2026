extends Node
class_name GrowthStatScaler

@onready var level_manager = $"../LevelManager"
@onready var evo_manager = $"../EvolutionManager"
@onready var survival = $"../SurvivalManager"
var current_max_health: float
var current_damage: float
var current_speed: float
var current_max_energy: float


@export_group("Stats Iniciales (Bebé/Inicio de etapa)")
@export var start_health: float = 15.0
@export var start_damage: float = 2.0
@export var start_speed: float = 0.3
@export var start_energy: float = 20.0

@export_group("Stats Terminales (Adulto/Fin de etapa)")
@export var end_health: float = 50.0
@export var end_damage: float = 10.0
@export var end_speed: float = 1.0
@export var end_energy: float = 50.0

func _process(_delta: float) -> void:
	if not survival or not evo_manager: return
	
	var stage = _get_current_stage()
	if not stage: return

	var t = survival.growth_percent 
	
	# 1. CRECIMIENTO FÍSICO (Lee directamente del recurso .tres de la etapa actual)
	var base_hp = lerp(stage.start_health, stage.end_health, t)
	var base_dmg = lerp(stage.start_damage, stage.end_damage, t)
	var base_spd = lerp(stage.start_speed, stage.end_speed, t)
	var base_eng = lerp(stage.start_energy, stage.end_energy, t)

	# 2. NIVEL (Experiencia): Multiplicador
	var lvl_multiplier = 1.0
	if level_manager:
		lvl_multiplier = 1.0 + (level_manager.level * 0.05)

	# 3. STATS FINALES APLICADOS
	current_max_health = base_hp * lvl_multiplier
	current_damage = base_dmg * lvl_multiplier
	current_speed = base_spd * lvl_multiplier
	current_max_energy = base_eng * lvl_multiplier
	
	# Sincronizamos con el SurvivalManager
	survival.max_health = current_max_health
	survival.max_energy = current_max_energy

func _get_current_stage() -> EvolutionStage:
	if evo_manager.current_stage_index != -1 and evo_manager.available_stages.size() > 0:
		return evo_manager.available_stages[evo_manager.current_stage_index]
	return null
