extends Node

enum LoadMode { AUTO, FORZAR_CARGA, DESACTIVADO }

@export_group("Configuración de Carga")
@export var cargar_criatura: LoadMode = LoadMode.AUTO
@export var cargar_agricultura: LoadMode = LoadMode.AUTO

@export_group("Herramienta de Depuración")
@export var modo_depuracion: bool = true

@onready var spawn_point: Marker3D = $SpawnPoint

func _ready() -> void:
	_debug_print("[Mundo] --- INICIANDO CONFIGURACIÓN DE ESCENA ---")
	_setup_creature_on_start()
	_setup_crops_on_start()
	_debug_print("[Mundo] --- CONFIGURACIÓN DE ESCENA COMPLETADA ---")

# --- FLUJO INICIAL: CRIATURA ---
func _setup_creature_on_start() -> void:
	var save = InventoryManager.current_save_state
	var tiene_guardado: bool = (save != null)
	var proceder_con_criatura: bool = false
	
	match cargar_criatura:
		LoadMode.AUTO: proceder_con_criatura = (InventoryManager.selected_creature != null)
		LoadMode.FORZAR_CARGA: proceder_con_criatura = true
		LoadMode.DESACTIVADO: proceder_con_criatura = false
		
	_debug_print("[Mundo - Criatura] Modo de carga inicial: %s (¿Tiene guardado válido?: %s)" % [LoadMode.keys()[cargar_criatura], tiene_guardado])

	if proceder_con_criatura:
		if InventoryManager.selected_creature == null:
			_debug_print("[Mundo - ERROR] Se intentó cargar la criatura pero 'selected_creature' es NULL.")
			return
			
		_spawn_and_initialize_creature(save, tiene_guardado and cargar_criatura == LoadMode.AUTO)
	else:
		_debug_print("[Mundo - Criatura] Carga automática omitida o desactivada.")

func _spawn_and_initialize_creature(save_data, use_saved_position: bool) -> void:
	var scene_path = InventoryManager.selected_creature.creature_scene_path
	_debug_print("[Mundo - Criatura] Instanciando escena desde ruta: " + scene_path)
	
	var creature_scene = load(scene_path).instantiate()
	add_child(creature_scene)
	
	if use_saved_position:
		creature_scene.global_position = save_data.global_position
		creature_scene.global_rotation = save_data.global_rotation
		_debug_print("[Mundo - Criatura] Posicionada con éxito en coordenadas guardadas: " + str(save_data.global_position))
	else:
		creature_scene.global_transform = spawn_point.global_transform
		_debug_print("[Mundo - Criatura] Posicionada con éxito en el Marker3D (SpawnPoint).")
		
	creature_scene.initialize_from_data(InventoryManager.selected_creature)
	_debug_print("[Mundo - Criatura] Estadísticas y evolución inicializadas.")

# --- FLUJO INICIAL: PLANTAS ---
func _setup_crops_on_start() -> void:
	var save = InventoryManager.current_save_state
	var proceder_con_plantas: bool = false
	
	match cargar_agricultura:
		LoadMode.AUTO: proceder_con_plantas = (save != null)
		LoadMode.FORZAR_CARGA: proceder_con_plantas = true
		LoadMode.DESACTIVADO: proceder_con_plantas = false
		
	_debug_print("[Mundo - Plantas] Modo de carga inicial: %s" % [LoadMode.keys()[cargar_agricultura]])

	if proceder_con_plantas:
		_execute_crop_loading()
	else:
		_debug_print("[Mundo - Plantas] Carga inicial agrícola omitida.")

func _execute_crop_loading() -> void:
	_debug_print("[Mundo - Plantas] Buscando o instanciando CropSaveManager...")
	var manager = get_node_or_null("CropSaveManager")
	if not manager:
		manager = CropSaveManager.new()
		manager.name = "CropSaveManager"
		add_child(manager)
		_debug_print("[Mundo - Plantas] CropSaveManager no existía, se ha creado uno dinámicamente.")
	
	_debug_print("[Mundo - Plantas] Disparando orden 'load_agriculture()'...")
	manager.load_agriculture()


# ==============================================================================
# LÓGICA DE LOS BOTONES DEL INSPECTOR 
# ==============================================================================
func manual_save_creature() -> void:
	_debug_print("[Botón] Ejecutando GUARDADO manual de Criatura...")
	# Aquí invocas el método o sistema que ya tengas para salvar la criatura
	# Ejemplo: InventoryManager.save_current_creature_state()
	_debug_print("[Botón] ¡Guardado de criatura finalizado!")

func manual_load_creature() -> void:
	_debug_print("[Botón] Ejecutando CARGA manual de Criatura...")
	# Primero eliminamos la criatura vieja si ya existe para evitar clones
	for child in get_children():
		if child.has_method("initialize_from_data"):
			_debug_print("[Botón] Eliminando criatura actual del mapa para evitar duplicados...")
			child.queue_free()
	
	await get_tree().process_frame # Esperamos limpieza de memoria
	_setup_creature_on_start()

func manual_save_crops() -> void:
	_debug_print("[Botón] Ejecutando GUARDADO manual del sistema agrícola...")
	var manager = get_node_or_null("CropSaveManager")
	if not manager:
		manager = CropSaveManager.new()
		manager.name = "CropSaveManager"
		add_child(manager)
	manager.save_agriculture()
	_debug_print("[Botón] ¡Guardado de plantas finalizado!")

func manual_load_crops() -> void:
	_debug_print("[Botón] Ejecutando CARGA manual del sistema agrícola...")
	_execute_crop_loading()

func manual_save_items() -> void:
	_debug_print("[HUD] Guardando objetos sueltos del mundo...")
	var manager = _get_or_create_item_manager()
	manager.save_items()

func manual_load_items() -> void:
	_debug_print("[HUD] Cargando objetos sueltos del mundo...")
	var manager = _get_or_create_item_manager()
	manager.load_items()

func _get_or_create_item_manager() -> ItemSaveManager:
	var manager = get_node_or_null("ItemSaveManager")
	if not manager:
		manager = ItemSaveManager.new()
		manager.name = "ItemSaveManager"
		add_child(manager)
	return manager

# ==============================================================================
# SISTEMA DE IMPRESIÓN CENTRALIZADO
# ==============================================================================
func _debug_print(message: String) -> void:
	if modo_depuracion:
		print_rich("[color=yellow]%s[/color]" % message) # Imprime en amarillo en la consola de Godot para que salte a la vista
