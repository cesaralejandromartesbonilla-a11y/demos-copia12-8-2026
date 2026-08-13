#script del jugador
extends CharacterBody3D
class_name Player

var dir = Vector3.ZERO
var flashlight

@onready var voxel_lod_terrain: VoxelLodTerrain = get_tree().root.find_child("VoxelLodTerrain", true, false)
@onready var voxel_tool := voxel_lod_terrain.get_voxel_tool()
@onready var ray_cast_3d: RayCast3D = $Camera/RayCast3D

const HOOK_AVAILIBLE_TEXTURE = preload("res://hook_availible.png")
const HOOK_NOT_AVAILIBLE_TEXTURE = preload("res://hook_not_availible.png")

@onready var camera := $Camera
@onready var hook_raycast: RayCast3D = $"Camera/Hook Raycast"
@onready var crosshair: TextureRect = $HUD/Crosshair
@export var rdm: float #Radio De Minado
@export var movement_speed := 2.0
@export var friction_ground := 0.8
@export var friction_air := 0.85
@export var jump_force := 10.0
@export var gravity := 0.5
@export var mouse_sensetivity := 3.0
@onready var hook_controller: HookController = $HookController

var tierra_acumulada: float = 0.0 # Cantidad de tierra en la pala/inventario
const CAPACIDAD_MAX = 50.0
@export var terreno_path : NodePath
@export var tierra_escena : PackedScene # Aquí arrastras tu TierraFisica.tscn en el inspector
@onready var raycast = $Camera/RayCast3D # Asegúrate de tener un RayCast3D mirando al frente
@export var snow_size := Vector2(1.0, 1.0)
@export var dinero_jugador: int 
@onready var punto_spawn = $"../SpawnPoint" # Asegúrate de tener un Marker3D como hijo

func _find_voxel_terrain_recursive(node: Node) -> VoxelLodTerrain:
	if node is VoxelLodTerrain:
		return node
	for child in node.get_children():
		var found = _find_voxel_terrain_recursive(child)
		if found: return found
	return null

# ——————————————————————————————
# LÓGICA DE ESPERA (ANTI-VACÍO)
# ——————————————————————————————
func esperar_terreno_listo():
	# 1. Congelar físicas pero NO el proceso del Voxel
	set_physics_process(false)
	
	var intentos = 0
	# Reducimos el tamaño de la caja de colisión para que sea más rápido validar
	var box = AABB(global_position - Vector3(0.5, 0.5, 0.5), Vector3(1, 1, 1))
	
	while intentos < 200: # Reducimos intentos máximos
		if voxel_tool and voxel_tool.is_area_editable(box):
			break
		
		# En lugar de esperar 1 frame, esperamos un poquito más para no saturar la CPU
		await get_tree().create_timer(0.05).timeout 
		intentos += 1
	
	set_physics_process(true)

func configurar_guardado_terreno():
	if voxel_lod_terrain:
		# Usamos SQLite para que el guardado sea rápido y automático
		var stream = VoxelStreamSQLite.new()
		stream.database_path = "user://mundo_voxel.db"
		voxel_lod_terrain.stream = stream
		
		print("Geometría del terreno vinculada a mundo_voxel.db")


# ——————————————————————————————
# FÍSICA (solo si está a pie)
# ——————————————————————————————

func _physics_process(delta: float) -> void:
	
	if Global.estado == 0: return
		
	# Detectar si estamos dentro de algo sólido (VoxelTerrain)
	if voxel_tool.get_voxel(global_position) < 0: # En SDF, valores negativos son sólidos
		global_position.y += 0.5 # Teletransporte suave hacia arriba hasta salir
	
	var _moving = false
	# Add the gravity. Pulls value from project settings.
	if not is_on_floor():
		velocity.y -= gravity * delta

	var target_pos = ray_cast_3d.get_collision_point()
	if ray_cast_3d.is_colliding():
		target_pos = ray_cast_3d.get_collision_point()
	else:
		target_pos = ray_cast_3d.global_position - ray_cast_3d.global_basis.z * 5
	if Input.is_action_just_pressed("click_right"): 
		soltar_tierra_fisica()
	# EXCAVAR
