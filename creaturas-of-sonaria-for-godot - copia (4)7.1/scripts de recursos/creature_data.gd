extends Resource
class_name CreatureData

# Definimos los tipos de dieta disponibles
enum DietType { HERBIVORE, CARNIVORE, OMNIVORE }

@export_group("Información Básica")
@export var creature_name: String = "Nueva Criatura"
@export var description: String = "Una criatura misteriosa."
@export var icon: Texture2D
@export var evolution_stages: Array[EvolutionStage] = []
@export var stage_name: String = "Criatura Desconocida"

@export_group("Escena 3D")
@export_file("*.tscn") var creature_scene_path: String

@export_group("Resistencia Térmica")
@export var heat_insulation: float = 1.0  # 1.0 es normal, 5.0 es mucha resistencia
@export var cold_insulation: float = 1.0
@export var recovery_speed: float = 1.0   # 1.0 es normal, 0.2 es lento (reptil)

@export_group("Estadísticas Base")
@export var diet: DietType = DietType.OMNIVORE
@export var max_hunger: float = 100.0
@export var max_thirst: float = 100.0
@export var growth_speed: float = 0.01
@export var base_speed: float = 5.0
@export var price: int = 50 
@export var max_health: float = 100.0
@export var max_energy: float = 100.0

@export_group("Stats Actuales (Guardado)")
@export var current_health: float = -1.0 # -1 significa "nuevo, no cargado"
@export var current_hunger: float = 100.0
@export var current_thirst: float = 100.0
@export var current_energy: float = 100.0
@export var growth_percent: float = 0.0
