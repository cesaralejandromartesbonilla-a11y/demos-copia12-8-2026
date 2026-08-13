class_name ProjectileBase
extends Area2D

@export var speed: float = 600.0

var direction: Vector2 = Vector2.ZERO
var damage: int = 1
var pierce: int = 1
var my_scene_id: String = ""
var damage_type: GameEnums.DamageType = GameEnums.DamageType.SHARP
var hit_bloon_ids: Dictionary = {} # Previene impactos duplicados en 1 mismo frame
var _stun_duration: float = 0.0
var _is_seeking: bool = false
var _bounce_count: int = 0
var _knockback_chance: float = 0.0

var _will_split: bool = false
var _split_count: int = 0
var _split_scene: PackedScene = null

func _ready() -> void:
	collision_layer = 4 # Layer 3: projectiles (bit 4)
	collision_mask = 2  # Layer 2: bloons (bit 2)
	monitoring = true
	monitorable = true

func setup(dir: Vector2, dmg: int, prc: int, scene_id: String, dmg_type: GameEnums.DamageType = GameEnums.DamageType.SHARP) -> void:
	direction = dir
	damage = dmg
	pierce = prc
	my_scene_id = scene_id
	damage_type = dmg_type
	rotation = direction.angle()
	hit_bloon_ids.clear()
	_stun_duration = 0.0
	_is_seeking = false
	_bounce_count = 0
	_knockback_chance = 0.0
	_will_split = false
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)

func setup_advanced(dir: Vector2, dmg: int, prc: int, scene_id: String, dmg_type: GameEnums.DamageType, stun_dur: float, seek: bool = false, bounce: int = 0, knockback: float = 0.0) -> void:
	setup(dir, dmg, prc, scene_id, dmg_type)
	_stun_duration = stun_dur
	_is_seeking = seek
	_bounce_count = bounce
	_knockback_chance = knockback

func enable_split(count: int, scene: PackedScene) -> void:
	_will_split = true
	_split_count = count
	_split_scene = scene

func _physics_process(delta: float) -> void:
	var start_pos = global_position
	var move_vec = direction * speed * delta
	var target_pos = start_pos + move_vec
	
	# Raycast de seguridad en la trayectoria para proyectiles ultra-rápidos (Anti-tunneling)
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(start_pos, target_pos, 2) # Layer 2: bloons
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var ray_result = space_state.intersect_ray(query)
	if not ray_result.is_empty():
		var hit_area = ray_result.collider
		if hit_area is Area2D:
			_handle_impact(hit_area)
			
	if _is_seeking:
		var target = _find_closest_bloon()
		if target:
			var target_dir = (target.global_position - global_position).normalized()
			direction = direction.lerp(target_dir, 5.0 * delta).normalized()
			rotation = direction.angle()
			
	global_position = target_pos
	
	# Chequeo complementario de solapamiento
	if monitoring:
		var overlapping = get_overlapping_areas()
		for area in overlapping:
			if pierce <= 0:
				break
			_handle_impact(area)

func _on_area_entered(area: Area2D) -> void:
	_handle_impact(area)

func _handle_impact(area: Area2D) -> void:
	if pierce <= 0 or not area or not is_instance_valid(area):
		return
		
	var bloon_node = area.get_parent() if area.get_parent() is BloonBase else area
	if not bloon_node or not is_instance_valid(bloon_node):
		return
		
	var instance_id = bloon_node.get_instance_id()
	if hit_bloon_ids.has(instance_id):
		return # Ya dañó a este globo en esta trayectoria
		
	if bloon_node is BloonBase or bloon_node.is_in_group("enemigo"):
		hit_bloon_ids[instance_id] = true
		if bloon_node.has_method("take_damage"):
			bloon_node.take_damage(damage)
			
		if _stun_duration > 0.0 and bloon_node.has_method("stun"):
			bloon_node.stun(_stun_duration)
			
		if _knockback_chance > 0.0 and randf() <= _knockback_chance and bloon_node.has_method("knockback"):
			bloon_node.knockback(50.0) # Distancia de retroceso
			
		pierce -= 1
		
		if pierce > 0 and _bounce_count > 0:
			_bounce_count -= 1
			var bounce_target = _find_closest_bloon([bloon_node])
			if bounce_target:
				direction = (bounce_target.global_position - global_position).normalized()
				rotation = direction.angle()
		elif pierce <= 0:
			_destroy_projectile()

func _destroy_projectile() -> void:
	set_deferred("monitoring", false)
	if _will_split and _split_scene:
		_do_split()
	PoolManager.return_instance(self, my_scene_id)

func _do_split() -> void:
	if not _split_scene or _split_count <= 0:
		return
	var angle_step = 360.0 / _split_count
	var dmg = max(1, int(damage / 2))
	for i in range(_split_count):
		var angle = deg_to_rad(angle_step * i)
		var dir = Vector2.UP.rotated(angle)
		var frag = PoolManager.get_instance(_split_scene)
		if frag.get_parent() != get_parent():
			if frag.get_parent():
				frag.get_parent().remove_child(frag)
			get_parent().add_child(frag)
		frag.global_position = global_position
		if frag.has_method("setup"):
			frag.setup(dir, dmg, 1, _split_scene.resource_path, damage_type)
	_will_split = false

func _find_closest_bloon(exclude_bloons: Array = []) -> BloonBase:
	var bloons = get_tree().get_nodes_in_group("enemigo")
	var closest: BloonBase = null
	var min_dist = 400.0 # Rango máximo de búsqueda para seeking/bouncing
	for node in bloons:
		var b = node as BloonBase
		if b and is_instance_valid(b) and not exclude_bloons.has(b):
			if hit_bloon_ids.has(b.get_instance_id()): continue
			var d = global_position.distance_to(b.global_position)
			if d < min_dist:
				min_dist = d
				closest = b
	return closest
