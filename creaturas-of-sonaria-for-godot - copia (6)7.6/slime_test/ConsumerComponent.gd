extends Area3D
class_name ConsumerComponent

@onready var slime = get_parent()
@onready var hold_position = slime.get_node("HoldPosition")

var held_item: RigidBody3D = null
var throw_force: float = 15.0
var massive_mode: bool = false 

enum InventoryType { MAGIC_POCKET, INTERNAL_MASS }
@export var active_inventory: InventoryType = InventoryType.INTERNAL_MASS

func _ready():
	body_entered.connect(_on_body_entered)

func _current_form_has_arms() -> bool:
	if slime.transformation_module and slime.form_controller:
		var form_index = slime.form_controller.current_form_index
		var config = slime.transformation_module.form_configs.get(form_index, {})
		return config.get("is_modular", false)
	return false

func _physics_process(_delta):
	if not _current_form_has_arms():
		if is_instance_valid(slime.aim_ik_coordinator):
			slime.aim_ik_coordinator.release_grab()
		return
		
	var has_stomach = false
	if slime.form_controller:
		has_stomach = slime.transformation_module.allows_internal_inventory(slime.form_controller.current_form_index)
		
	if has_stomach and Input.is_action_pressed("press_clickIZ") and held_item == null:
		_vacuum_expelled_mass()
	
	if held_item != null:
		if slime.aim_ik_coordinator:
			slime.aim_ik_coordinator.set_grab_target(held_item)
		return

	var bodies = get_overlapping_bodies()
	var closest_item: ConsumableItem = null
	var min_distance = INF
	
	for body in bodies:
		if body is ConsumableItem:
			var distance = global_position.distance_to(body.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_item = body
	
	if closest_item != null:
		if slime.aim_ik_coordinator:
			slime.aim_ik_coordinator.set_grab_target(closest_item)
	else:
		if is_instance_valid(slime.aim_ik_coordinator):
			slime.aim_ik_coordinator.release_grab()

func _vacuum_expelled_mass():
	var pull_radius = 6.0 * slime.base_visual_scale.x 
	var mouth_pos = global_position
	
	var all_mass = get_tree().get_nodes_in_group("expelled_mass")
	var sticky_nodes = get_tree().get_nodes_in_group("sticky_nodes")
	var total_targets = all_mass + sticky_nodes
	
	for blob in total_targets:
		if not is_instance_valid(blob): continue
			
		var dist = mouth_pos.distance_to(blob.global_position)
		if dist < pull_radius:
			
			# Si NO es un anclaje activo, lo arrastramos hacia la boca
			if not (blob is StickyNode and blob.is_anchored):
				var dir = (mouth_pos - blob.global_position).normalized()
				blob.linear_velocity = dir * 12.0 
			
			# Distancia de "Mordida" (Ya está en la boca o tocándolo)
			if dist < 2.5 * slime.base_visual_scale.x:
				if blob is StickyNode:
					if not blob.is_depleted:
						if slime.matter_controller: slime.matter_controller.grow_slime(blob.stored_mass)
						blob.is_depleted = true
					
					# Adherirse a la superficie del nodo si estaba pegado a una pared
					if blob.is_anchored:
						slime.attach_to_surface(blob.global_position, blob.surface_normal)
						if slime.locomotion:
							slime.locomotion.stop_grapple() # Soltamos la red para pasar a modo pared
					
					var is_active_tether = false
					if slime.locomotion: 
						is_active_tether = slime.locomotion.active_grapple_nodes.has(blob)
					
					if not is_active_tether:
						blob.queue_free()
				else:
					var recovered_mass = blob.get_meta("mass_value", 0.2)
					if slime.matter_controller: slime.matter_controller.grow_slime(recovered_mass)
					blob.queue_free()

func _get_closest_item_on_floor() -> ConsumableItem:
	var bodies = get_overlapping_bodies()
	var closest_item: ConsumableItem = null
	var min_distance = INF
	
	for body in bodies:
		if body is ConsumableItem and body != held_item:
			var distance = global_position.distance_to(body.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_item = body
	return closest_item

func _on_body_entered(body):
	var has_stomach = false
	if slime.form_controller:
		has_stomach = slime.transformation_module.allows_internal_inventory(slime.form_controller.current_form_index)
	if not has_stomach:
		return
		
	if slime.form_controller and slime.form_controller.get_current_form() == FormController.Form.DEVOURER:
		if massive_mode and body is ConsumableItem and body != held_item:
			var form_name = body.form_to_grant
			var absorbed_weight = body.item_weight
			
			var stored_successfully = false
			if active_inventory == InventoryType.MAGIC_POCKET and slime.has_node("MagicInventory"):
				stored_successfully = slime.magic_inventory.store_physical_item(body)
			elif active_inventory == InventoryType.INTERNAL_MASS and slime.has_node("InternalInventory"):
				stored_successfully = slime.get_node("InternalInventory").try_absorb_item(body)
			
			if stored_successfully:
				_grant_form(form_name)
				if slime.matter_controller: slime.matter_controller.grow_slime(absorbed_weight)
				if slime.aim_ik_coordinator: slime.aim_ik_coordinator.release_grab()

func _grant_form(form_name: String):
	var target_form = FormController.Form.SLIME
	match form_name:
		"SLIME": target_form = FormController.Form.SLIME
		"STONE": target_form = FormController.Form.STONE
		"FIRE": target_form = FormController.Form.FIRE
		"SKELETON": target_form = FormController.Form.SKELETON
	if slime.form_controller:
		slime.form_controller.unlock_form(target_form)

func _grant_element(element_name: String):
	if slime.matter_controller and slime.matter_controller.has_method("consume_element"):
		slime.matter_controller.consume_element(element_name)

func _unhandled_input(event):
	var has_stomach = false
	if slime.form_controller:
		has_stomach = slime.transformation_module.allows_internal_inventory(slime.form_controller.current_form_index)
	
	if event.is_action_pressed("press_clickIZ"):
		if held_item != null:
			throw_item()
		else:
			try_pick_up_to_head()
			
	elif event.is_action_pressed("press_e"):
		if has_stomach:
			if held_item != null:
				put_back_item() 
			else:
				var has_items = false
				if active_inventory == InventoryType.MAGIC_POCKET and slime.has_node("MagicInventory"):
					has_items = slime.magic_inventory.stored_data.size() > 0
				elif active_inventory == InventoryType.INTERNAL_MASS and slime.has_node("InternalInventory"):
					has_items = slime.get_node("InternalInventory").stored_items.size() > 0
					
				if has_items:
					extract_item() 
				
	elif event.is_action_pressed("press_f"):
		if held_item != null and has_stomach:
			digest_held_item() 
		else:
			_vacuum_expelled_mass()
			
	elif event.is_action_pressed("press_clickDE"):
		if held_item != null:
			drop_item()
		
	elif event.is_action_pressed("null"):
		massive_mode = not massive_mode
		print("Modo de recolección cambiado. ¿Modo Masivo?: ", massive_mode)

func try_pick_up_to_head():
	var bodies = get_overlapping_bodies()
	var closest_item: ConsumableItem = null
	var min_distance = INF
	
	for body in bodies:
		if body is ConsumableItem and body != held_item:
			var distance = global_position.distance_to(body.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_item = body
				
	if closest_item != null:
		place_on_head(closest_item)
		if slime.aim_ik_coordinator:
			slime.aim_ik_coordinator.set_grab_target(held_item)

func digest_held_item():
	print("Digeriendo objeto: ", held_item.name)
	var form_name = held_item.form_to_grant
	var element_name = held_item.get("element_to_grant") 
	if element_name == null: element_name = "BASE"
	var absorbed_weight = held_item.item_weight
	
	var item_mat: Material = null
	if held_item.get("item_mesh") != null and held_item.item_mesh.get_surface_count() > 0:
		item_mat = held_item.item_mesh.surface_get_material(0)
		
	if item_mat == null and held_item.has_node("MeshInstance3D"):
		item_mat = held_item.get_node("MeshInstance3D").material_override

	_grant_form(form_name) 
	if slime.matter_controller:
		slime.matter_controller.consume_element(element_name, item_mat) 
		slime.matter_controller.grow_slime(absorbed_weight)
	
	if slime.aim_ik_coordinator:
		slime.aim_ik_coordinator.release_grab()
		
	held_item.queue_free()
	held_item = null

var grab_margin: float = 1.2

func update_area_size(body_radius: float, body_height: float):
	var area_shape = null
	for child in get_children():
		if child is CollisionShape3D:
			area_shape = child
			break
			
	if area_shape and area_shape.shape:
		if area_shape.shape is SphereShape3D:
			area_shape.shape.radius = body_radius + grab_margin
		elif area_shape.shape is CapsuleShape3D or area_shape.shape is CylinderShape3D:
			area_shape.shape.radius = body_radius + grab_margin
			area_shape.shape.height = body_height + (grab_margin * 2.0)

# ==========================================
# LÓGICAS DE MANIPULACIÓN ADAPTADAS
# ==========================================

func extract_item():
	var item = null
	
	if active_inventory == InventoryType.MAGIC_POCKET and slime.has_node("MagicInventory"):
		item = slime.magic_inventory.extract_last_item()
	elif active_inventory == InventoryType.INTERNAL_MASS and slime.has_node("InternalInventory"):
		var internal_inv = slime.get_node("InternalInventory")
		if internal_inv.stored_items.size() > 0:
			item = internal_inv.stored_items.pop_back()
			
			var current_parent = item.get_parent()
			if current_parent: current_parent.remove_child(item)
			get_tree().current_scene.add_child(item)
			internal_inv.restore_item_physics(item)

	if item:
		if item.has_method("reapply_collision_shape"):
			item.reapply_collision_shape()
		place_on_head(item)

func put_back_item():
	if held_item:
		var current_item = held_item 
		var stored = false
		
		if active_inventory == InventoryType.MAGIC_POCKET and slime.has_node("MagicInventory"):
			stored = slime.magic_inventory.store_physical_item(current_item)
		elif active_inventory == InventoryType.INTERNAL_MASS and slime.has_node("InternalInventory"):
			var internal_inv = slime.get_node("InternalInventory")
			release_from_head(current_item)
			stored = internal_inv.try_absorb_item(current_item)
			
		if stored:
			held_item = null

func place_on_head(item: ConsumableItem):
	var current_parent = item.get_parent()
	if current_parent:
		current_parent.remove_child(item)
		
	hold_position.add_child(item)
	item.visible = true
	item.add_collision_exception_with(slime)
	item.set_picked_up(true)
	
	if active_inventory == InventoryType.MAGIC_POCKET and is_instance_valid(slime.magic_inventory.stomach_container):
		item.global_position = slime.magic_inventory.stomach_container.global_position
	elif active_inventory == InventoryType.INTERNAL_MASS and slime.has_node("InternalInventory"):
		item.global_position = slime.get_node("InternalInventory").global_position
	else:
		item.position = Vector3.ZERO
		
	await get_tree().process_frame
	
	if is_instance_valid(item): 
		var tween = get_tree().create_tween()
		tween.tween_property(item, "position", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	held_item = item

func release_from_head(item: ConsumableItem):
	held_item = null
	var current_parent = item.get_parent()
	if current_parent == hold_position:
		hold_position.remove_child(item)
		get_tree().current_scene.add_child(item)
	
	item.set_picked_up(false)

func drop_item():
	var item = held_item
	release_from_head(item)
	
	if slime.camera_controller:
		item.global_position = hold_position.global_position + (slime.camera_controller.global_transform.basis * Vector3(0, 0, -1.5))

func throw_item():
	var item = held_item
	release_from_head(item)
	
	if slime.camera_controller:
		item.global_position = hold_position.global_position + (slime.camera_controller.global_transform.basis * Vector3(0, 0, -1.5))
		var aim_dir = slime.camera_controller.get_aim_direction()
		var throw_dir = (aim_dir + Vector3(0, 0.3, 0)).normalized()
		item.apply_central_impulse(throw_dir * throw_force)

# ==========================================
# CICLADO DE MUNICIÓN ADAPTADO
# ==========================================

func cycle_held_item(direction: int):
	var next_item = null
	var current = held_item
	
	if active_inventory == InventoryType.MAGIC_POCKET and slime.has_node("MagicInventory"):
		if slime.magic_inventory.stored_data.size() == 0: return
		next_item = slime.magic_inventory.extract_first_item() if direction == 1 else slime.magic_inventory.extract_last_item()
		if current: slime.magic_inventory.store_physical_item(current)
			
	elif active_inventory == InventoryType.INTERNAL_MASS and slime.has_node("InternalInventory"):
		var internal_inv = slime.get_node("InternalInventory")
		if internal_inv.stored_items.size() == 0: return
		
		next_item = internal_inv.stored_items.pop_front() if direction == 1 else internal_inv.stored_items.pop_back()
		
		if next_item:
			var parent = next_item.get_parent()
			if parent: parent.remove_child(next_item)
			get_tree().current_scene.add_child(next_item)
			internal_inv.restore_item_physics(next_item)
			next_item.scale = Vector3.ONE
		
		if current: 
			release_from_head(current)
			internal_inv.try_absorb_item(current)
			
	if next_item:
		if next_item.has_method("reapply_collision_shape"): next_item.reapply_collision_shape()
		place_on_head(next_item)

func process_consumption():
	if held_item:
		var current_item = held_item
		var form_name = current_item.form_to_grant
		var stored = false
		
		if active_inventory == InventoryType.MAGIC_POCKET and slime.has_node("MagicInventory"):
			stored = slime.magic_inventory.store_physical_item(current_item)
		elif active_inventory == InventoryType.INTERNAL_MASS and slime.has_node("InternalInventory"):
			release_from_head(current_item)
			stored = slime.get_node("InternalInventory").try_absorb_item(current_item)
			
		if stored:
			_grant_form(form_name)
			held_item = null
		else:
			print("No puedo consumir esto, inventario activo lleno.")
