extends Node
class_name ItemSaveManager

const SAVE_PATH = "user://world_items_data.dat"

func save_items() -> void:
	var saved_items: Array = []
	var all_items = get_tree().get_nodes_in_group("pickable_items")
	
	for item in all_items:
		if item.has_method("save_data"):
			saved_items.append(item.save_data())
			
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(saved_items)
		file.close()
		print("[ItemSystem] Objetos del entorno guardados: ", saved_items.size())

func load_items() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[ItemSystem] No hay archivo de objetos previo.")
		return
		
	# Limpieza de objetos actuales sueltos en el mapa
	var current_items = get_tree().get_nodes_in_group("pickable_items")
	for item in current_items:
		item.queue_free()
		
	await get_tree().process_frame
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file: return
	var saved_items = file.get_var()
	file.close()
	
	for item_data in saved_items:
		var scene_path = item_data["filename"]
		if not ResourceLoader.exists(scene_path): continue
		
		var item_scene = load(scene_path)
		var new_item = item_scene.instantiate()
		
		# TRUCO DE FÍSICAS: Lo congelamos y aislamos antes de meterlo al árbol
		new_item.collision_layer = 0
		new_item.collision_mask = 1
		new_item.freeze = true 
		
		var parent_node = get_node_or_null(item_data["parent"])
		if parent_node: parent_node.add_child(new_item)
		else: get_tree().current_scene.add_child(new_item)
			
		if new_item.has_method("load_data"):
			new_item.load_data(item_data)
			
		# Lo posicionamos en su lugar definitivo
		new_item.global_position = Vector3(item_data["pos_x"], item_data["pos_y"], item_data["pos_z"])
		new_item.global_rotation = Vector3(item_data["rot_x"], item_data["rot_y"], item_data["rot_z"])
		
		# Descongelación diferida: Espera a que el motor procese el cambio de posición
		_despertar_body.call_deferred(new_item)
		
	print("[ItemSystem] Entorno restaurado con mallas y físicas estables.")

func _despertar_body(body: RigidBody3D) -> void:
	if is_instance_valid(body):
		body.freeze = false
		body.sleeping = false
