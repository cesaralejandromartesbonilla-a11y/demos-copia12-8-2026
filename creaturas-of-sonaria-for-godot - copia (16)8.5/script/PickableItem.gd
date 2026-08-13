extends RigidBody3D
class_name PickableItem

@export var data: ItemData
@export var signals:bool = false

@onready var collision = $CollisionShape3D

var ghost_mesh: MeshInstance3D = null
var mesh_instance: Node3D
var visual_tween: Tween = null
var esta_resaltado: bool = false
var componentes_internos: Array[Dictionary] = [] 
# Estructura de cada diccionario: { "type": SegmentType, "visual": Node3D, "shape": CollisionShape3D, "item_recompensa": ItemData }

func _ready() -> void:
	if signals:
		print("cargando objeto")
	if data == null: 
		if signals:printerr("PickableItem generado sin datos en: ", global_position)
		return
		
	# 1. GENERACIÓN DINÁMICA DEL MODELO 3D
	if data.item_mesh != null:
		var nueva_malla = MeshInstance3D.new()
		nueva_malla.mesh = data.item_mesh
		mesh_instance = nueva_malla
		add_child(mesh_instance)
		
	# 2. CONFIGURACIÓN DE METADATOS Y GRUPOS
	
	# --- Bucle para asignar grupos dinámicamente desde el recurso ---
	if "item_groups" in data and data.item_groups.size() > 0:
		for group_name in data.item_groups:
			add_to_group(group_name)
	
	if data.is_edible:
		set_meta("current_capacity", data.nutrition_value)
		set_meta("max_capacity", data.nutrition_value)
		
	# Registro para el sistema de guardado y modo fantasma inicial
	add_to_group("pickable_items")
	activate_ghost_mode()
		
	if signals:print("se termino de cargar objeto")

func desprender_segmento(area_objetivo: CropSegmentArea) -> void:
	if not is_instance_valid(area_objetivo): return
	
	var mundo = get_tree().current_scene
	var scene_path = get_scene_file_path()
	if scene_path == "": scene_path = "res://items/pickable_item.tscn"
	
	var transform_real = area_objetivo.global_transform
	
	# Creamos el nuevo PickableItem independiente
	var n_item = load(scene_path).instantiate() as PickableItem
	mundo.add_child(n_item)
	n_item.global_transform = transform_real
	
	if n_item.has_node("CollisionShape3D"):
		n_item.get_node("CollisionShape3D").queue_free()
		
	var vis = area_objetivo.visual_node
	var shp = area_objetivo.shape_node
	
	# Extraemos de forma segura los nodos del área y los pasamos al nuevo ítem físico suelto
	if is_instance_valid(vis) and is_instance_valid(shp):
		area_objetivo.remove_child(vis)
		area_objetivo.remove_child(shp)
		
		n_item.add_child(vis)
		n_item.add_child(shp)
		vis.transform = Transform3D.IDENTITY
		shp.transform = Transform3D.IDENTITY
		
		n_item.collision = shp
		n_item.mesh_instance = vis
		
		if area_objetivo.item_recompensa:
			n_item.data = area_objetivo.item_recompensa
		else:
			_generar_data_ficticia_por_tipo(n_item, area_objetivo.type)
			
		n_item.inicializar_objeto()
		
		# Impulso físico radial simulando la fuerza del golpe recibido
		var impulso = Vector3(randf_range(-1.2, 1.2), randf_range(1.6, 2.4), randf_range(-1.2, 1.2))
		n_item.apply_central_impulse(impulso)
	
	# Borramos el área destruida del objeto compuesto
	area_objetivo.queue_free()
	
	# Limpieza de contenedor: si no quedan más segmentos vivos en este bloque, se elimina
	await get_tree().process_frame
	var componentes_restantes = 0
	for child in get_children():
		if child is CropSegmentArea:
			componentes_restantes += 1
			
	if componentes_restantes == 0:
		queue_free()

