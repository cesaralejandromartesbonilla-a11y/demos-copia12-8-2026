extends Resource
class_name CreatureDNA

@export var species_name: String = "Nueva Especie"

@export_group("Superficie")
@export var skin_color: Color = Color.WHITE
@export var baked_texture: Texture2D

@export_group("Morfología (BlendShapes)")
@export var morphology: Dictionary = {
	"musculoso": 0.0,
	"gordo": 0.0,
	"cuello_largo": 0.0
}

@export_group("Datos del Chasis Base")
@export var chassis_scene: PackedScene 
@export var is_humanoid: bool = true
@export var base_capacity: int = 4
@export var has_internal_inventory: bool = false
@export var base_jump_velocity: float = 4.5

@export_group("Piezas Ensambladas")
@export var attached_parts: Array = []

# Variables de juego (no se exportan, se calculan en memoria)
var total_weight: float = 0.0
var fire_resistance: float = 0.0
var total_speed: float = 10.0 # Velocidad base

# Llama a esta función cada vez que el jugador termine de editar la criatura
func recalculate_stats() -> void:
	total_weight = 0.0
	fire_resistance = (1.0 - skin_color.v) * 50.0 
	
	total_weight += morphology.get("gordo", 0.0) * 20.0
	total_weight += morphology.get("musculoso", 0.0) * 15.0
	
	# Modificamos este bucle para leer correctamente el diccionario de anclaje
	for slot_info in attached_parts:
		if slot_info and slot_info.has("part_data"):
			var part = slot_info["part_data"]
			if part:
				total_weight += part.weight
				fire_resistance += part.fire_resistance_mod
				total_speed += part.speed_mod
				
	total_speed = max(1.0, 10.0 + total_speed - (total_weight * 0.1))
