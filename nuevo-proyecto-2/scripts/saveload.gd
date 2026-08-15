#saveload.gd
extends Node

# Use ".tres" if you want human readable file
# File paths are described in:
# https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html
var file_template = "user://%s.res"
var file_config = "res://config.cfg"
var file_config_default = "res://configs_default.cfg"
var loaded_data: SaveGame = null
var config = ConfigFile.new()
@onready var voxel_lod_terrain: VoxelLodTerrain = get_tree().root.find_child("VoxelLodTerrain", true, false)

## SAVES
# You can easily implement multiple files system
# or custom file names by supplying different file_name.
# It can also be used to implement autosave or quicksave
# by naming files accordingly.
# For example, save files can be named 2023-10-03-12-58-00-(auto)save.tres,
# whereas single quicksave file will be quicksave.tres

func game_save(file_name):
	# Show overlay
	get_node("/root/ArcadeDemo/Overlay").show()
	get_node("/root/ArcadeDemo/Overlay/Back/Label").text = "SAVING..."
	
	# Create a new resource
	var save_data = SaveGame.new()
	# Fill it with data
	# You can Fill it from here or send to several other classes
	save_data = get_node("/root/ArcadeDemo").save_data(save_data)
	
	# You can use ResourceSaver.FLAG_COMPRESS as a third argument
	var result = ResourceSaver.save(save_data, file_template % file_name)
	if result == OK:
		print("Saved game to " + file_template % file_name + "!")
	else:
		print("Error saving file!")
	
	# Hide overlay
	await get_tree().create_timer(0.5).timeout
	get_node("/root/ArcadeDemo/Overlay").hide()


func game_load(file_name):
	# Check if file exists
	if ResourceLoader.exists(file_template % file_name):
		# Show overlay
		get_node("/root/ArcadeDemo/Overlay").show()
		get_node("/root/ArcadeDemo/Overlay/Back/Label").text = "LOADING..."
		
		# Load file
		var save_data = ResourceLoader.load(file_template % file_name)
		# Check if file is loaded correctly as a resource of a needed type
		if save_data is SaveGame:
			print("Loaded game!")
			
			# Put loaded data into persistent static variable
			loaded_data = save_data
			
			# Reload scene (it will load all the data on ready)
			await get_tree().create_timer(0.5).timeout
			get_tree().reload_current_scene()
		else:
			print("Error loading!")
	else:
		print("File not found!")


## CONFIGS
# Config file is not saved with the game,
# because it is normally saved each time you change settings
# in the game's menu.


func config_save():
	# Just saving config file
	var result = config.save(file_config)
	if result != OK:
		print("Config saving error!")
	

# Datos del Jugador
@export var player_pos: Vector3
@export var player_rot: Vector3
@export var dinero: int

# Lista para objetos instanciados (Camiones, cajas, etc.)
@export var dynamic_objects: Array[Dictionary] = []

const SAVE_PATH = "user://partida.res"

# --- CONFIGURACIÓN ---
# CAMBIA ESTO: Pon la ruta real de tu escena de jugador .tscn
var player_scene = preload("res://player.tscn") 

func full_save():
	print("💾 Iniciando guardado...")
	var data = savegame.new()
	var player = get_tree().get_first_node_in_group("player")
	
	# 1. Datos del Jugador
	if player:
		data.player_pos = player.global_position
		data.player_rot = player.global_rotation
		if "dinero" in player: data.dinero = player.dinero
	
	# 2. Objetos Dinámicos (Vehículos/Trucks)
	var objects = get_tree().get_nodes_in_group("save_transform")
	for obj in objects:
		if obj.is_in_group("player"): continue # No duplicar al jugador
		
		var dict = {
			"scene": obj.scene_file_path,
			"pos": obj.global_position,
			"rot": obj.global_rotation
		}
		if obj is RigidBody3D: dict["vel"] = obj.linear_velocity
		data.dynamic_objects.append(dict)
	
	ResourceSaver.save(data, SAVE_PATH)
	if voxel_lod_terrain: voxel_lod_terrain.save_modified_blocks()
	print("✅ Juego Guardado en: ", data.player_pos)

func full_load():
	if not ResourceLoader.exists(SAVE_PATH): 
		print("❌ No hay archivo de guardado.")
		return
	
	var data = ResourceLoader.load(SAVE_PATH)
	if not data is savegame: return

	Loading.show_message("RECONSTRUYENDO MUNDO...")

	# TRUCO PRO: Teletransportar el Viewer ANTES de todo
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var viewer = player.get_node_or_null("VoxelViewer")
		if viewer:
			# Movemos solo el viewer a la posición final para que el terreno 
			# empiece a trabajar en segundo plano mientras instanciamos coches
			viewer.global_position = data.player_pos 

	# 1. LIMPIEZA: Borrar vehículos viejos (pero NO al jugador si ya existe)
	for old in get_tree().get_nodes_in_group("save_transform"):
		if not old.is_in_group("player"):
			old.queue_free()

	# 2. GESTIÓN DEL JUGADOR
	
	if player == null:
		print("🕵️ Player no encontrado. Creando nuevo desde .tscn...")
		player = player_scene.instantiate()
		get_tree().current_scene.add_child(player)
	
	# 3. POSICIONAMIENTO Y MODO FANTASMA
	# Lo ponemos un poco elevado para que no se entierre
	player.global_position = data.player_pos + Vector3(0, 0.5, 0)
	
	if player.has_method("activar_modo_fantasma_temporal"):
		player.activar_modo_fantasma_temporal(1.5) # Le damos tiempo a que carguen los vehículos

	# 4. RE-INSTANCIAR VEHÍCULOS
	for item in data.dynamic_objects:
		if ResourceLoader.exists(item["scene"]):
			var scn = load(item["scene"])
			var inst = scn.instantiate()
			get_tree().current_scene.add_child(inst)
			inst.global_position = item["pos"]
			inst.global_rotation = item["rot"]
			inst.add_to_group("save_transform")
			if inst is RigidBody3D and "vel" in item:
				inst.linear_velocity = item["vel"]

	# 5. CÁMARA: Forzar reset para evitar el "Palo Selfie"
	var cam = player.get_node_or_null("Camera") 
	if cam:
		cam.rotation = Vector3.ZERO
		cam.make_current()

	# 6. ESPERA DE TERRENO (Tu función de seguridad)
	if player.has_method("esperar_suelo_seguro"):
		await player.esperar_suelo_seguro()

	print("✅ CARGA COMPLETA. Player en tree: ", player.is_inside_tree())
	Loading.hide_screen()
	if data:
		print("CARGANDO -> Posición recuperada del archivo: ", data.player_pos)
		
		if player:
			player.global_position = data.player_pos
			print("Jugador teletransportado a: ", player.global_position)
			
			# FORZAMOS ALTURA SI ESTÁ MUY BAJO
			if player.global_position.y < 0:
				print("AVISO: La posición cargada es bajo tierra. Corrigiendo altura...")
				player.global_position.y = 50 # Lo subimos al cielo para que caiga a salvo
