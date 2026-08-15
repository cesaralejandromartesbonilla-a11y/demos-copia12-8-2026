class_name TowerBase
extends Node2D

signal selected(tower: TowerBase)
signal upgraded(tower: TowerBase)

@export var data: TowerData
@export var targeting_mode: GameEnums.TargetingMode = GameEnums.TargetingMode.FIRST

@onready var attack_timer: Timer = $AttackTimer
@onready var range_area: Area2D = $RangeArea

var targets_in_range: Array[BloonBase] = []
var pops_count: int = 0
var selection_area: Area2D = null

# Sistema de mejoras (Tiers comprados por camino: [Path1, Path2, Path3])
var current_tiers: Array[int] = [0, 0, 0]

# Modificadores acumulados por mejoras
var extra_damage: int = 0
var extra_pierce: int = 0
var extra_range: float = 0.0
var cooldown_multiplier: float = 1.0
var can_see_camo_override: bool = false
var active_damage_type: GameEnums.DamageType = GameEnums.DamageType.SHARP

# Mecánicas especiales acumuladas
var crit_chance: float = 0.0
var crit_multiplier: float = 3.0
var extra_projectiles: int = 0
var spread_angle: float = 30.0
var moab_damage_bonus: int = 0
var splits_on_expire: bool = false
var split_count: int = 6
var stun_duration: float = 0.0
var extra_gold_per_attack: int = 0
var is_seeking: bool = false
var bounce_count: int = 0
var knockback_chance: float = 0.0

var gold_generation_bonus: int = 0
var end_of_wave_gold: int = 0
var end_of_wave_lives: int = 0
var is_bank: bool = false
var bank_capacity: int = 0
var current_bank_balance: float = 0.0
var bank_interest_rate: float = 0.0

var active_projectile_scene: PackedScene = null  # null = usar data.projectile_scene
var override_radial_shooting: bool = false
var secondary_projectile_scene: PackedScene = null
var current_rotation_angle: float = 0.0 # Usado para Maelstrom

# Drones orbitales (Portaaviones)
var drone_count: int = 0
var drones: Array[Node2D] = []
var drone_orbit_radius: float = 80.0
var drone_orbit_angle: float = 0.0
var drone_fire_timer: float = 0.0
var drone_fire_interval: float = 0.8

# Habilidad activa
var has_active_ability: bool = false
var ability_data: UpgradeData = null
var ability_cooldown_remaining: float = 0.0
var ability_active: bool = false

func _ready() -> void:
	if range_area:
		range_area.collision_layer = 8 # Layer 4: tower_range
		range_area.collision_mask = 2  # Layer 2: bloons
		if not range_area.area_entered.is_connected(_on_range_area_entered):
			range_area.area_entered.connect(_on_range_area_entered)
		if not range_area.area_exited.is_connected(_on_range_area_exited):
			range_area.area_exited.connect(_on_range_area_exited)
			
	if has_node("FootprintArea"):
		selection_area = $FootprintArea
		if not selection_area.input_event.is_connected(_on_footprint_input_event):
			selection_area.input_event.connect(_on_footprint_input_event)
			
	if data:
		active_damage_type = data.damage_type
		_apply_tower_data()

func _on_footprint_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(self)
		GameEvents.tower_selected.emit(self)

func _process(delta: float) -> void:
	# Actualizar cooldown de habilidad
	if has_active_ability:
		if ability_active:
			pass
		elif ability_cooldown_remaining > 0:
			ability_cooldown_remaining -= delta
			
	# Actualizar drones orbitales
	if drone_count > 0:
		drone_orbit_angle += delta * 1.5 # Velocidad de órbita
		for i in range(drones.size()):
			if drones[i] and is_instance_valid(drones[i]):
				var angle = drone_orbit_angle + (TAU / drones.size()) * i
				drones[i].global_position = global_position + Vector2(cos(angle), sin(angle)) * drone_orbit_radius
				drones[i].rotation = angle
		
		drone_fire_timer -= delta
		if drone_fire_timer <= 0:
			drone_fire_timer = drone_fire_interval
			_fire_drones()

