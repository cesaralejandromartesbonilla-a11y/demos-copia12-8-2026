class_name TowerData
extends Resource

@export var tower_id: String = ""
@export var cost: int = 200
@export var range_radius: float = 150.0
@export var attack_cooldown: float = 1.0
@export var damage: int = 1
@export var pierce: int = 1
@export var tower_texture: Texture2D
@export var projectile_scene: PackedScene
@export var damage_type: GameEnums.DamageType = GameEnums.DamageType.SHARP
@export var is_radial_shooter: bool = false
@export var is_hitscan: bool = false
@export var is_farm: bool = false
@export var base_gold_generation: int = 0
@export var allowed_terrain: GameEnums.PlacementType = GameEnums.PlacementType.STANDARD
@export var can_see_camo: bool = false

@export_group("Upgrade Paths")
@export var path_1_upgrades: Array[UpgradeData] = []
@export var path_2_upgrades: Array[UpgradeData] = []
@export var path_3_upgrades: Array[UpgradeData] = []
