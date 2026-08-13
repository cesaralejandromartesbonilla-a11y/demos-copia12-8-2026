extends Area3D
class_name TornadoEntity

# --- ASIGNA ESTO EN EL EDITOR ---
@export var tornado_mesh: MeshInstance3D 
@export var base_color: Color = Color(1.0, 1.0, 1.0, 0.5) 

@export_group("Configuración por Biomas")
@export var arctic_color: Color = Color(0.8, 0.9, 1.0, 0.7)
# ¡SOLUCIÓN ERROR! Ahora exige estrictamente un StatusEffect (.tres), no aceptará escenas (.tscn)
@export var arctic_effect: StatusEffect 
@export var desert_color: Color = Color(0.9, 0.6, 0.2, 0.7)
@export var desert_effect: StatusEffect 
@export var ocean_color: Color = Color(0.0, 0.0, 1.0, 0.7)
@export var ocean_effect: StatusEffect 
@export var default_biome_effect: StatusEffect 
# --------------------------------

# Configuración de Movimiento
var category: int = 1
var move_direction: Vector3
var speed: float = 6.0
var rotation_speed: float = 5.0
var direction_timer: float = 0.0
var map_radius: float = 300.0

# Ciclo de Vida y Degradación
var age: float = 0.0
@export var max_lifetime: float = 300.0 
var is_degrading: bool = false
var degradation_interval: float = 2.0 
var degradation_timer: float = 0.0

# Sistema de Buffer de Habilidades
var absorbed_effects: Dictionary = {} 
var discharge_interval: float = 1.0 / 60.0 
var discharge_timer: float = 0.0
var effect_duration: float = 60.0

# Entorno y Color actual
var current_biome: String = "vacio"
var active_biome_effect: StatusEffect = null
var biome_check_timer: float = 0.0
var current_tornado_color: Color # Variable para rastrear el color actual y poder robarlo en fusiones

func _ready():
	_pick_erratic_direction()
	add_to_group("weather_entity")
	add_to_group("tornado")
	
	_change_tornado_color(base_color)
	_update_visual_scale()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float):
	global_position += move_direction * speed * delta
	rotate_y(rotation_speed * delta) 
	
	direction_timer += delta
	if direction_timer >= 15.0: 
		direction_timer = 0.0
		_pick_erratic_direction()
		
	biome_check_timer += delta
	if biome_check_timer >= 0.5:
		biome_check_timer = 0.0
		_update_current_biome()
	
	age += delta
	if age >= max_lifetime:
		is_degrading = true
		degradation_timer += delta
		if degradation_timer >= degradation_interval:
			degradation_timer = 0.0
			category -= 1
			if category <= 0:
				queue_free() 
			else:
				_update_visual_scale() 
	
	_process_effects_timers(delta)
	
	if not absorbed_effects.is_empty():
		discharge_timer += delta
		if discharge_timer >= discharge_interval:
			discharge_timer = 0.0
			_shoot_all_absorbed_elements()
			
	_check_boundaries(delta)

func _update_current_biome():
	var areas = get_overlapping_areas()
	var found_biome = "vacio"
	
	for area in areas:
		if area.is_in_group("bioma_desierto"): found_biome = "desierto"; break
		elif area.is_in_group("bioma_artico"): found_biome = "artico"; break
		elif area.is_in_group("bioma_pradera"): found_biome = "pradera"; break
		elif area.is_in_group("bioma_oceano"): found_biome = "oceano"; break
		elif area.is_in_group("bioma_lago"): found_biome = "lago"; break
			
	if current_biome != found_biome:
		current_biome = found_biome
		_apply_biome_properties()

func _apply_biome_properties():
	var can_change_color = absorbed_effects.is_empty()
	
	match current_biome:
		"artico":
			if can_change_color: _change_tornado_color(arctic_color)
			active_biome_effect = arctic_effect
		"desierto":
			if can_change_color: _change_tornado_color(desert_color)
			active_biome_effect = desert_effect
		"oceano":
			if can_change_color: _change_tornado_color(ocean_color)
			active_biome_effect = ocean_effect
		_:
			if can_change_color: _change_tornado_color(base_color)
			active_biome_effect = default_biome_effect

func _on_body_entered(body: Node3D):
	if active_biome_effect:
		if body.has_method("apply_status_effect"):
			body.apply_status_effect(active_biome_effect)
		elif body.get_parent() and body.get_parent().has_method("apply_status_effect"):
			body.get_parent().apply_status_effect(active_biome_effect)

func _pick_erratic_direction():
	move_direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	speed = randf_range(5.0, 8.0)

func _process_effects_timers(delta: float):
	var keys_to_remove = []
	var was_empty_before = absorbed_effects.is_empty()
	
	for scene_path in absorbed_effects.keys():
		absorbed_effects[scene_path] -= delta
		if absorbed_effects[scene_path] <= 0:
			keys_to_remove.append(scene_path)
	
	for key in keys_to_remove:
		absorbed_effects.erase(key)
		
	if not was_empty_before and absorbed_effects.is_empty():
		_apply_biome_properties()

func _on_area_entered(area: Area3D):
	if area.is_in_group("ability_projectile"):
		var path = area.scene_file_path 
		if path != "":
			absorbed_effects[path] = effect_duration
			
			if "element_color" in area:
				_change_tornado_color(area.element_color)
				
		area.queue_free()
		
	elif area.is_in_group("tornado") and area is TornadoEntity:
		if age >= (max_lifetime - 2.0) or is_degrading:
			return
		if get_instance_id() < area.get_instance_id(): return 
		
		self.category += area.category
		_update_visual_scale()
		
		# ¡SOLUCIÓN FUSIÓN DE COLOR! Si el otro tornado tiene un color distinto al base, nos lo quedamos
		if area.current_tornado_color != area.base_color:
			_change_tornado_color(area.current_tornado_color)
		
		for other_path in area.absorbed_effects.keys():
			self.absorbed_effects[other_path] = effect_duration
			
		area.queue_free()

func _shoot_all_absorbed_elements():
	if is_degrading: return 

	for scene_path in absorbed_effects.keys():
		var effect_scene = load(scene_path)
		if effect_scene:
			var projectile = effect_scene.instantiate()
			projectile.position = self.global_position + Vector3(randf_range(-3, 3), randf_range(1, 6), randf_range(-3, 3))
			if "direction" in projectile:
				projectile.direction = Vector3(randf_range(-1, 1), randf_range(-0.2, 0.5), randf_range(-1, 1)).normalized()
			
			projectile.remove_from_group("ability_projectile")
			projectile.add_to_group("tornado_projectile") 
			
			get_tree().current_scene.add_child(projectile)
			
			if projectile.has_method("activate"):
				projectile.activate(self, projectile.direction)

func _update_visual_scale():
	var target_s = 1.0 + (category * 0.5)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(target_s, target_s * 1.5, target_s), 1.0)

func _check_boundaries(delta: float):
	var distance_from_center = global_position.distance_to(Vector3.ZERO)
	if distance_from_center > map_radius:
		var direction_to_center = (Vector3.ZERO - global_position).normalized()
		move_direction = move_direction.lerp(direction_to_center, delta * 0.5).normalized()

func _change_tornado_color(new_color: Color):
	current_tornado_color = new_color # Guardamos el color actual
	
	if tornado_mesh:
		if not tornado_mesh.material_override:
			tornado_mesh.material_override = StandardMaterial3D.new()
			tornado_mesh.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		
		var tween = create_tween()
		tween.tween_property(tornado_mesh.material_override, "albedo_color", new_color, 1.0)
