extends Area3D
class_name ConsumerComponent

@onready var slime = get_parent()
@onready var hold_position = slime.get_node("HoldPosition")

var held_item: RigidBody3D = null
var throw_force: float = 15.0
var massive_mode: bool = false # false = Modo Normal (Click), true = Modo Masivo (Auto)

func _ready():
	body_entered.connect(_on_body_entered)

# --- FUNCIÓN DE APOYO ---
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
	
	# Si ya tenemos un objeto en la cabeza, le decimos a la mano que lo apunte a él
	if held_item != null:
		if slime.aim_ik_coordinator:
			slime.aim_ik_coordinator.set_grab_target(held_item)
		return

	# Si la mano está libre, escaneamos la zona
	var bodies = get_overlapping_bodies()
	var closest_item: ConsumableItem = null
	var min_distance = INF
	
	for body in bodies:
		if body is ConsumableItem:
			var distance = global_position.distance_to(body.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_item = body
	
	# Pasamos directamente el objeto encontrado al coordinador
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
	
	for blob in all_mass:
		if not is_instance_valid(blob): continue
			
		var dist = mouth_pos.distance_to(blob.global_position)
		if dist < pull_radius:
			var dir = (mouth_pos - blob.global_position).normalized()
			blob.linear_velocity = dir * 12.0 
			
			if dist < 2.5 * slime.base_visual_scale.x:
				var recovered_mass = blob.get_meta("mass_value")
				if slime.matter_controller: slime.matter_controller.grow_slime(recovered_mass)
				blob.queue_free()

func _get_closest_item_on_floor() -> ConsumableItem:
	var bodies = get_overlapping_bodies()
	var closest_item: ConsumableItem = null
	var min_distance = INF
	
	for body in bodies:
		if body is ConsumableItem and body != held_item: # <- Se borró el check de stored_objects
			var distance = global_position.distance_to(body.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_item = body
	return closest_item

# --- EL RESTO DEL SCRIPT QUEDA CASI IGUAL, SOLO PEQUEÑOS AJUSTES ---

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
			
			if slime.magic_inventory.store_physical_item(body):
				_grant_form(form_name)
				if slime.matter_controller: slime.matter_controller.grow_slime(absorbed_weight)
				
				if slime.aim_ik_coordinator:
					slime.aim_ik_coordinator.release_grab()

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
	
	# RECOGER
	if event.is_action_pressed("press_clickIZ"):
		if held_item != null:
			throw_item()
		else:
			try_pick_up_to_head()
			
	# SELECCIONAR / ALMACENAR (Inventario Interno)
	elif event.is_action_pressed("press_e"):
		if has_stomach:
			if held_item != null:
				put_back_item() # Guardar en el estómago (sin digerirlo)
			elif slime.magic_inventory.stored_data.size() > 0:
				extract_item() # Sacar del estómago a la cabeza
				
	# ABSORBER / DIGERIR
	elif event.is_action_pressed("press_f"):
		if held_item != null and has_stomach:
			digest_held_item() # Lo consumes para crecer, destruyendo el objeto
			
	# Soltar suavemente o Aspirar Masa Perdida
	elif event.is_action_pressed("press_clickDE"):
		if held_item != null:
			drop_item()
		elif has_stomach:
			_vacuum_expelled_mass()
		
	# alternar modos
	elif event.is_action_pressed("null"):
		massive_mode = not massive_mode
		print("Modo de recolección cambiado. ¿Modo Masivo?: ", massive_mode)

func try_pick_up_to_head():
	var bodies = get_overlapping_bodies()
	var closest_item: ConsumableItem = null
	var min_distance = INF
	
	# Solo busca objetos consumibles, ignora la masa expulsada (esa se aspira)
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
	
	# 🔥 NUEVO: Extraer el material físico del objeto
	var item_mat: Material = null
	
	# Intento 1: Sacarlo de la malla Resource
	if held_item.get("item_mesh") != null and held_item.item_mesh.get_surface_count() > 0:
		item_mat = held_item.item_mesh.surface_get_material(0)
		
	# Intento 2: Sacarlo del override del MeshInstance3D
	if item_mat == null and held_item.has_node("MeshInstance3D"):
		item_mat = held_item.get_node("MeshInstance3D").material_override

	# Pasamos el material a la función del jugador
	_grant_form(form_name) # Asumiendo que usas tu función de desbloqueo
	if slime.matter_controller:
		slime.matter_controller.consume_element(element_name, item_mat) # ¡Aquí pasamos el material!
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
		# Actualizamos manteniendo el margen constante
		if area_shape.shape is SphereShape3D:
			area_shape.shape.radius = body_radius + grab_margin
		elif area_shape.shape is CapsuleShape3D or area_shape.shape is CylinderShape3D:
			area_shape.shape.radius = body_radius + grab_margin
			area_shape.shape.height = body_height + (grab_margin * 2.0)

# --- Lógicas de manipulación ---
func extract_item():
	var item = slime.magic_inventory.extract_last_item() 
	if item:
		item.reapply_collision_shape()
		place_on_head(item)

func put_back_item():
	if held_item:
		if slime.magic_inventory.store_physical_item(held_item):
			held_item = null

func place_on_head(item: ConsumableItem):
	var current_parent = item.get_parent()
	if current_parent:
		current_parent.remove_child(item)
		
	hold_position.add_child(item)
	item.visible = true
	
	# Truco del fantasma y desactivar físicas
	item.add_collision_exception_with(slime)
	item.set_picked_up(true)
	
	# Lo teletransportamos al estómago
	if is_instance_valid(slime.magic_inventory.stomach_container):
		item.global_position = slime.magic_inventory.stomach_container.global_position
	else:
		item.position = Vector3.ZERO
		
	# --- EL FIX MÁGICO DE GODOT ---
	# Esperamos 1 solo fotograma para que el motor asimile el cambio de posición
	await get_tree().process_frame
	
	# Ahora el Tween sabrá perfectamente cómo llevarlo desde el estómago hasta la cabeza
	if is_instance_valid(item): # Comprobación de seguridad
		var tween = get_tree().create_tween()
		tween.tween_property(item, "position", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	held_item = item

func release_from_head(item: ConsumableItem):
	held_item = null
	hold_position.remove_child(item)
	get_tree().current_scene.add_child(item)
	
	# ELIMINAMOS la manipulación manual de físicas (freeze y set_deferred).
	# En su lugar, usamos la función maestra que ya optimizamos en el objeto:
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

# --- Ciclado de Munición ---
func cycle_held_item(direction: int):
	if slime.magic_inventory.stored_data.size() == 0:
		return
		
	var current = held_item
	var next_item = null
	
	if direction == 1:
		next_item = slime.magic_inventory.extract_first_item()
	else:
		next_item = slime.magic_inventory.extract_last_item()
		
	# Guardamos el que teníamos en la cabeza
	if current:
		slime.magic_inventory.store_physical_item(current)
		
	# Ponemos el nuevo en la cabeza
	if next_item:
		place_on_head(next_item)

func process_consumption():
	if held_item:
		var form_name = held_item.form_to_grant
		if slime.magic_inventory.store_physical_item(held_item):
			_grant_form(form_name)
			held_item = null
		else:
			print("No puedo consumir esto, inventario interno lleno.")