# Dentro de _physics_process en player.gd
	if Input.is_action_just_pressed("click_left"):
		if ray_cast_3d.is_colliding():
			
			# Usamos un margen un poco más grande para la comprobación
			var check_box = AABB(target_pos - Vector3(0.5, 0.5, 0.5), Vector3(1, 1, 1))
			
			if voxel_tool.is_area_editable(check_box):
				if tierra_acumulada < CAPACIDAD_MAX:
					tierra_acumulada += 1.0
					excavar(target_pos)
			else:
				# Si sale mucho este mensaje, el VoxelViewer no está funcionando
				print("Aviso: El terreno en ", target_pos, " aún no está listo para edición.")
	
	if Input.is_action_just_pressed("null"):
		voxel_tool.texture_index = posmod(voxel_tool.texture_index+1,3)
	
	# Horizontal movement
	var movement_direction: Vector2 = Input.get_vector("press_a", "press_d", "press_s", "press_w")
	var movement_vector: Vector3 = (transform.basis * Vector3(movement_direction.x, 0, -movement_direction.y)).normalized()
	
	velocity += movement_vector * movement_speed * delta * 60
	
	match is_on_floor():
		true: velocity *= Vector3(friction_ground, 1, friction_ground)
		false: velocity *= Vector3(friction_air, 1, friction_air)
	
	# Gravity & Jumping
	if not is_on_floor():
		velocity.y -= gravity
	
	elif Input.is_action_pressed("press_space"):
		velocity.y = jump_force
	
	move_and_slide()
		# UI
	crosshair.texture = HOOK_AVAILIBLE_TEXTURE if hook_raycast.is_colliding() and not hook_controller.is_hook_launched else HOOK_NOT_AVAILIBLE_TEXTURE
	# RED DE SEGURIDAD: Si caes al vacío, te devuelve arriba
	if global_position.y < -100:
		print("¡Caída al vacío detectada! Respawneando...")
		global_position.y = 200 # Te devuelve al cielo
		velocity = Vector3.ZERO
	# Nos avisará si estamos cayendo al vacío
	if global_position.y < -50:
		print("ALERTA: Jugador cayendo al vacío en: ", global_position)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation_degrees.y -= event.relative.x * 0.06 * mouse_sensetivity
		
		camera.rotation_degrees.x -= event.relative.y * 0.06 * mouse_sensetivity
		
		camera.rotation_degrees.x = clamp(camera.rotation_degrees.x, -90, 90)

# ——————————————————————————————
# INICIALIZACIÓN
# ——————————————————————————————

func _ready() -> void:
	
	# 1. Configuración forzada del VoxelViewer
	var viewer = $VoxelViewer # Ajusta la ruta si es necesario
	if viewer:
		viewer.view_distance = 512
		viewer.requires_visuals = true
		viewer.requires_collisions = true
		viewer.set_process(true)
		print("VoxelViewer activado y configurado.")
	
	# 2. Buscar terreno y esperar (Código anterior corregido)
	var terrains = get_tree().get_nodes_in_group("voxel_terrains")
	if terrains.size() > 0:
		voxel_lod_terrain = terrains[0]
		configurar_guardado_terreno()
	 
		# AQUÍ ESTÁ EL TRUCO PARA LA PANTALLA GRIS
		await esperar_terreno_listo() 
	
	_set_state(PlayerState.ON_FOOT)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if terrains.size() > 0:
		voxel_lod_terrain = terrains[0]
	else:
		voxel_lod_terrain = _find_voxel_terrain_recursive(get_tree().root)
	
	if voxel_lod_terrain:
		voxel_tool = voxel_lod_terrain.get_voxel_tool()
		# Activamos el guardado persistente (SQLite)
		configurar_guardado_terreno()
		await esperar_terreno_listo()
	
	else:
		push_error("¡No se encontró ningún VoxelLodTerrain en la escena!")
# Función auxiliar para buscar el terreno si no usas grupos
		
		
	_set_state(PlayerState.ON_FOOT)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
# Estados
enum PlayerState { ON_FOOT, IN_VEHICLE }
var current_state: PlayerState = PlayerState.ON_FOOT

# Referencia al vehículo actual (si está montado)
@export var current_vehicle: Node3D = null

