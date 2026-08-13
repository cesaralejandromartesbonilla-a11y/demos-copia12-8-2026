extends Node3D

# Arrastra aquí tu nodo VoxelLodTerrain desde el editor
@export var terrain_node: VoxelLodTerrain
@export var player_node: CharacterBody3D # Necesario para el empuje
@export var max_reach: float = 15.0 # Límite de distancia

# Configuración del pincel
var brush_radius: float = 4.0
var brush_opacity: float = 1.0 # Velocidad de pintado

# Definimos los "Colores" que el shader entiende como texturas
# Rojo (R=1, G=0, B=0) -> Shader lo interpreta como Textura 0 (Roca/Tierra)
const COLOR_ROCK = Color(1.0, 0.0, 0.0) 

# Verde (R=0, G=1, B=0) -> Shader lo interpreta como Textura 1 (Pasto)
const COLOR_GRASS = Color(0.0, 1.0, 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if not terrain_node: return
	
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Clic Izquierdo: Excavar y dejar roca
			_modify_voxel(false)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Clic Derecho: Rellenar y poner pasto
			_modify_voxel(true)

func _modify_voxel(is_filling: bool) -> void:
	var tool = terrain_node.get_voxel_tool()
	if not tool: return

	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	var origin = camera.project_ray_origin(mouse_pos)
	var dir = camera.project_ray_normal(mouse_pos)
	
	# 1. LIMITAMOS EL ALCANCE usando max_reach
	var hit = tool.raycast(origin, dir, max_reach)
	
	if hit:
		var hit_pos_float = Vector3(hit.position) 
		var offset = hit.normal * (brush_radius * 0.5)
		var target_pos = hit_pos_float + (offset if is_filling else -offset)
		
		# --- LÓGICA DE EMPUJE (ANTIENTERRAMIENTO) ---
		if is_filling:
			var player_feet = player_node.global_position
			var dist_to_player = target_pos.distance_to(player_feet)
			
			# Si el centro del relleno está muy cerca del jugador
			if dist_to_player < brush_radius + 1.0:
				# Calculamos la dirección hacia donde empujar (hacia arriba y afuera)
				var push_dir = (player_feet - target_pos).normalized()
				if push_dir.length() < 0.1: push_dir = Vector3.UP # Failsafe
				
				# Movemos al jugador fuera del radio de la esfera
				var push_distance = (brush_radius + 1.2) - dist_to_player
				player_node.global_position += push_dir * push_distance
		
		# --- MODIFICAR FORMA ---
		tool.channel = VoxelBuffer.CHANNEL_SDF
		tool.mode = VoxelTool.MODE_ADD if is_filling else VoxelTool.MODE_REMOVE
		tool.do_sphere(target_pos, brush_radius)
			
		# --- MODIFICAR TEXTURA ---
		tool.channel = VoxelBuffer.CHANNEL_COLOR
		tool.mode = VoxelTool.MODE_SET 
		tool.value = (COLOR_GRASS if is_filling else COLOR_ROCK).to_abgr32()
		tool.do_sphere(target_pos, brush_radius + 1.0)
