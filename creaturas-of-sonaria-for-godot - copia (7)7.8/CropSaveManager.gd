extends Node
class_name CropSaveManager

const SAVE_PATH = "user://agriculture_data.dat"

# --- FUNCIÓN DE GUARDADO ---
func save_agriculture() -> void:
	var saved_crops: Array = []
	var all_crops = get_tree().get_nodes_in_group("crop_plot")
	
	for crop in all_crops:
		if crop.has_method("save_data"):
			saved_crops.append(crop.save_data())
			
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(saved_crops)
		file.close()
		print("[SaveSystem] Cultivos guardados con éxito: ", saved_crops.size())

# --- FUNCIÓN DE CARGA ---
func load_agriculture() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[SaveSystem] No se encontró ningún archivo de guardado agrícola previo.")
		return
		
	# 1. LIMPIEZA TOTAL: Eliminamos los cultivos actuales del mapa para evitar duplicados
	var current_crops = get_tree().get_nodes_in_group("crop_plot")
	for crop in current_crops:
		crop.queue_free()
		
	# Esperamos un frame de físicas para garantizar que el motor limpió las áreas de la memoria
	await get_tree().process_frame
	
	# 2. LECTURA DEL ARCHIVO
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file: return
	
	var saved_crops = file.get_var()
	file.close()
	
	# 3. RECONSTRUCCIÓN DE PLANTAS
	for crop_data in saved_crops:
		var scene_path = crop_data["filename"]
		if not ResourceLoader.exists(scene_path): continue
		
		# Instanciamos dinámicamente si es parcela básica o planta libre
		var crop_scene = load(scene_path)
		var new_crop = crop_scene.instantiate()
		
		# Lo devolvemos a su contenedor/padre original en el árbol de nodos
		var parent_node = get_node_or_null(crop_data["parent"])
		if parent_node:
			parent_node.add_child(new_crop)
		else:
			get_tree().current_scene.add_child(new_crop)
			
		# Le inyectamos sus estadísticas guardadas
		if new_crop.has_method("load_data"):
			new_crop.load_data(crop_data)
			
	print("[SaveSystem] Sistema agrícola restaurado correctamente. Plantas cargadas: ", saved_crops.size())