# ——————————————————————————————
# INPUT (siempre activo, incluso en vehículo)
# ——————————————————————————————
func _input(event):
	if event.is_action_pressed("press_bar"):
		$"../VBoxContainer".visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		$"../VBoxContainer".visible = true
	if event.is_action_pressed("press_midle"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("press_e"):
		if current_state == PlayerState.IN_VEHICLE:
			on_player_unmounted()
		elif current_state == PlayerState.ON_FOOT:
			_try_enter_nearest_vehicle()

# ——————————————————————————————
# MÁQUINA DE ESTADOS
# ——————————————————————————————
func _set_state(new_state: PlayerState):
	current_state = new_state # Actualizar variable primero
	
	match new_state:
		PlayerState.ON_FOOT:
			Global.estado = 1
			set_physics_process(true)
			# Despertar el nodo de física si estaba dormido
			if is_inside_tree():
				process_mode = PROCESS_MODE_INHERIT 

		PlayerState.IN_VEHICLE:
			Global.estado = 0
			set_physics_process(false)

	current_state = new_state

# ——————————————————————————————
# ENTRAR AL VEHÍCULO
# ——————————————————————————————
func _try_enter_nearest_vehicle():
	const MAX_DIST = 4.0
	var nearest: Node3D = null
	var best_dist = MAX_DIST

	for vehicle in get_tree().get_nodes_in_group("vehicles"):
		if vehicle.has_method("can_mount") and vehicle.can_mount():
			var dist = global_position.distance_to(vehicle.global_position)
			if dist < best_dist:
				best_dist = dist
				nearest = vehicle

	if nearest:
		_enter_vehicle(nearest)
		Global.estado = 0



func _enter_vehicle(vehicle: Node3D):
	current_vehicle = vehicle
	
	collision_layer = 0
	collision_mask = 0
	
	# Solo llama al estado, él se encarga de apagar la física
	_set_state(PlayerState.IN_VEHICLE)
	
	reparent.call_deferred(vehicle)
	vehicle.on_player_mounted(self)

	var mount = vehicle.get_node_or_null("MountPoint_Player")
	if mount:
		await get_tree().process_frame
		global_transform = mount.global_transform

# ——————————————————————————————
# SALIR DEL VEHÍCULO
# ——————————————————————————————
func on_player_unmounted():
	# 1. VERIFICACIÓN: Si no hay vehículo, no hacemos nada
	if current_vehicle == null:
		return

	# 2. CAPTURAR DATOS ANTES DE DESCONECTAR
	# Buscamos el punto de salida mientras current_vehicle aún es válido
	var exit = current_vehicle.get_node_or_null("ExitPoint_Player")
	var vehicle_ref = current_vehicle # Referencia temporal segura
	
	# 3. CAMBIO DE PADRE Y ESTADO
	reparent.call_deferred(get_tree().current_scene)
	
	collision_layer = 1
	collision_mask = 1
	Global.estado = 1 
	_set_state(PlayerState.ON_FOOT)
	velocity = Vector3.ZERO
	
	# 4. ESPERAR PROCESAMIENTO
	await get_tree().process_frame 
	
	# 5. POSICIONAR Y LIMPIAR ROTACIÓN
	if is_instance_valid(exit):
		global_position = exit.global_position
	else:
		global_position = vehicle_ref.global_position + Vector3(0, 2, 2)
	
	# Resetear rotación para no volar
	var y_rot = global_transform.basis.get_euler().y
	global_transform.basis = Basis.from_euler(Vector3(0, y_rot, 0))

	# 6. NOTIFICAR AL VEHÍCULO Y LIMPIAR
	if vehicle_ref.has_method("on_player_unmounted"):
		vehicle_ref.on_player_unmounted()
	
	current_vehicle = null # ÚLTIMO PASO

#sistema de tienda================================================================================

func comprar_item(item: Item):
	# BUSCAMOS AL JUGADOR EN TIEMPO REAL
	var player = get_tree().get_first_node_in_group("player")
	
	if item == null: 
		print("Error: El ítem recibido es nulo")
		return
	
	if player == null: 
		print("Error: No hay jugador para comprar")
		return
	
	if player.dinero_jugador >= item.precio:
		player.dinero_jugador -= item.precio
		var instancia = item.escena_visual.instantiate()
		get_tree().current_scene.add_child(instancia)
		instancia.global_position = punto_spawn.global_position
		
		# IMPORTANTE: Añadir al grupo para que se guarde el vehículo
		instancia.add_to_group("save_transform") 
		print("Comprado: ", item.nombre, ". Dinero restante: ", dinero_jugador)
	else:
		print("No tienes suficiente dinero para: ", item.nombre)

		
	#if dinero_jugador >= item.precio:
		#dinero_jugador -= item.precio
		#var instancia = item.escena_visual.instantiate()
		#get_tree().current_scene.add_child(instancia)
		#instancia.global_position = punto_spawn.global_position
		#add_to_group("save_transform")
		#print("Comprado: ", item.nombre, ". Dinero restante: ", dinero_jugador)
	#else:
		#print("No tienes suficiente dinero para: ", item.nombre)

func save_instanced_objects(data: SaveGame):
	data.dynamic_objects.clear() # Limpiar antes de guardar
	
	# Buscamos todos los RigidBody que compraste
	# Asumo que les pusiste el grupo "save_transform" como vi en tu código
	var objects_to_save = get_tree().get_nodes_in_group("save_transform")
	
	for obj in objects_to_save:
		var dict = {
			"scene_path": obj.scene_file_path,
			"pos": obj.global_position,
			"rot": obj.global_rotation,
			"linear_vel": obj.linear_velocity if obj is RigidBody3D else Vector3.ZERO
		}
		data.dynamic_objects.append(dict)

func load_instanced_objects(data: SaveGame):
	# 1. Borrar los actuales para no duplicar
	for old_obj in get_tree().get_nodes_in_group("save_transform"):
		old_obj.queue_free()
		
	# 2. Recrear desde el recurso
	for item_data in data.dynamic_objects:
		var scene = load(item_data["scene_path"])
		var instance = scene.instantiate()
		
		get_tree().current_scene.add_child(instance)
		
		instance.global_position = item_data["pos"]
		if instance is RigidBody3D:
			instance.linear_velocity = item_data["linear_vel"]
		
		instance.add_to_group("save_transform")


func _on_area_3d_body_entered(_body: Node3D) -> void:
	if CharacterBody3D:
		$Control.visible = true   # Aparece
		print("entro")


func _on_area_3d_body_exited(_body: Node3D) -> void:
	$Control.visible = false  # Desaparece
	print("salio")


func set_inventory(value):
	dinero_jugador = value

func consume_battery():
	set_inventory(dinero_jugador + 100)

func consume_coin():
	set_inventory(dinero_jugador + 500)

#============================================================================================================================================
# save player
#============================================================================================================================================

func save_data(data: SaveGame):
	data.player_pos = global_position
	data.player_rot = rotation # Rotación del cuerpo (Y)
	# GUARDAMOS LA ROTACIÓN DE LA CÁMARA (X)
	data.camera_rot = camera.rotation 
	# ERROR CORREGIDO: Antes hacías dinero = data.dinero
	data.dinero = dinero_jugador 
	return data

func load_data(data: SaveGame):
	global_position = data.player_pos
	rotation = data.player_rot
	# CARGAMOS LA ROTACIÓN DE LA CÁMARA
	if "camera_rot" in data:
		camera.rotation = data.camera_rot
	dinero_jugador = data.dinero


#generar tierra suelta =============================================================================

# --- FUNCIÓN EXCAVAR ACTUALIZADA ---
func excavar(pos: Vector3):
	# Leer el tipo de textura antes de borrar (Canal TYPE o INDICES)
	var material_id = voxel_tool.get_voxel(pos) 
	
	
	voxel_tool.do_sphere(pos, rdm ) # Borrar
	
	#esto es para generar tierra o piedra al excavar 
	#var piedra = tierra_escena.instantiate()
	#get_tree().root.add_child(piedra)
	#piedra.global_position = pos
	#piedra.configurar_material(material_id) # Le pasamos el color

	voxel_tool.channel = VoxelBuffer.CHANNEL_SDF 
	voxel_tool.mode = VoxelTool.MODE_REMOVE
	voxel_tool.value = 1.0
	
	#es para generar tierra cada vez que se escaba==============================
	#if tierra_escena:
		#var nueva_tierra = tierra_escena.instantiate()
		#get_tree().root.add_child(nueva_tierra)
		#nueva_tierra.global_position = pos + Vector3(0, 0.5, 0)
		
		# IMPORTANTE: Para que la tierra física no genere más tierra
		# Asegúrate de que el RayCast3D ignore los objetos de "TierraFisica"
		# poniéndolos en una Collision Layer diferente (ej. Capa 3).

func soltar_tierra_fisica():
	if tierra_escena:
		var piedra = tierra_escena.instantiate()
		get_tree().root.add_child(piedra)
		
		# Aparece frente al jugador (a la altura de la cámara/pala)
		var spawn_pos = $Camera.global_position - $Camera.global_basis.z * 1.5
		piedra.global_position = spawn_pos
		
		# Le damos un pequeño impulso hacia adelante para que no caiga en nuestros pies
		if piedra is RigidBody3D:
			var direccion = -$Camera.global_basis.z
			piedra.apply_central_impulse((direccion + Vector3(0, 0.5, 0)) * 5.0)

# En player.gd

func activar_modo_fantasma_temporal(tiempo: float = 0.5):
	print("👻 Iniciando Modo Fantasma (Sin colisiones ni gravedad)")
	
	# 1. Desactivar colisión (te vuelve intangible)
	# Usamos set_deferred para evitar errores de físicas
	$CollisionShape3D.set_deferred("disabled", true)
	
	# 2. Desactivar gravedad y movimiento (te congela)
	set_physics_process(false)
	velocity = Vector3.ZERO
	
	# 3. Esperar el tiempo indicado (ej. 0.5 segundos)
	await get_tree().create_timer(tiempo).timeout
	
	# 4. Reactivar todo
	$CollisionShape3D.set_deferred("disabled", false)
	set_physics_process(true)
	
	print("🛡️ Modo Fantasma terminado. Físicas activas.")
