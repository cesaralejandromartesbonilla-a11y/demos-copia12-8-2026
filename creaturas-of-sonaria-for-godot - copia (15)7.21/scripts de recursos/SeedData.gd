extends Resource
class_name SeedData

enum CropType { FUNGUS, SINGLE_HARVEST, PERENNIAL, AQUATIC }
enum TerrainRequired { DIRT, NORMAL_PLOT, LARGE_PLOT }

@export_group("Datos de Cosecha")
@export var result_item_data: ItemData
@export var secondary_result_data: ItemData
@export var drop_amount: int = 1
@export var visual_data: CropVisualData

@export_group("Requisitos de Cultivo")
@export var crop_type: CropType = CropType.SINGLE_HARVEST
@export var required_terrain: TerrainRequired = TerrainRequired.NORMAL_PLOT
@export var water_needed: float = 100.0
@export var organic_matter_needed: float = 100.0
@export var requires_submerged: bool = false

@export_group("Ciclo de Vida")
@export var vulnerable_to_pests: bool = true
@export var is_perennial: bool = false
@export var leaves_trash_behind: bool = false 
@export var grow_time_ticks: float = 100.0
@export var retained_growth_ratio: float = 0.0
@export var energia_inicial: float = 20.0
