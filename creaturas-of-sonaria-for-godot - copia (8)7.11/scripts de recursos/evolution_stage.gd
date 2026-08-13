extends Resource
class_name EvolutionStage

@export_group("Datos de la Etapa")
@export var stage_name: String = "Bebé"
@export var model_scene: PackedScene 

@export_group("Combate Cuerpo a Cuerpo")
@export var bite_damage: float = 15.0
@export var bite_cooldown: float = 1.0
@export var bite_effect: Resource 

@export_group("Requisitos para Evolucionar")
@export var required_level: int = 1
@export var required_age_minutes: float = 0.0
@export var special_requirement_tag: String = "" 
@export var required_growth: float = 0.3

@export_group("Capacidades Desbloqueadas")
@export var granted_abilities: Array[PackedScene] = [] 
@export var can_swim: bool = false
@export var can_fly: bool = false
@export var stage_immunities: Array[String] = [] 
@export var can_farm: bool = false 

# NUEVO: Array de planos que esta etapa puede construir
@export var unlocked_blueprints: Array[BlueprintData] = []

@export_group("Escalado de Stats de la Etapa")
@export var start_health: float = 15.0
@export var end_health: float = 50.0
@export var start_damage: float = 2.0
@export var end_damage: float = 10.0
@export var start_speed: float = 0.3
@export var end_speed: float = 1.0
@export var start_energy: float = 20.0
@export var end_energy: float = 50.0