func activate_ability() -> void:
	if not has_active_ability or not ability_data:
		return
	if ability_active or ability_cooldown_remaining > 0:
		return
	
	ability_active = true
	ability_cooldown_remaining = 0.0
	
	# Aplicar efecto: velocidad aumentada (factor 3x, no 10x para evitar lag)
	# Guardamos el cooldown ACTUAL ya calculado del timer para restaurar exacto
	var original_wait = attack_timer.wait_time
	var ability_wait = max(0.08, original_wait / 3.0)
	
	if "Maelstrom" in ability_data.ability_name:
		ability_wait = 0.05 # Disparo muy rápido para Maelstrom
	elif "Suministros" in ability_data.ability_name:
		if "Élite" in ability_data.ability_name:
			GameEvents.bloon_popped.emit(3000)
		else:
			GameEvents.bloon_popped.emit(1000)
		ability_wait = original_wait # No cambia la cadencia
	elif "Préstamo" in ability_data.ability_name:
		if "Gran" in ability_data.ability_name:
			GameEvents.bloon_popped.emit(25000)
		else:
			GameEvents.bloon_popped.emit(10000)
		ability_wait = original_wait # No cambia la cadencia
		
	attack_timer.wait_time = ability_wait
	
	GameEvents.ability_activated.emit(self, ability_data.ability_name)
	
	# Timer para terminar la habilidad (process_always para que funcione aunque no haya pausa)
	var timer = get_tree().create_timer(ability_data.ability_duration, true, false, true)
	timer.timeout.connect(func():
		ability_active = false
		if is_instance_valid(self) and attack_timer:
			attack_timer.wait_time = original_wait
			
		# Detener rotación si es Maelstrom
		if "Maelstrom" in ability_data.ability_name:
			rotation = 0.0
			
		ability_cooldown_remaining = ability_data.ability_cooldown
		GameEvents.ability_deactivated.emit(self)
	)

func setup(tower_data: TowerData) -> void:
	data = tower_data
	if data:
		active_damage_type = data.damage_type
	_apply_tower_data()

func can_buy_upgrade(path_index: int) -> bool:
	if not data or path_index < 0 or path_index > 2:
		return false
		
	var current_tier = current_tiers[path_index]
	var upgrades_list: Array[UpgradeData] = []
	match path_index:
		0: upgrades_list = data.path_1_upgrades
		1: upgrades_list = data.path_2_upgrades
		2: upgrades_list = data.path_3_upgrades
		
	if current_tier >= upgrades_list.size():
		return false
		
	# BTD6 Rules (5-2-0):
	# Max 1 path >= Tier 3
	# Max 1 other path >= Tier 1 (up to Tier 2)
	# Max 2 active paths
	
	var simulated_tiers = current_tiers.duplicate()
	simulated_tiers[path_index] += 1
	
	var paths_with_t3_plus = 0
	var paths_active = 0
	
	for tier in simulated_tiers:
		if tier > 0:
			paths_active += 1
		if tier >= 3:
			paths_with_t3_plus += 1
			
	if paths_with_t3_plus > 1:
		return false
	if paths_active > 2:
		return false
		
	return true

func get_next_upgrade(path_index: int) -> UpgradeData:
	if not data or path_index < 0 or path_index > 2:
		return null
	var current_tier = current_tiers[path_index]
	var upgrades_list: Array[UpgradeData] = []
	match path_index:
		0: upgrades_list = data.path_1_upgrades
		1: upgrades_list = data.path_2_upgrades
		2: upgrades_list = data.path_3_upgrades
	if current_tier < upgrades_list.size():
		return upgrades_list[current_tier]
	return null

func buy_upgrade(path_index: int) -> bool:
	if not can_buy_upgrade(path_index):
		return false
		
	var upgrade = get_next_upgrade(path_index)
	if not upgrade:
		return false
		
	var game_manager = get_tree().root.find_child("GameManager", true, false)
	if game_manager:
		if not game_manager.can_afford(upgrade.cost):
			return false
		game_manager.gold -= upgrade.cost
		game_manager.gold_changed.emit(game_manager.gold)
		
	current_tiers[path_index] += 1
	_apply_upgrade(upgrade)
	upgraded.emit(self)
	return true

