class_name HitscanProjectile
extends ProjectileBase

var target_bloon: BloonBase = null
var _time_alive: float = 0.0

func setup_hitscan(tgt: BloonBase, dmg: int, prc: int, scene_id: String, dmg_type: GameEnums.DamageType = GameEnums.DamageType.SHARP, stun_dur: float = 0.0) -> void:
	# Direction doesn't matter much for hitscan, but we pass it anyway
	if tgt and is_instance_valid(tgt):
		var dir = (tgt.global_position - global_position).normalized()
		super.setup(dir, dmg, prc, scene_id, dmg_type)
		target_bloon = tgt
		_stun_duration = stun_dur
		
		# Inmediatamente aplicar el daño
		if target_bloon.has_node("Hitbox"):
			var hitbox = target_bloon.get_node("Hitbox") as Area2D
			if hitbox:
				_handle_impact(hitbox)
		
		# Rotar para que el efecto visual (si hay) apunte al objetivo
		rotation = dir.angle()
		
		# Desactivar monitoring para no dañar áreas en el camino
		set_deferred("monitoring", false)
	else:
		super.setup(Vector2.RIGHT, dmg, prc, scene_id, dmg_type)
		PoolManager.return_instance(self, my_scene_id)

func _physics_process(delta: float) -> void:
	# Solo efecto visual rápido (ej: destello que dura 0.05s)
	_time_alive += delta
	if _time_alive > 0.05:
		PoolManager.return_instance(self, my_scene_id)

func _handle_impact(area: Area2D) -> void:
	super._handle_impact(area)
	if _stun_duration > 0.0:
		var bloon_node = area.get_parent() if area.get_parent() is BloonBase else area
		if bloon_node and is_instance_valid(bloon_node) and bloon_node.has_method("stun"):
			bloon_node.stun(_stun_duration)
			
	if _will_split and _split_scene:
		_do_split()

func enable_split(count: int, scene: PackedScene) -> void:
	_will_split = true
	_split_count = count
	_split_scene = scene

func _do_split() -> void:
	if not _split_scene or _split_count <= 0:
		return
		
	var angle_step = 360.0 / _split_count
	var dmg = max(1, int(damage / 2)) # Fragmentos hacen la mitad del daño
	
	for i in range(_split_count):
		var angle = deg_to_rad(angle_step * i)
		var dir = Vector2.UP.rotated(angle)
		
		# Usamos un proyectil normal para los fragmentos
		var frag = PoolManager.get_instance(_split_scene)
		if frag.get_parent() != get_parent():
			if frag.get_parent():
				frag.get_parent().remove_child(frag)
			get_parent().add_child(frag)
		
		frag.global_position = target_bloon.global_position if target_bloon else global_position
		
		if frag.has_method("setup"):
			frag.setup(dir, dmg, 1, _split_scene.resource_path, damage_type)
			
	_will_split = false # Solo una vez