func dañar_segmento_interno(area_objetivo: Area3D, cantidad_daño: float) -> void:
	if not is_instance_valid(area_objetivo) or not area_objetivo.has_meta("es_segmento"): return
	
	var vida = area_objetivo.get_meta("vida_actual") - cantidad_daño
	area_objetivo.set_meta("vida_actual", max(0.0, vida))
	
	# Efecto visual sutil de impacto en la escala del sub-segmento afectado
	var vis = area_objetivo.get_meta("visual_node") as Node3D
	if vis:
		var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		tween.tween_property(vis, "scale", Vector3.ONE * 0.7, 0.05)
		tween.tween_property(vis, "scale", Vector3.ONE, 0.1)

	# 💀 Si el segmento se queda sin vida, se desprende y se independiza
	if vida <= 0.0:
		var mundo = get_tree().current_scene
		var scene_path = get_scene_file_path()
		if scene_path == "": scene_path = "res://items/pickable_item.tscn"
		
		# Guardamos su posición global antes del desprendimiento
		var transform_real = area_objetivo.global_transform
		
		# Instanciamos su nuevo contenedor PickableItem independiente
		var n_item = load(scene_path).instantiate() as PickableItem
		mundo.add_child(n_item)
		n_item.global_transform = transform_real
		
		# Eliminamos el colisionador por defecto que trae el .tscn vacío
		if n_item.has_node("CollisionShape3D"):
			n_item.get_node("CollisionShape3D").queue_free()
			
		# Extraemos los nodos originales de la estructura compuesta
		var shp = area_objetivo.get_meta("shape_node") as CollisionShape3D
		
		area_objetivo.remove_child(vis)
		area_objetivo.remove_child(shp)
		
		# Los montamos en el nuevo ítem independiente y los centramos
		n_item.add_child(vis)
		n_item.add_child(shp)
		vis.transform = Transform3D.IDENTITY
		shp.transform = Transform3D.IDENTITY
		
		# Enlazamos las variables base para tu Ghost Mode e interacciones futuras
		n_item.collision = shp
		n_item.mesh_instance = vis
		
		# Transferimos los datos del recurso o fallback
		var recompensa = area_objetivo.get_meta("item_recompensa")
		if recompensa:
			n_item.data = recompensa
		else:
			_generar_data_ficticia_por_tipo(n_item, area_objetivo.get_meta("tipo_segmento"))
			
		n_item.inicializar_objeto()
		
		# Pequeño impulso físico para simular que salió volando del hachazo
		var impulso = Vector3(randf_range(-1.0, 1.0), randf_range(1.5, 2.5), randf_range(-1.0, 1.0))
		n_item.apply_central_impulse(impulso)
		
		# Eliminamos el área del objeto compuesto antiguo
		area_objetivo.queue_free()
		
		# Comprobación de limpieza: Si el objeto compuesto ya no tiene más segmentos visuales vivos, se borra el nodo master
		await get_tree().process_frame # Esperamos un frame a que queue_free limpie el área
		var componentes_restantes = 0
		for child in get_children():
			if child.is_in_group("segmentos_interactivos"):
				componentes_restantes += 1
		
		if componentes_restantes == 0:
			queue_free()

func _generar_data_ficticia_por_tipo(item_objetivo: PickableItem, tipo_segmento: int) -> void:
	var datos_ficticios = ItemData.new()
	datos_ficticios.item_category = "planta"
	datos_ficticios.is_tool = false
	datos_ficticios.is_edible = false
	
	match tipo_segmento:
		0: datos_ficticios.item_name = "Tronco de Madera"  # TRUNK
		1: datos_ficticios.item_name = "Rama Limpia"       # BRANCH
		2: datos_ficticios.item_name = "Hojas Secas"       # LEAF
		3: datos_ficticios.item_name = "Flor Silvestre"    # FLOWER
		4: datos_ficticios.item_name = "Fruto Silvestre"   # FRUIT
		_: datos_ficticios.item_name = "Material Orgánico"
		
	item_objetivo.data = datos_ficticios

func inicializar_objeto() -> void:
	if data.item_mesh != null and mesh_instance == null:
		var nueva_malla = MeshInstance3D.new()
		nueva_malla.mesh = data.item_mesh
		mesh_instance = nueva_malla
		add_child(mesh_instance)
		
	if "item_groups" in data and data.item_groups.size() > 0:
		for group_name in data.item_groups:
			add_to_group(group_name)
			
	if data.is_edible:
		set_meta("current_capacity", data.nutrition_value)
		set_meta("max_capacity", data.nutrition_value)
		
	add_to_group("pickable_items")
	activate_ghost_mode()

func set_picked_up(is_picked: bool) -> void:
	freeze = is_picked 
	if collision:
		collision.disabled = is_picked

func resaltar_objeto(activar: bool) -> void:
	if not mesh_instance or esta_resaltado == activar: return
	esta_resaltado = activar
	
	if visual_tween:
		visual_tween.kill() # Cortamos cualquier animación de tamaño anterior
		
	visual_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Obtenemos la escala base real del objeto (por si ya está mordido/reducido)
	var escala_base = 1.0
	if has_meta("current_capacity") and has_meta("max_capacity"):
		escala_base = max(0.2, get_meta("current_capacity") / get_meta("max_capacity"))
		
	var multiplicador = 1.25 if activar else 1.0
	var escala_final = Vector3.ONE * (escala_base * multiplicador)
	
	# Animamos la propiedad de escala del Mesh de forma limpia
	visual_tween.tween_property(mesh_instance, "scale", escala_final, 0.15)

