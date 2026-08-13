class_name RingOfFireProjectile
extends ProjectileBase

@export var max_duration: float = 0.5
@export var max_scale: float = 3.0

var _lifetime: float = 0.0

func setup(dir: Vector2, dmg: int, prc: int, scene_id: String, dmg_type: GameEnums.DamageType = GameEnums.DamageType.FIRE) -> void:
	super.setup(dir, dmg, prc, scene_id, dmg_type)
	_lifetime = 0.0
	speed = 0.0 # No se mueve
	scale = Vector2.ZERO

func _physics_process(delta: float) -> void:
	_lifetime += delta
	
	# Efecto de explosión rápida
	var progress = _lifetime / max_duration
	if progress < 0.2:
		scale = Vector2.ONE * (progress / 0.2) * max_scale
	else:
		var fade = 1.0 - ((progress - 0.2) / 0.8)
		modulate.a = fade
	
	# Chequeo de impacto a todos los globos solapados
	if monitoring:
		var overlapping = get_overlapping_areas()
		for area in overlapping:
			if pierce <= 0:
				break
			_handle_impact(area)
			
	if _lifetime >= max_duration:
		set_deferred("monitoring", false)
		PoolManager.return_instance(self, my_scene_id)
