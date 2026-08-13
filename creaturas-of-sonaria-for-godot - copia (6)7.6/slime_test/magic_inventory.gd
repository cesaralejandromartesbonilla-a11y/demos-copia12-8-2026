extends Node
class_name MagicInventory

@onready var player = get_parent()
const BASE_ITEM_SCENE = preload("res://slime_test/comsumableitem.tscn")

var stored_data: Array[Dictionary] = []
var stomach_container: Node3D

func _ready():
	stomach_container = Node3D.new()
	stomach_container.name = "StomachContents"
	call_deferred("_setup_container")

func _setup_container():
	if player.visuals:
		player.visuals.add_child(stomach_container)
		# 🔥 CENTRAMOS EL ESTÓMAGO EXACTAMENTE EN EL NÚCLEO
		stomach_container.position = Vector3(0, player.default_col_height / 2.0, 0)

func get_current_capacity() -> int:
	var base_capacity = 3
	if player.transformation_module and player.form_controller:
		base_capacity = player.transformation_module.get_capacity(player.form_controller.get_current_form())
	
	if "base_visual_scale" in player:
		var current_growth = player.base_visual_scale.x - 1.0
		var extra_slots = floori(current_growth / 0.1) 
		return base_capacity + extra_slots
		
	return base_capacity

func store_physical_item(item: ConsumableItem) -> bool:
	if stored_data.size() < get_current_capacity():
		
		var dummy = MeshInstance3D.new()
		if item.item_mesh: dummy.mesh = item.item_mesh
		
		stomach_container.add_child(dummy)
		
		# --- ANIMACIÓN DE ABSORCIÓN (Agrupados en el Núcleo) ---
		dummy.global_position = item.global_position 
		
		# 🔥 Hacemos que floten pegados al núcleo (radio de 0.25) para que no toquen la cáscara externa
		var random_core_orbit = Vector3(randf_range(-0.25, 0.25), randf_range(-0.25, 0.25), randf_range(-0.25, 0.25))
		
		var tween = get_tree().create_tween()
		tween.set_parallel(true)
		tween.tween_property(dummy, "position", random_core_orbit, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
		# Los hacemos pequeñitos para que quepan todos orbitando el núcleo
		tween.tween_property(dummy, "scale", Vector3.ONE * 0.2, 0.3).set_trans(Tween.TRANS_SINE)
		
		var item_data = {
			"item_name": item.item_name,
			"form_to_grant": item.form_to_grant,
			"item_mesh": item.item_mesh,
			"forma_colision": item.forma_colision,
			"item_weight": item.item_weight,
			"hands_required": item.hands_required,
			"dummy_node": dummy
		}
	
		stored_data.append(item_data)
		item.queue_free() 
		return true
		
	return false

func _reconstruct_item(data: Dictionary) -> ConsumableItem:
	if is_instance_valid(data["dummy_node"]):
		data["dummy_node"].queue_free()
		
	var new_item = BASE_ITEM_SCENE.instantiate() as ConsumableItem
	if new_item != null:
		new_item.item_mesh = data["item_mesh"]
		new_item.item_name = data["item_name"]
		new_item.form_to_grant = data["form_to_grant"]
		# Rescatar peso y físicas
		new_item.item_weight = data["item_weight"]
		return new_item
	return null

func extract_last_item() -> ConsumableItem:
	if stored_data.is_empty(): return null
	return _reconstruct_item(stored_data.pop_back())

func extract_first_item() -> ConsumableItem:
	if stored_data.is_empty(): return null
	return _reconstruct_item(stored_data.pop_front())

func _expel_internal_inventory():
	while stored_data.size() > 0:
		_drop_item_into_world(extract_last_item())

func _enforce_capacity_limit(form_index: int):
	if player.transformation_module:
		var new_capacity = player.transformation_module.get_capacity(form_index)
		while stored_data.size() > new_capacity:
			_drop_item_into_world(extract_last_item())

func _drop_item_into_world(item: ConsumableItem):
	if item == null: return
	
	get_tree().current_scene.add_child(item)
	
	var dispersion = Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
	var spawn_pos = player.global_position + (-player.global_transform.basis.z * 1.5) + Vector3(0, 1.5, 0) + dispersion
	
	item.global_position = spawn_pos
	item.set_picked_up(false)
	
	if item is CollisionObject3D:
		item.add_collision_exception_with(player)
		# 🔥 FIX COLLISION EXCEPTION: Aseguramos que la excepción se limpie limpiamente
		get_tree().create_timer(1.2).timeout.connect(func():
			if is_instance_valid(item) and is_instance_valid(player):
				item.remove_collision_exception_with(player)
		)
	
	if is_instance_valid(item.mesh_instance):
		item.mesh_instance.scale = Vector3.ONE * 0.01 
		var tween = get_tree().create_tween()
		tween.tween_property(item.mesh_instance, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	var fuerza_impulso = (-player.global_transform.basis.z * randf_range(2.0, 4.0)) + Vector3(0, randf_range(3.0, 5.0), 0)
	item.apply_central_impulse(fuerza_impulso)