func _apply_upgrade(upgrade: UpgradeData) -> void:
	if not upgrade:
		return
	cooldown_multiplier *= upgrade.cooldown_multiplier
	extra_range += upgrade.range_bonus
	extra_damage += upgrade.damage_bonus
	extra_pierce += upgrade.pierce_bonus
	if upgrade.grant_camo:
		can_see_camo_override = true
	active_damage_type = upgrade.change_damage_type
	
	# Mecánicas especiales
	if upgrade.crit_chance > 0:
		crit_chance = upgrade.crit_chance
		crit_multiplier = upgrade.crit_multiplier
	if upgrade.extra_projectiles > 0:
		extra_projectiles += upgrade.extra_projectiles
		spread_angle = upgrade.spread_angle
	if upgrade.moab_damage_bonus > 0:
		moab_damage_bonus += upgrade.moab_damage_bonus
	if upgrade.stun_duration > 0.0:
		stun_duration += upgrade.stun_duration
	if upgrade.splits_on_expire:
		splits_on_expire = true
		split_count = upgrade.split_count
	if upgrade.extra_gold_per_attack > 0:
		extra_gold_per_attack += upgrade.extra_gold_per_attack
	if upgrade.is_seeking:
		is_seeking = true
	if upgrade.bounce_count > 0:
		bounce_count += upgrade.bounce_count
	if upgrade.knockback_chance > 0.0:
		knockback_chance += upgrade.knockback_chance
	if upgrade.drone_count_bonus > 0:
		drone_count += upgrade.drone_count_bonus
		_spawn_drones(drone_count)
		
	# Farm Mechanics
	gold_generation_bonus += upgrade.gold_generation_bonus
	end_of_wave_gold += upgrade.end_of_wave_gold
	end_of_wave_lives += upgrade.end_of_wave_lives
	if upgrade.is_bank:
		is_bank = true
		bank_capacity = upgrade.bank_capacity
		bank_interest_rate = upgrade.bank_interest_rate
		
	if upgrade.has_active_ability:
		has_active_ability = true
		ability_data = upgrade
		ability_cooldown_remaining = 0.0
	if upgrade.projectile_scene_override:
		active_projectile_scene = upgrade.projectile_scene_override
	if upgrade.disable_radial_shooting:
		override_radial_shooting = true
	
	_apply_tower_data()

func _apply_tower_data() -> void:
	if not data:
		return
		
	if has_node("Sprite2D") and data.tower_texture:
		$Sprite2D.texture = data.tower_texture
		
	if attack_timer:
		var base_wait = data.attack_cooldown * cooldown_multiplier
		# Mínimo de 0.08s para evitar lag con demasiados proyectiles
		attack_timer.wait_time = max(0.08, base_wait)
		if attack_timer.is_stopped():
			attack_timer.start()
			
	if range_area and range_area.has_node("CollisionShape2D"):
		var shape_owner: CollisionShape2D = range_area.get_node("CollisionShape2D")
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = data.range_radius + extra_range
		shape_owner.shape = circle_shape
		
		# Optimización: Si el rango es global, no usamos físicas para detectar
		if data.range_radius + extra_range >= 2000.0:
			range_area.monitoring = false
			range_area.monitorable = false
			
		# Si es granja, tampoco usamos físicas
		if data.is_farm:
			range_area.monitoring = false
			range_area.monitorable = false
			
	if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
		attack_timer.timeout.connect(_on_attack_timer_timeout)
	if not GameEvents.wave_finished.is_connected(_on_wave_finished):
		GameEvents.wave_finished.connect(_on_wave_finished)

func get_current_range() -> float:
	return (data.range_radius + extra_range) if data else 150.0

func _on_range_area_entered(area: Area2D) -> void:
	var bloon = area.get_parent() if area.get_parent() is BloonBase else area
	if bloon is BloonBase and not targets_in_range.has(bloon):
		targets_in_range.append(bloon)

func _on_range_area_exited(area: Area2D) -> void:
	var bloon = area.get_parent() if area.get_parent() is BloonBase else area
	if bloon is BloonBase and targets_in_range.has(bloon):
		targets_in_range.erase(bloon)

func _clean_targets_in_range() -> void:
	var valid_targets: Array[BloonBase] = []
	var can_detect_camo = (data.can_see_camo if data else false) or can_see_camo_override
	
	for bloon in targets_in_range:
		if is_instance_valid(bloon) and bloon.is_inside_tree():
			if bloon.is_camo and not can_detect_camo:
				continue
			valid_targets.append(bloon)
	targets_in_range = valid_targets

