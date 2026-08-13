class_name RockProjectile
extends ProjectileBase

# Roca que viaja más lento, tiene más alcance y puede fragmentarse al expirar
@export var max_range: float = 500.0
@export var rock_speed: float = 280.0

var _travel_distance: float = 0.0
var _split_enabled: bool = false

func _ready() -> void:
	super._ready()
	speed = rock_speed

func setup(dir: Vector2, dmg: int, prc: int, scene_id: String, dmg_type: GameEnums.DamageType = GameEnums.DamageType.SHARP) -> void:
	super.setup(dir, dmg, prc, scene_id, dmg_type)
	_travel_distance = 0.0
	# Las rocas no rotan con la dirección — ruedan
	rotation = 0.0

func enable_split(count: int, scene: PackedScene) -> void:
	_split_enabled = true
	_split_count = count
	_split_scene = scene

func _physics_process(delta: float) -> void:
	# Rotación visual de la roca (rueda)
	rotation += delta * 6.0
	
	var move_dist = speed * delta
	_travel_distance += move_dist
	
	var start_pos = global_position
	var move_vec = direction * move_dist
	var target_pos = start_pos + move_vec
	
	# Raycast anti-tunneling (igual que ProjectileBase)
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(start_pos, target_pos, 2)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var ray_result = space_state.intersect_ray(query)
	if not ray_result.is_empty():
		var hit_area = ray_result.collider
		if hit_area is Area2D:
			_handle_impact(hit_area)
	
	global_position = target_pos
	
	if monitoring:
		var overlapping = get_overlapping_areas()
		for area in overlapping:
			if pierce <= 0:
				break
			_handle_impact(area)
	
	# Expirar por distancia máxima
	if _travel_distance >= max_range:
		_expire()

func _expire() -> void:
	if _split_enabled and _split_scene and get_parent():
		var angles = []
		for i in range(_split_count):
			angles.append(deg_to_rad((360.0 / _split_count) * i))
		
		for angle in angles:
			var sub = PoolManager.get_instance(_split_scene)
			if sub.get_parent():
				sub.get_parent().remove_child(sub)
			get_parent().add_child(sub)
			sub.global_position = global_position
			var sub_dir = Vector2.RIGHT.rotated(angle)
			if sub.has_method("setup"):
				sub.setup(sub_dir, max(1, damage / 2), max(1, pierce), _split_scene.resource_path, damage_type)
	
	set_deferred("monitoring", false)
	PoolManager.return_instance(self, my_scene_id)
