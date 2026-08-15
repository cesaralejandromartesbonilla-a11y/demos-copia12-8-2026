class_name TackProjectile
extends ProjectileBase

@export var max_range: float = 120.0

var _travel_distance: float = 0.0

func setup(dir: Vector2, dmg: int, prc: int, scene_id: String, dmg_type: GameEnums.DamageType = GameEnums.DamageType.SHARP) -> void:
	super.setup(dir, dmg, prc, scene_id, dmg_type)
	_travel_distance = 0.0

func _physics_process(delta: float) -> void:
	var move_dist = speed * delta
	_travel_distance += move_dist
	
	super._physics_process(delta)
	
	if _travel_distance >= max_range:
		set_deferred("monitoring", false)
		PoolManager.return_instance(self, my_scene_id)