func get_target() -> BloonBase:
	if not data:
		return null
		
	# Optimización para torres de rango global (ej: Francotirador)
	if (data.range_radius + extra_range) >= 2000.0:
		var bloons = get_tree().get_nodes_in_group("enemigo")
		var best_target: BloonBase = null
		var max_progress: float = -1.0
		var can_detect_camo = (data.can_see_camo if data else false) or can_see_camo_override
		
		for node in bloons:
			var bloon = node as BloonBase
			if bloon and is_instance_valid(bloon):
				if bloon.is_camo and not can_detect_camo:
					continue
				if bloon.progress > max_progress:
					max_progress = bloon.progress
					best_target = bloon
		return best_target

	_clean_targets_in_range()
	
	if targets_in_range.is_empty():
		return null
		
	var chosen_target: BloonBase = null
	
	match targeting_mode:
		GameEnums.TargetingMode.FIRST:
			var max_progress: float = -1.0
			for bloon in targets_in_range:
				if bloon.progress > max_progress:
					max_progress = bloon.progress
					chosen_target = bloon
					
		GameEnums.TargetingMode.LAST:
			var min_progress: float = INF
			for bloon in targets_in_range:
				if bloon.progress < min_progress:
					min_progress = bloon.progress
					chosen_target = bloon
					
		GameEnums.TargetingMode.STRONG:
			var max_health: int = -1
			var max_progress: float = -1.0
			for bloon in targets_in_range:
				var hp = bloon.get_health()
				var prog = bloon.progress
				if hp > max_health or (hp == max_health and prog > max_progress):
					max_health = hp
					max_progress = prog
					chosen_target = bloon
					
		GameEnums.TargetingMode.CLOSE:
			var min_dist: float = INF
			for bloon in targets_in_range:
				var dist = global_position.distance_to(bloon.global_position)
				if dist < min_dist:
					min_dist = dist
					chosen_target = bloon
					
	return chosen_target

func _on_attack_timer_timeout() -> void:
	if not data:
		return
		
	if data.is_farm:
		if not is_bank:
			var gold_to_give = data.base_gold_generation + gold_generation_bonus
			if gold_to_give > 0:
				GameEvents.bloon_popped.emit(gold_to_give)
		return
		
	var target = get_target()
	
	if ability_active and ability_data and "Maelstrom" in ability_data.ability_name:
		# Maelstrom: dispara 8 sierras girando
		current_rotation_angle += deg_to_rad(15.0)
		rotation = current_rotation_angle
		_shoot_maelstrom()
		return
		
	if target and is_instance_valid(target):
		if data and not (data.is_radial_shooter and not override_radial_shooting):
			look_at(target.global_position)
		_shoot(target)

func _shoot(target: BloonBase) -> void:
	if not data or not data.projectile_scene:
		return
	
	# Calcular daño base con críticos y bonus MOAB
	var final_damage = data.damage + extra_damage
	var is_moab_class = target.data and target.data.bloon_id == "moab"
	if is_moab_class:
		final_damage += moab_damage_bonus
	if crit_chance > 0.0 and randf() <= crit_chance:
		final_damage = int(final_damage * crit_multiplier)
	
	var final_pierce = data.pierce + extra_pierce
	var scene_path: String = data.projectile_scene.resource_path
	
	if extra_gold_per_attack > 0:
		GameEvents.bloon_popped.emit(extra_gold_per_attack)
	
	if data.is_radial_shooter and not override_radial_shooting:
		var total_projectiles = 8 + extra_projectiles
		var angle_step = 360.0 / total_projectiles
		for i in range(total_projectiles):
			var angle = deg_to_rad(angle_step * i)
			var spread_dir = Vector2.UP.rotated(angle)
			_fire_single_projectile(spread_dir, final_damage, final_pierce, scene_path)
	else:
		# Dirección principal
		var base_direction = (target.global_position - global_position).normalized()
		
		# Disparar proyectil principal (Si es Anillo de Fuego, solo lanza 1)
		_fire_single_projectile(base_direction, final_damage, final_pierce, scene_path, target)
		
		# Proyectiles extra en arco (Triple Darts, etc.) NO APLICA a Ring of Fire
		if extra_projectiles > 0 and not override_radial_shooting:
			var half_spread = spread_angle / 2.0
			var angle_step_val = spread_angle / float(extra_projectiles + 1)
			for i in range(extra_projectiles):
				var angle_offset = deg_to_rad(-half_spread + angle_step_val * (i + 1))
				var spread_dir = base_direction.rotated(angle_offset)
				_fire_single_projectile(spread_dir, final_damage, final_pierce, scene_path)
				
		# Proyectil Secundario (Ej: Meteoro del Inferno Ring)
		if secondary_projectile_scene:
			var sec_proj = PoolManager.get_instance(secondary_projectile_scene)
			if sec_proj.get_parent() != get_parent():
				if sec_proj.get_parent():
					sec_proj.get_parent().remove_child(sec_proj)
				get_parent().add_child(sec_proj)
			sec_proj.global_position = global_position
			if sec_proj.has_method("setup"):
				sec_proj.setup(base_direction, final_damage * 10, final_pierce, secondary_projectile_scene.resource_path, active_damage_type)

