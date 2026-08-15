class_name MapDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var unlock_cost: int = 0
@export var available: bool = true

@export_group("Terreno")
@export var base_height: float = 220.0
@export var difficulty_ramp_distance: float = 9000.0
@export var ground_color: Color = Color(0.35, 0.55, 0.22)
@export var sky_color: Color = Color(0.55, 0.78, 0.98)
@export var hills_far_color: Color = Color(0.42, 0.64, 0.38)
@export var hills_near_color: Color = Color(0.48, 0.7, 0.42)

@export_group("Mecánicas")
@export var mechanic_tags: PackedStringArray = PackedStringArray(["default"])
