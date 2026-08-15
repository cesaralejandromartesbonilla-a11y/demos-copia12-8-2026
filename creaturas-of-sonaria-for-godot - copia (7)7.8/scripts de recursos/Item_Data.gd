extends Resource
class_name ItemData

@export_group("Datos Básicos")
@export var slot_cost: int = 1 
@export var weight_kg: float = 1.0 
@export var item_name: String = "Item"
@export var item_mesh: Mesh
@export var is_edible: bool = false
@export var item_category: String = "planta"
@export var nutrition_value: float = 10.0
@export var item_groups: Array[String] = []

@export_group("Módulo Agrícola")
@export var seed_data: SeedData
@export var compost_value: float = 0.0

@export_group("Herramientas y Acciones")
@export var is_tool: bool = false
@export var can_till_soil: bool = false
@export var is_fire_starter: bool = false # Para quemar el trigo/limpiar parcelas
@export var is_pest_killer: bool = false # Para eliminar plagas

@export_group("Contenedores")
@export var is_container: bool = false
@export var gather_liquid_group: String = "agua"
@export var filled_result_data: ItemData

@export_group("Suministros Agrícolas")
@export var is_fertilizer: bool = false
@export var is_organic_matter: bool = false # Para los hongos