func _shoot_maelstrom() -> void:
	var final_damage = data.damage + extra_damage
	var final_pierce = data.pierce + extra_pierce + 10 # Las sierras de maelstrom atraviesan más
	var scene_path = data.projectile_scene.resource_path
	if active_projectile_scene:
		scene_path = active_projectile_scene.resource_path
		
	# Dispara en 8 direcciones desde la rotación actual
	for i in range(8):
		var angle = deg_to_rad(45.0 * i) + current_rotation_angle
		var spread_dir = Vector2.UP.rotated(angle)
		_fire_single_projectile(spread_dir, final_damage, final_pierce, scene_path)

func _fire_single_projectile(direction: Vector2, dmg: int, pierce: int, scene_path: String, target_override: BloonBase = null) -> void:
	var proj_scene = active_projectile_scene if active_projectile_scene else data.projectile_scene
	var projectile = PoolManager.get_instance(proj_scene)
	if projectile.get_parent() != get_parent():
		if projectile.get_parent():
			projectile.get_parent().remove_child(projectile)
		get_parent().add_child(projectile)
	projectile.global_position = global_position
	
	if data and data.is_hitscan and projectile.has_method("setup_hitscan"):
		projectile.setup_hitscan(target_override, dmg, pierce, scene_path, active_damage_type, stun_duration)
	elif projectile.has_method("setup"):
		if projectile.has_method("setup_advanced"):
			projectile.setup_advanced(direction, dmg, pierce, scene_path, active_damage_type, stun_duration, is_seeking, bounce_count, knockback_chance)
		else:
			projectile.setup(direction, dmg, pierce, scene_path, active_damage_type)
		
	# Pasar flag de fragmentación si aplica
	if splits_on_expire and projectile.has_method("enable_split"):
		projectile.enable_split(split_count, proj_scene)

func _on_wave_finished() -> void:
	# Granjas: entregar dinero y vidas
	if data and data.is_farm:
		if end_of_wave_gold > 0:
			GameEvents.bloon_popped.emit(end_of_wave_gold)
			
		if end_of_wave_lives > 0:
			var game_manager = get_tree().root.find_child("GameManager", true, false)
			if game_manager:
				game_manager.lives += end_of_wave_lives
				game_manager.lives_changed.emit(game_manager.lives)
				
		if is_bank:
			current_bank_balance += float(data.base_gold_generation + gold_generation_bonus) * 15.0
			if current_bank_balance > 0:
				current_bank_balance += current_bank_balance * bank_interest_rate
				
			if current_bank_balance >= float(bank_capacity):
				current_bank_balance = float(bank_capacity)
				
			if current_bank_balance > 0:
				GameEvents.bloon_popped.emit(int(current_bank_balance))
				current_bank_balance = 0.0
	else:
		# Torres no-granja con end_of_wave_gold (ej: Barco Mercante)
		if end_of_wave_gold > 0:
			GameEvents.bloon_popped.emit(end_of_wave_gold)

func _spawn_drones(count: int) -> void:
	# Limpiar drones anteriores
	for d in drones:
		if d and is_instance_valid(d):
			d.queue_free()
	drones.clear()
	drone_count = count
	
	for i in range(count):
		var drone = Sprite2D.new()
		# Representación visual simple: un cuadrado pequeño
		var img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.8, 0.9, 1.0, 1.0))
		drone.texture = ImageTexture.create_from_image(img)
		get_parent().add_child(drone)
		drones.append(drone)

func _fire_drones() -> void:
	if not data or not data.projectile_scene:
		return
	var scene_path = data.projectile_scene.resource_path
	var final_damage = data.damage + extra_damage
	var final_pierce = data.pierce + extra_pierce
	
	for drone in drones:
		if drone and is_instance_valid(drone):
			var target = get_target()
			if target:
				var dir = (target.global_position - drone.global_position).normalized()
				var proj_scene = active_projectile_scene if active_projectile_scene else data.projectile_scene
				var projectile = PoolManager.get_instance(proj_scene)
				if projectile.get_parent() != get_parent():
					if projectile.get_parent():
						projectile.get_parent().remove_child(projectile)
					get_parent().add_child(projectile)
				projectile.global_position = drone.global_position
				if projectile.has_method("setup"):
					projectile.setup(dir, final_damage, final_pierce, scene_path, active_damage_type)
