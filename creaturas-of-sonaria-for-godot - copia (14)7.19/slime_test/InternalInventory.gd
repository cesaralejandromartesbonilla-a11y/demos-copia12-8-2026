extends Node3D
class_name InternalInventory

signal inventory_changed(status_text: String)

@export var base_weight_capacity: float = 50.0

var stored_items: Array[ConsumableItem] = []
const BASE_RADIUS: float = 0.5 
var current_internal_radius: float = 0.5
var current_mass_level: float = 1.0
var last_global_pos: Vector3 = Vector3.ZERO

const INTERNAL_PHYSICS_LAYER: int = 512 

func _ready():
	last_global_pos = global_position

func _physics_process(delta: float) -> void:
	# 1. Calculamos exactamente cuánto se movió el jugador
	var current_global_pos = self.global_position
	var slime_movement_delta = current_global_pos - last_global_pos
	last_global_pos = current_global_pos
	var items_to_expel = []
	
	var escape_limit = current_internal_radius + 1.5 

	for item in stored_items:
		if is_instance_valid(item) and item is RigidBody3D:
			
			item.global_position += slime_movement_delta
			
			if item.linear_velocity.length() > 8.0:
				item.linear_velocity = item.linear_velocity.normalized() * 8.0
				
			var offset = item.global_position - current_global_pos
			var dist = offset.length()
			
			if dist > escape_limit:
				items_to_expel.append(item)
				continue
			
			var dir_to_center = -offset.normalized() if dist > 0.01 else Vector3.ZERO
			var spring_k = 25.0 
			
			if dist > current_internal_radius:
				spring_k = 80.0 
				item.linear_velocity = item.linear_velocity.lerp(Vector3.ZERO, delta * 15.0)
				
			var force = dir_to_center * (dist * spring_k) * item.mass
			item.apply_central_force(force)

	# Purga segura
	for item in items_to_expel:
		print("¡Objeto fugado por límite constante!: ", item.name)
		_expel_specific_item(item)

func try_absorb_item(item: ConsumableItem) -> bool:
	if _get_current_weight() + item.item_weight > get_dynamic_capacity():
		print("Masa saturada. No se puede absorber más.")
		return false
	_absorb_into_mass(item)
	return true

func _absorb_into_mass(item: ConsumableItem) -> void:
	var current_parent = item.get_parent()
	if current_parent: current_parent.remove_child(item)
		
	add_child(item)
	stored_items.append(item)
	
	# Guardamos propiedades originales
	item.set_meta("original_layer", item.collision_layer)
	item.set_meta("original_mask", item.collision_mask)
	item.set_meta("original_linear_damp", item.linear_damp)
	item.set_meta("original_angular_damp", item.angular_damp)
	item.collision_layer = INTERNAL_PHYSICS_LAYER
	item.collision_mask = INTERNAL_PHYSICS_LAYER
	item.freeze = false
	item.sleeping = false
	item.gravity_scale = 0.0 
	item.linear_damp = 12.0  
	item.angular_damp = 12.0
	item.top_level = true
	item.linear_velocity = Vector3.ZERO
	item.angular_velocity = Vector3.ZERO
	
	_scale_collision_shapes(item, 0.4)
	
	var random_offset = Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), randf_range(-0.1, 0.1))
	item.global_position = self.global_position + random_offset
	
	_update_ui()

func recalculate_internal_bounds(new_mass_level: float) -> void:
	current_mass_level = new_mass_level
	current_internal_radius = (BASE_RADIUS * new_mass_level) * 0.75
	_enforce_weight_limit()
	_update_ui()

func expel_last_item() -> void:
	if stored_items.size() > 0: _expel_specific_item(stored_items.back())

func expel_first_item() -> void:
	if stored_items.size() > 0: _expel_specific_item(stored_items.front())

func drop_all_items() -> void:
	for i in range(stored_items.size() - 1, -1, -1): _expel_specific_item(stored_items[i])

func _enforce_weight_limit() -> void:
	while _get_current_weight() > get_dynamic_capacity() and stored_items.size() > 0:
		expel_last_item()

func _expel_specific_item(item: ConsumableItem) -> void:
	if not item in stored_items: return
	
	stored_items.erase(item)
	var current_parent = item.get_parent()
	if current_parent: current_parent.remove_child(item)
		
	get_tree().current_scene.add_child(item)
	
	# Restauramos la física para que vuelva a la normalidad
	restore_item_physics(item)
	
	var player = get_parent() as Node3D
	var spawn_pos = global_position
	var aim_dir = Vector3.FORWARD
	
	if player:
		aim_dir = -player.camera_pivot.global_transform.basis.z.normalized() if player.get("camera_pivot") else -player.global_transform.basis.z.normalized()
		var dispersion = Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
		spawn_pos = player.global_position + (aim_dir * (current_internal_radius + 1.0)) + Vector3(0, current_internal_radius + 0.5, 0) + dispersion
	
	item.global_position = spawn_pos
	if item.has_method("set_picked_up"): item.set_picked_up(false)
	
	if player is CollisionObject3D and item is CollisionObject3D:
		item.add_collision_exception_with(player)
		get_tree().create_timer(1.2).timeout.connect(func():
			if is_instance_valid(item) and is_instance_valid(player): item.remove_collision_exception_with(player)
		)
		
	item.scale = Vector3.ONE * 0.01 
	var visual_tween = get_tree().create_tween()
	visual_tween.tween_property(item, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if item is RigidBody3D:
		var force = (aim_dir * randf_range(4.0, 7.0)) + Vector3(0, randf_range(3.0, 5.0), 0)
		item.apply_central_impulse(force)
		
	_update_ui()

# ==========================================
# 🛠️ UTILIDADES PROFUNDAS PARA LA FÍSICA
# ==========================================

func restore_item_physics(item: ConsumableItem) -> void:
	item.top_level = false 
	item.collision_layer = item.get_meta("original_layer", 1)
	item.collision_mask = item.get_meta("original_mask", 1)
	item.linear_damp = item.get_meta("original_linear_damp", 0.0)
	item.angular_damp = item.get_meta("original_angular_damp", 0.0)
	item.gravity_scale = 1.0
	
	_scale_collision_shapes(item, 1.0)
	
	item.freeze = false
	item.sleeping = false

func _scale_collision_shapes(item: Node, target_scale: float) -> void:
	var shapes = item.find_children("*", "CollisionShape3D")
	for shape in shapes:
		if not shape.has_meta("original_scale"):
			shape.set_meta("original_scale", shape.scale)
		
		var orig_scale = shape.get_meta("original_scale")
		shape.scale = orig_scale * target_scale

func get_dynamic_capacity() -> float: return base_weight_capacity * current_mass_level
func _get_current_weight() -> float:
	var total = 0.0
	for item in stored_items: total += item.item_weight
	return total
func _update_ui() -> void:
	var status = "Inventario de Masa (" + str(snapped(_get_current_weight(), 0.1)) + "/" + str(snapped(get_dynamic_capacity(), 0.1)) + "kg):\n"
	if stored_items.size() == 0: status += "- Vacío"
	else:
		for item in stored_items: status += "- " + item.item_name + " (" + str(item.item_weight) + "kg)\n"
	inventory_changed.emit(status)
