class_name TowerManager
extends Node2D

var placing_tower_data: TowerData = null
var ghost_sprite: Sprite2D = null
var ghost_area: Area2D = null

const DART_MONKEY_SCENE: String = "res://scenes/entities/towers/tower_dart_monkey.tscn"

func _ready() -> void:
	GameEvents.request_tower_placement.connect(_start_placement)

func _start_placement(tower_data: TowerData) -> void:
	placing_tower_data = tower_data
	
	if ghost_sprite:
		_cancel_placement()
		
	ghost_sprite = Sprite2D.new()
	ghost_sprite.texture = tower_data.tower_texture
	add_child(ghost_sprite)
	
	ghost_area = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 20.0
	collision.shape = shape
	ghost_area.add_child(collision)
	ghost_sprite.add_child(ghost_area)

func _process(_delta: float) -> void:
	if ghost_sprite:
		ghost_sprite.global_position = get_global_mouse_position()
		
		if _is_placement_valid():
			ghost_sprite.modulate = Color(1, 1, 1, 0.5)
		else:
			ghost_sprite.modulate = Color(1, 0, 0, 0.5)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if placing_tower_data:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if _is_placement_valid():
					_place_tower(get_global_mouse_position())
				else:
					print("Invalid tower placement position.")
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_cancel_placement()
		else:
			if event.button_index == MOUSE_BUTTON_LEFT:
				GameEvents.tower_deselected.emit()

func _is_placement_valid() -> bool:
	if not ghost_area or placing_tower_data == null:
		return false
		
	var overlapping_areas = ghost_area.get_overlapping_areas()
	var is_touching_path: bool = false
	var is_touching_water: bool = false
	var is_touching_land: bool = false
	
	for area in overlapping_areas:
		if area.is_in_group("torre") or area.is_in_group("no_apto"):
			return false 
			
		if area.is_in_group("camino"):
			is_touching_path = true
			
		if area.is_in_group("agua"):
			is_touching_water = true
			
		if area.is_in_group("terreno"):
			is_touching_land = true
			
	match placing_tower_data.allowed_terrain:
		GameEnums.PlacementType.STANDARD: # Suelo normal (NO path, NO water)
			if is_touching_path or is_touching_water: return false
			
		GameEnums.PlacementType.PATH: # Solo en camino
			if not is_touching_path: return false
			
		GameEnums.PlacementType.WATER: # Solo en agua
			if is_touching_path or not is_touching_water or is_touching_land: return false
			
	return true

func _place_tower(pos: Vector2) -> void:
	var tower_scene = load(DART_MONKEY_SCENE)
	var new_tower = tower_scene.instantiate()
	get_parent().add_child(new_tower)
	new_tower.global_position = pos
	if new_tower.has_method("setup"):
		new_tower.setup(placing_tower_data)
		
	GameEvents.tower_placed.emit(placing_tower_data)
	_cancel_placement()

func _cancel_placement() -> void:
	placing_tower_data = null
	if ghost_sprite:
		ghost_sprite.queue_free()
		ghost_sprite = null
		ghost_area = null
