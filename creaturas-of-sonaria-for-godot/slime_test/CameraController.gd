class_name CameraController extends Node3D

# --- Variables de Cámara ---
@export var mouse_sensitivity: float = 0.003
@export var min_zoom: float = 2.0
@export var max_zoom: float = 10.0
@export var zoom_speed: float = 1.5
@export var zoom_smoothness: float = 8.0
@export var zoom_growth_factor: float = 0.1

var base_max_zoom: float = 3.0
var base_zoom_speed: float = 0.3
var target_zoom: float = 5.0
var player: Node3D
var cam_yaw: float = 0.0
var cam_pitch: float = 0.0
var is_internal_cam_active: bool = false
var internal_cam_speed: float = 6.0
var saved_target_zoom: float = 5.0
var internal_ray: RayCast3D
var gravity_hold_point: Marker3D
var grabbed_internal_item: ConsumableItem = null

@onready var spring_arm = $SpringArm3D

var tracking_target: Node3D = null
var default_offset: Vector3 = Vector3(0, 0.5, 0) # Altura normal de tu cámara cuando estás en el suelo

# ==========================================
# 🌀 MODO ORBITAL — absorbido de camera_pivot.gd (editor tipo Spore)
# ==========================================
# Reutiliza el mismo SpringArm3D/Camera3D que el modo de juego normal —
# get_camera() sigue devolviendo lo mismo sin importar el modo, así que
# BuildingSocketsManager no necesita saber cuál está activo. is_build_mode
# decide cuál de los dos corre en handle_input()/process_camera().

@export_group("Modo Orbital")
@export var orbital_target: Node3D # el "player_dummy" que se está armando
@export var orbital_rotation_speed: float = 0.005
@export var orbital_zoom_speed: float = 0.5
@export var orbital_min_zoom: float = 1.0
@export var orbital_max_zoom: float = 8.0
var is_orbital_rotating: bool = false

func _ready():
	player = get_parent() as Node3D
	spring_arm.spring_length = target_zoom
	base_max_zoom = max_zoom 
	base_zoom_speed = zoom_speed
	cam_yaw = global_transform.basis.get_euler().y
	cam_pitch = spring_arm.rotation.x
	top_level = true 
	internal_ray = RayCast3D.new()
	internal_ray.target_position = Vector3(0, 0, -10.0) 
	internal_ray.collision_mask = 513 
	internal_ray.collide_with_areas = false
	internal_ray.collide_with_bodies = true
	add_child(internal_ray)

func update_max_zoom_for_scale(mass_level: float):
	var zoom_multiplier: float = 1.0 + ((mass_level - 1.0) * zoom_growth_factor)
	max_zoom = base_max_zoom * zoom_multiplier
	zoom_speed = base_zoom_speed * zoom_multiplier

var is_build_mode: bool = false # setealo externamente si el cuerpo activo entra en modo construcción

func handle_input(event: InputEvent) -> void:
	if is_build_mode:
		_handle_orbital_input(event)
		return

	if event.is_action_pressed("press_tab"):
		toggle_internal_camera()
		
	# ==========================================
	# 🤿 SECUESTRO DE INPUT: MODO BUCEO
	# ==========================================
	if is_internal_cam_active:
		# Lógica del Gravity Gun
		if event.is_action_pressed("press_clickIZ"):
			if grabbed_internal_item == null:
				internal_ray.force_raycast_update()
				if internal_ray.is_colliding():
					var hit = internal_ray.get_collider()
					# Si es un objeto válido, simplemente lo agarramos
					if hit is ConsumableItem: 
						grabbed_internal_item = hit
						grabbed_internal_item.set_meta("is_grabbed_by_cam", true)
			else:
				# Si ya teníamos algo, lo soltamos donde esté
				grabbed_internal_item.set_meta("is_grabbed_by_cam", false)
				grabbed_internal_item = null

		# ROTACIÓN DESCONGELADA: Usamos las variables estándar
		if event is InputEventMouseMotion:
			cam_yaw -= event.relative.x * mouse_sensitivity
			cam_pitch -= event.relative.y * mouse_sensitivity
			
			# Límite para no rompernos el cuello (mirar arriba/abajo)
			cam_pitch = clamp(cam_pitch, -deg_to_rad(89), deg_to_rad(89))
			
		return
	
	# 1. Rotar el horizonte de la cámara con el ratón
	if event is InputEventMouseMotion:
		# Modificamos los acumuladores directos en vez de multiplicar transformaciones del nodo
		cam_yaw -= event.relative.x * mouse_sensitivity
		cam_pitch -= event.relative.y * mouse_sensitivity
		
		# Clampeamos el cabeceo vertical (para no dar la vuelta al revés de cabeza)
		cam_pitch = clamp(cam_pitch, deg_to_rad(-65), deg_to_rad(65))
	
	# 2. Controlar el Zoom objetivo
	if event.is_action_pressed("scroll_up"):
		target_zoom -= zoom_speed
	elif event.is_action_pressed("scroll_down"):
		target_zoom += zoom_speed
		
	target_zoom = clamp(target_zoom, min_zoom, max_zoom)

