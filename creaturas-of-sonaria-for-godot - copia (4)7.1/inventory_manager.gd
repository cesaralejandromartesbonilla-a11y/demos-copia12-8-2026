extends Node

const SAVE_DIR = "user://saves/"
const PLAYER_SAVE_PATH = "user://saves/player_profile.tres"

var player_data: PlayerData
var selected_instance_id: String = "" 
var selected_creature: CreatureData = null
var current_save_state: CreatureSaveState = null
var unlocked_creature_parts: Array[CreaturePartData] = []

func _ready():
	# Crear un chasis de prueba en memoria
	var chasis_test = CreaturePartData.new()
	chasis_test.display_name = "Chasis Humanoide de Pruebas"
	chasis_test.slot_type = CreaturePartData.SlotType.CHASIS
	chasis_test.part_scene = preload("res://slime_test/chasis.tscn")
	unlocked_creature_parts.append(chasis_test)
#	Chasis (Node3D o CharacterBody3D - Con el script CreatureChassis.gd)
#	└── Armature (Node3D)
#	   └── Skeleton3D (El esqueleto de tu torso del modelo 3D)
#	       ├── BoneAttachment3D_BrazoDer (Configurado al hueso "Arm_R")
#	        │   └── Socket_BrazoDer (Area3D - Con el script InteractiveSocket.gd)
#	        │       └── CollisionShape3D (Una pequeña esfera para el Raycast)
#	        └── BoneAttachment3D_Cabeza (Configurado al hueso "Head")
#	            └── Socket_Cabeza (Area3D - Con el script InteractiveSocket.gd)
#	                └── CollisionShape3D
	
	
	# Crear un brazo de prueba en memoria
	var brazo_test = CreaturePartData.new()
	brazo_test.display_name = "Garra de Prueba"
	brazo_test.slot_type = CreaturePartData.SlotType.MANOS
	brazo_test.part_scene = preload("res://slime_test/arm_L_large.tscn")
	unlocked_creature_parts.append(brazo_test)
	_ensure_dir_exists()
	load_player_profile()

func _ensure_dir_exists():
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)

func load_player_profile() -> void:
	if FileAccess.file_exists(PLAYER_SAVE_PATH):
		player_data = load(PLAYER_SAVE_PATH)
	else:
		player_data = PlayerData.new()
		save_player_profile()

func save_player_profile() -> void:
	ResourceSaver.save(player_data, PLAYER_SAVE_PATH)


func add_creature_part(part: CreaturePartData) -> void:
	if not unlocked_creature_parts.has(part):
		unlocked_creature_parts.append(part)

func get_parts_by_category(category_index: int) -> Array[CreaturePartData]:
	var valid_parts: Array[CreaturePartData] = []
	for part in unlocked_creature_parts:
		# category_index vendrá de la HUD (ej: 0 para PIES, 1 para MANOS...)
		if part.slot_type == category_index: 
			valid_parts.append(part)
	return valid_parts

func get_parts_for_socket(socket_name: String) -> Array[CreaturePartData]:
	var valid_parts: Array[CreaturePartData] = []
	for part in unlocked_creature_parts:
		# Asume que añadiste 'compatible_socket' a tu CreaturePartData
		if part.get("compatible_socket") == socket_name: 
			valid_parts.append(part)
	return valid_parts

# --- SISTEMA DE MONEDAS ---
func add_coins(amount: int) -> void:
	player_data.coins += amount
	save_player_profile()

# --- SISTEMA DE TIENDA Y DESBLOQUEO ---
func buy_creature(creature: CreatureData) -> bool:
	if player_data.coins >= creature.price:
		player_data.coins -= creature.price
		
		# Generamos un ID único para esta criatura específica
		var new_id = str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000)
		var new_instance = {
			"creature_path": creature.resource_path,
			"instance_id": new_id
		}
		
		player_data.owned_instances.append(new_instance)
		save_player_profile()
		return true
	return false

# Esta es la función que pedía tu Shop.gd
# En un sistema múltiple, esto devuelve true si posees al menos UNA de esa especie
func is_unlocked(creature: CreatureData) -> bool:
	for instance in player_data.owned_instances:
		if instance["creature_path"] == creature.resource_path:
			return true
	return false

# --- GESTIÓN DE PARTIDAS POR ID ---
func _get_save_path_by_id(id: String) -> String:
	return SAVE_DIR + "creature_" + id + ".tres"

func has_save_file(id: String) -> bool:
	return FileAccess.file_exists(_get_save_path_by_id(id))

func set_selected_instance(instance_data: Dictionary) -> void:
	selected_instance_id = instance_data["instance_id"]
	selected_creature = load(instance_data["creature_path"])
	
	if has_save_file(selected_instance_id):
		current_save_state = load(_get_save_path_by_id(selected_instance_id))
	else:
		current_save_state = null

func save_game(creature_node: CharacterBody3D) -> void:
	if selected_instance_id == "": 
		print("Error: No hay instancia seleccionada para guardar.")
		return
	
	# Si ya hay una partida cargada, la actualizamos. Si no, creamos una nueva.
	var save: CreatureSaveState
	if current_save_state != null:
		save = current_save_state
	else:
		save = CreatureSaveState.new()
		save.template = selected_creature
	
	# Guardar Supervivencia
	if creature_node.survival:
		save.current_health = creature_node.survival.current_health
		save.current_hunger = creature_node.survival.current_hunger
		save.current_thirst = creature_node.survival.current_thirst
		save.set("current_energy", creature_node.survival.current_energy)
		save.growth_percent = creature_node.survival.growth_percent
	
	# Guardar Nivel y XP
	if creature_node.get_node_or_null("LevelManager"):
		var lvl_mgr = creature_node.get_node("LevelManager")
		save.level = lvl_mgr.level
		save.current_xp = lvl_mgr.current_xp
	
	# Posición y Rotación
	save.global_position = creature_node.global_position
	save.global_rotation = creature_node.rotation
	
	# Guardamos sobrescribiendo el archivo
	var path = _get_save_path_by_id(selected_instance_id)
	ResourceSaver.save(save, path)
	
	# Actualizamos la memoria
	current_save_state = save
	print("¡Partida Guardada CORRECTAMENTE y sobrescrita en: ", path)

# --- FUNCIÓN DE BORRADO (La que pedía tu MainMenu) ---
func reset_all_data() -> void:
	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()
	
	player_data = PlayerData.new()
	save_player_profile()
	selected_instance_id = ""
	selected_creature = null
	current_save_state = null
	print("Sistema reseteado: Monedas, Compras y Partidas borradas.")

# --- MUERTE PERMANENTE (PERMADEATH) ---
func delete_current_save() -> void:
	if selected_instance_id == "": return
	
	# 1. Borramos el archivo físico .tres de la partida
	var path = _get_save_path_by_id(selected_instance_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		
	# 2. Quitamos a la criatura de la lista de posesiones del jugador
	for i in range(player_data.owned_instances.size() - 1, -1, -1):
		if player_data.owned_instances[i]["instance_id"] == selected_instance_id:
			player_data.owned_instances.remove_at(i)
			break
			
	# Guardamos el perfil actualizado (sin esa criatura)
	save_player_profile()
	
	# Limpiamos las variables actuales
	selected_instance_id = ""
	selected_creature = null
	current_save_state = null
	print("Partida borrada. La criatura ha muerto para siempre.")
