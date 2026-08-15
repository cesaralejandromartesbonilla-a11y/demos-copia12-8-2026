extends Resource
class_name CreaturePartData

enum SlotType { PIES, MANOS, EXTENSIONES, CHASIS, TORSOS, CADERAS, CABEZAS, DECORACIONES }

@export var id: String = ""
@export var display_name: String = ""
@export var slot_type: SlotType = SlotType.MANOS
# El puntero a la micro-escena 3D de la pieza
@export var part_scene: PackedScene
@export_group("Estadísticas Aportadas")
@export var weight: float = 0.0
@export var fire_resistance_mod: float = 0.0
@export var speed_mod: float = 0.0