func _handle_orbital_input(event: InputEvent) -> void:
	# Idéntico a camera_pivot.gd — clic derecho para girar, rueda para zoom.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		is_orbital_rotating = event.pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if is_orbital_rotating else Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseMotion and is_orbital_rotating:
		rotate_y(-event.relative.x * orbital_rotation_speed)
		spring_arm.rotate_x(-event.relative.y * orbital_rotation_speed)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-85), deg_to_rad(85))

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = clamp(spring_arm.spring_length - orbital_zoom_speed, orbital_min_zoom, orbital_max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = clamp(spring_arm.spring_length + orbital_zoom_speed, orbital_min_zoom, orbital_max_zoom)

func process_camera(delta: float):
	if is_build_mode:
		_process_orbital_camera(delta)
		return

	# ==========================================
	# 🤿 1. INTERCEPCIÓN TOTAL: MODO BUCEO
	# ==========================================
	if is_internal_cam_active:
		# A. Movimiento libre con WASD
		var fly_dir = Vector3.ZERO
		var basis = global_transform.basis
		
		if Input.is_action_pressed("press_w"): fly_dir -= basis.z
		if Input.is_action_pressed("press_s"): fly_dir += basis.z
		if Input.is_action_pressed("press_a"): fly_dir -= basis.x
		if Input.is_action_pressed("press_d"): fly_dir += basis.x
		if Input.is_action_pressed("press_space"): fly_dir += Vector3.UP
		if Input.is_action_pressed("press_shift"): fly_dir -= Vector3.UP
		
		if fly_dir != Vector3.ZERO:
			global_position += fly_dir.normalized() * internal_cam_speed * delta
			
		# ==========================================
		# B. BARRERA DE VUELO AMPLIADA (Segura)
		# ==========================================
		var core_pos = Vector3.ZERO
		var current_radius = 2.0
		
		if is_instance_valid(player):
			core_pos = player.global_position + default_offset
			# ✅ Usamos las variables reales de tu slime_base para el tamaño
			current_radius = player.default_col_radius * player.current_liquid_scale
				
			var max_distance = max(2.5, current_radius + 3.0) 
			
			if global_position.distance_to(core_pos) > max_distance:
				var direction_to_core = core_pos.direction_to(global_position)
				global_position = core_pos + (direction_to_core * max_distance)
				
		# C. ROTACIÓN PURA
		global_transform.basis = Basis.from_euler(Vector3(cam_pitch, cam_yaw, 0))
		
		# D. Suavizado de Zoom a cero
		spring_arm.spring_length = lerp(spring_arm.spring_length, target_zoom, zoom_smoothness * delta)
		spring_arm.rotation = Vector3.ZERO
		
		# ==========================================
		# E. GRAVITY GUN UNIVERSAL (Transiciones Suaves)
		# ==========================================
		if is_instance_valid(grabbed_internal_item):
			var target_pos = global_position + (global_transform.basis * Vector3(0, 0, -2.5))
			var current_pos = grabbed_internal_item.global_position
			
			# 1. TRANSICIONES DE MUNDO (Adentro vs Afuera)
			if is_instance_valid(player) and player.has_node("InternalInventory"):
				var internal_inv = player.get_node("InternalInventory")
				var dist_from_core = current_pos.distance_to(core_pos)
				var is_inside_stomach = grabbed_internal_item in internal_inv.stored_items
				
				# 🚪 Entrar al estómago (Solo si no está ya adentro)
				if dist_from_core <= current_radius and not is_inside_stomach:
					var saved_pos = current_pos # Guardamos su posición real flotando
					if internal_inv.has_method("try_absorb_item"):
						internal_inv.try_absorb_item(grabbed_internal_item)
						# Cancelamos la teletransportación del script _absorb_into_mass
						grabbed_internal_item.global_position = saved_pos 
						
				# 🚪 Salir al mundo exterior (Solo si no está ya afuera)
				elif dist_from_core > current_radius + 1.0 and is_inside_stomach:
					if internal_inv.has_method("release_item_silently"):
						internal_inv.release_item_silently(grabbed_internal_item)
						# release_item_silently no teletransporta, así que es seguro

			# 2. APLICAR LEVITACIÓN (Después de la transición)
			# Actualizamos current_pos de nuevo por si la absorción cambió su estado
			current_pos = grabbed_internal_item.global_position 
			var direction = target_pos - current_pos
			var distance = direction.length()
			
			# Multiplicador de fuerza para que persiga a la cámara fluidamente
			grabbed_internal_item.linear_velocity = direction * (10.0 + distance * 5.0)
		
		# ⛔ RETORNAMOS PARA QUE NO SE EJECUTE LA CÁMARA NORMAL
		return
		
	# ==========================================
	# 🌲 2. CÁMARA NORMAL EN TERCERA PERSONA
	# ==========================================
	if not is_instance_valid(player):
		return # todavía no hay a quién seguir (ej. arranque, antes de register_home) — no hacer nada este frame

	if is_instance_valid(tracking_target):
		global_position = tracking_target.global_position
	else:
		global_position = player.global_position + default_offset
		
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_zoom, zoom_smoothness * delta)
	
	var surface_up = player.global_transform.basis.y
	var basis_surface = Basis()
	basis_surface.y = surface_up
	
	if abs(surface_up.dot(Vector3.UP)) < 0.99:
		basis_surface.x = Vector3.UP.cross(surface_up).normalized()
	else:
		basis_surface.x = surface_up.cross(Vector3.FORWARD).normalized()
		
	basis_surface.z = basis_surface.x.cross(basis_surface.y).normalized()
	basis_surface = basis_surface.orthonormalized()
	
	var target_basis = basis_surface
	target_basis = target_basis.rotated(target_basis.y, cam_yaw)   
	target_basis = target_basis.rotated(target_basis.x, cam_pitch) 
	
	global_transform.basis = target_basis
	spring_arm.rotation = Vector3.ZERO

