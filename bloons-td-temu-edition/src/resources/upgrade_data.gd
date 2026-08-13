class_name UpgradeData
extends Resource

@export var upgrade_name: String = ""
@export var description: String = ""
@export var cost: int = 100
@export var icon: Texture2D

@export_group("Stat Modifiers")
@export var cooldown_multiplier: float = 1.0
@export var range_bonus: float = 0.0
@export var damage_bonus: int = 0
@export var pierce_bonus: int = 0
@export var grant_camo: bool = false
@export var change_damage_type: GameEnums.DamageType = GameEnums.DamageType.SHARP
# Opcional: cambiar la escena del proyectil al comprar esta mejora
@export var projectile_scene_override: PackedScene = null
@export var secondary_projectile_scene: PackedScene = null
@export var disable_radial_shooting: bool = false
@export var is_hitscan: bool = false

@export_group("Special Mechanics")
# Críticos: probabilidad de golpe crítico (0.0 = ninguno, 1.0 = siempre)
@export var crit_chance: float = 0.0
# Multiplicador de daño en críticos
@export var crit_multiplier: float = 3.0
# Disparo múltiple: número de proyectiles extra en arco
@export var extra_projectiles: int = 0
# Ángulo total del arco de disparo múltiple (grados)
@export var spread_angle: float = 30.0
# Bonus de daño exclusivo contra MOAB-class (blimp)
@export var moab_damage_bonus: int = 0
# Fragmentación: al expirar el proyectil, lanza N sub-proyectiles
@export var splits_on_expire: bool = false
@export var split_count: int = 6
@export var stun_duration: float = 0.0
@export var extra_gold_per_attack: int = 0
@export var is_seeking: bool = false
@export var bounce_count: int = 0
@export var knockback_chance: float = 0.0
@export var drone_count_bonus: int = 0

@export_group("Farm Mechanics")
@export var gold_generation_bonus: int = 0
@export var end_of_wave_gold: int = 0
@export var end_of_wave_lives: int = 0
@export var is_bank: bool = false
@export var bank_capacity: int = 0
@export var bank_interest_rate: float = 0.15

# Habilidad activa (Rama 2)
@export var has_active_ability: bool = false
@export var ability_name: String = ""
@export var ability_description: String = ""
@export var ability_duration: float = 10.0
@export var ability_cooldown: float = 60.0