func consume(amount: float) -> bool:
	if not has_meta("current_capacity"): return false
	
	var current = get_meta("current_capacity")
	current -= amount
	set_meta("current_capacity", current)
	
	# Usamos el nodo que generamos dinámicamente para encogerlo
	if mesh_instance:
		var max_cap = get_meta("max_capacity")
		var scale_factor = max(0.2, current / max_cap)
		if esta_resaltado: scale_factor *= 1.25
		mesh_instance.scale = Vector3(scale_factor, scale_factor, scale_factor)
	
	if current <= 0:
		queue_free()
		return true
	return false

func update_ghost_placement(hit_position: Vector3, is_valid_terrain: bool) -> void:
	if ghost_mesh == null:
		_spawn_ghost_hologram()
	
	if ghost_mesh:
		ghost_mesh.global_position = hit_position
		# Cambiamos el color según la disponibilidad del espacio
		var mat = ghost_mesh.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = Color(0, 1, 0, 0.4) if is_valid_terrain else Color(1, 0, 0, 0.4)

func remove_ghost() -> void:
	if ghost_mesh and is_instance_valid(ghost_mesh):
		ghost_mesh.queue_free()
	ghost_mesh = null

func _spawn_ghost_hologram() -> void:
	if data == null or not "seed_data" in data or data.seed_data == null: return
	var s_data = data.seed_data
	
	ghost_mesh = MeshInstance3D.new()
	# Si la semilla tiene una malla inicial en sus visuales, la usamos de holograma
	if s_data.visual_data and s_data.visual_data.sprout_mesh:
		ghost_mesh.mesh = s_data.visual_data.sprout_mesh
	elif data.item_mesh:
		ghost_mesh.mesh = data.item_mesh
		
	var ghost_mat = StandardMaterial3D.new()
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.albedo_color = Color(0, 1, 0, 0.4)
	ghost_mesh.material_override = ghost_mat
	
	get_tree().current_scene.add_child(ghost_mesh)

# --- PREPARACIÓN PARA GUARDADO ---
func save_data() -> Dictionary:
	var save_dict = {
		"filename" : get_scene_file_path(), # Sabemos qué escena base instanciar (item_base.tscn)
		"parent" : str(get_parent().get_path()) if get_parent() else "", # Dónde estaba guardado
		"pos_x" : global_position.x,
		"pos_y" : global_position.y,
		"pos_z" : global_position.z,
		"rot_x" : global_rotation.x,
		"rot_y" : global_rotation.y,
		"rot_z" : global_rotation.z,
		"data_path" : ""
	}
	
	# Guardamos de qué está disfrazado este objeto (ruta del recurso ItemData)
	if data != null:
		save_dict["data_path"] = data.resource_path
		
	# Si es comida a medio comer, recordamos sus mordiscos
	if has_meta("current_capacity"):
		save_dict["current_capacity"] = get_meta("current_capacity")
		
	return save_dict

func load_data(save_dict: Dictionary) -> void:
	global_position = Vector3(save_dict["pos_x"], save_dict["pos_y"], save_dict["pos_z"])
	global_rotation = Vector3(save_dict["rot_x"], save_dict["rot_y"], save_dict["rot_z"])
	
	if save_dict["data_path"] != "":
		data = load(save_dict["data_path"])
		inicializar_objeto()
		
	if save_dict.has("current_capacity") and has_meta("current_capacity"):
		set_meta("current_capacity", save_dict["current_capacity"])
		if mesh_instance and has_meta("max_capacity"):
			var scale_factor = max(0.2, save_dict["current_capacity"] / get_meta("max_capacity"))
			mesh_instance.scale = Vector3(scale_factor, scale_factor, scale_factor)
			
	# Al ser cargado del disco, entra inmediatamente en modo fantasma para no explotar
	activate_ghost_mode()

func activate_ghost_mode() -> void:
	if collision == null: return
	var original_mask = collision_mask
	var original_layer = collision_layer
	
	collision_layer = 0
	collision_mask = 1
	
	await get_tree().create_timer(0.5).timeout
	
	if is_instance_valid(self) and not freeze:
		collision_mask = original_mask
		collision_layer = original_layer