# --- Funciones Utilitarias ---

func _process_orbital_camera(_delta: float) -> void:
	# Solo posición — la rotación en modo orbital se maneja directo sobre
	# self/spring_arm en _handle_orbital_input(), no con cam_yaw/cam_pitch.
	if is_instance_valid(orbital_target):
		global_position = global_position.lerp(orbital_target.global_position + Vector3(0, 1, 0), 0.1)

func retarget(new_player: Node3D) -> void:
	player = new_player
	tracking_target = null # por si venía de un seguimiento especial (ej. la punta del andamio)

func get_camera() -> Camera3D:
	return spring_arm.get_child(0) as Camera3D

func get_aim_direction() -> Vector3:
	var cam = spring_arm.get_child(0) as Camera3D
	if cam:
		return -cam.global_transform.basis.z.normalized()
	return -global_transform.basis.z.normalized()

func force_min_safe_zoom(safe_distance: float):
	target_zoom = max(target_zoom, safe_distance)

func toggle_internal_camera():
	is_internal_cam_active = !is_internal_cam_active
	if is_internal_cam_active:
		saved_target_zoom = target_zoom
		target_zoom = 0.0 # Retraemos el brazo mecánico por completo al núcleo
	else:
		if is_instance_valid(grabbed_internal_item):
			var extracted_item = grabbed_internal_item
			extracted_item.set_meta("is_grabbed_by_cam", false)
			grabbed_internal_item = null # Limpiamos la pinza
			
			if is_instance_valid(player):
				var internal_inv = player.get_node_or_null("InternalInventory")
				var consumer = player.get_node_or_null("ConsumerComponent")
				
				if internal_inv and consumer:
					# 1. Lo sacamos silenciosamente del estómago
					internal_inv.release_item_silently(extracted_item)
					# 2. Tu ConsumerComponent lo pone automáticamente en la cabeza
					consumer.place_on_head(extracted_item)
