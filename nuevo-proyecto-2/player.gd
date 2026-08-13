extends CharacterBody3D

@export_group("Planetas")
@export var debug_planet: Node3D 

@export_group("Movimiento")
@export var speed := 8.0
@export var jump_force := 12.0
@export var gravity_force := 20.0
@export var acceleration := 8.0
@export var friction := 10.0

@export_group("Cámara")
@export var mouse_sensitivity := 0.002
@export var min_pitch := -80.0
@export var max_pitch := 60.0
@export var zoom_speed := 0.5
@export var min_zoom := 1.5
@export var max_zoom := 10.0


@onready var camera_mount: Node3D = $CameraMount
@onready var spring_arm: SpringArm3D = $CameraMount/SpringArm3D
@onready var visuals: Node3D = $Visuals
@onready var backpack_ui_root: Node3D = $Visuals/Mochila # Ajusta la ruta a tu mochila
@onready var camera: Camera3D = $CameraMount/SpringArm3D/Camera3D # Ajusta la ruta a tu cámara

@export_group("Herramientas")
@export var tool_model: Node3D 
var is_tool_active := false

# Acumuladores de cámara
var cam_rot_h := 0.0 
var cam_rot_v := 0.0 
var is_rotating_camera := false

var target_planet_center := Vector3.ZERO
var is_inventory_mode := false
var held_item: Node3D = null 
var current_hovered_item: Node3D = null 

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	spring_arm.add_excluded_object(self.get_rid())
	
	# Aseguramos que no haya rotaciones residuales en el editor
	visuals.top_level = false 
	camera_mount.top_level = false

func _unhandled_input(event: InputEvent) -> void:
# TOGGLE INVENTARIO (Tecla TAB o Q)
	if event.is_action_pressed("press_tab"): # Configura "toggle_inventory" en InputMap
		toggle_inventory_mode()
		return
		# Si estamos en modo inventario, NO rotamos la cámara con el ratón
	#if is_inventory_mode:
		#Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		#return
	# Click derecho para activar cámara
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_rotating_camera = true
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				is_rotating_camera = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Movimiento del ratón
	if event is InputEventMouseMotion and is_rotating_camera:
		cam_rot_h -= event.relative.x * mouse_sensitivity
		cam_rot_v -= event.relative.y * mouse_sensitivity
		cam_rot_v = clamp(cam_rot_v, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
	# (Asegúrate de meter tu lógica anterior dentro de un "else" o comprobar !is_inventory_mode)
	# ZOOM DE CÁMARA (Rueda del ratón)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = clamp(spring_arm.spring_length - zoom_speed, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = clamp(spring_arm.spring_length + zoom_speed, min_zoom, max_zoom)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target = get_object_under_mouse()
		
		# CASO A: No tienes nada en la mano e intentas agarrar algo
		if held_item == null:
			if target and target.is_in_group("items"):
				grab_item(target)
		
		# CASO B: Tienes algo en la mano e intentas interactuar
		else:
			if target and target.is_in_group("slots"):
				try_place_in_slot(target)
			else:
				drop_item()
	if event.is_action_pressed("press_e"):
		toggle_tool_mode()

func _process(delta: float) -> void:
	if held_item:
		var mouse_pos = get_viewport().get_mouse_position()
		var target_pos = camera.project_position(mouse_pos, 4.0)
		held_item.global_position = held_item.global_position.lerp(target_pos, 0.2)
		
		# Si tenemos algo en la mano, quitamos el resaltado de cualquier otra cosa
		if current_hovered_item:
			if is_instance_valid(current_hovered_item) and current_hovered_item.has_method("set_highlight"):
				current_hovered_item.set_highlight(false)
			current_hovered_item = null
	
	# --- NUEVA LÓGICA DE DETECCIÓN (HOVER) ---
	# Solo detectamos si NO tenemos nada en la mano y NO estamos girando la cámara
	elif not is_rotating_camera:
		var target = get_object_under_mouse()
		
		# Si apuntamos a algo nuevo
		if target != current_hovered_item:
			
			# 1. Apagamos el objeto anterior (si había uno)
			if current_hovered_item and is_instance_valid(current_hovered_item):
				if current_hovered_item.has_method("set_highlight"):
					current_hovered_item.set_highlight(false)
			
			# 2. Guardamos el nuevo objeto
			current_hovered_item = target
			
			# 3. Encendemos el nuevo objeto (si es un Item)
			if current_hovered_item and current_hovered_item.is_in_group("items"):
				if current_hovered_item.has_method("set_highlight"):
					current_hovered_item.set_highlight(true)

func _physics_process(delta: float) -> void:
	# 1. ACTUALIZAR FUENTE DE GRAVEDAD
	update_gravity_source()
	
	var planet_up = (global_position - target_planet_center).normalized()
	
	# Parche de seguridad (centro del mundo)
	if (global_position - target_planet_center).length_squared() < 1.0: 
		planet_up = Vector3.UP
	
	# --- CORRECCIÓN DE ALINEACIÓN (ANTI-VIBRACIÓN) ---
	# En lugar de Slerp agresivo, usamos Quaternions para alinear suavemente
	# el eje Y del jugador con el eje del planeta sin tocar los otros ejes bruscamente.
	align_up_with_planet(planet_up)

	# 2. GRAVEDAD
	if not is_on_floor():
		velocity += -planet_up * gravity_force * delta

	# 3. SALTO
	if Input.is_action_just_pressed("press_space") and is_on_floor():
		velocity += planet_up * jump_force

	# 4. MOVIMIENTO
	# Importante: Usamos la base del CameraMount que ahora rota solidariamente con el Player
	var input_dir = Input.get_vector("press_a", "press_d", "press_s", "press_w")
	var move_dir = Vector3.ZERO
	
	if input_dir != Vector2.ZERO:
		# La cámara es hija del Player, así que su 'basis' ya es relativa al planeta.
		var cam_basis = camera_mount.global_transform.basis
		
		# Proyectamos la dirección de la cámara sobre el plano del suelo
		var forward = -cam_basis.z.slide(planet_up).normalized()
		var right = cam_basis.x.slide(planet_up).normalized()
		
		move_dir = (forward * input_dir.y + right * input_dir.x).normalized()
		
		# Rotar visuales (El modelo 3D) hacia donde caminas
		if move_dir.length_squared() > 0.01:
			var current_quat = visuals.global_transform.basis.get_rotation_quaternion()
			# Creamos una base mirando hacia move_dir, pero con UP = planet_up
			var target_basis = Basis.looking_at(move_dir, planet_up)
			var target_quat = target_basis.get_rotation_quaternion()
			
			# Interpolación suave solo visual
			visuals.global_transform.basis = Basis(current_quat.slerp(target_quat, 0.2))

	# 5. APLICAR VELOCIDAD
	var v_vert = velocity.project(planet_up)
	var v_horiz = velocity - v_vert
	
	if move_dir:
		v_horiz = v_horiz.move_toward(move_dir * speed, acceleration * delta)
	else:
		v_horiz = v_horiz.move_toward(Vector3.ZERO, friction * delta)
	
	velocity = v_vert + v_horiz
	
	# Seteamos el "Up Direction" para que move_and_slide sepa qué es suelo
	up_direction = planet_up
	move_and_slide()
	
	# --- CÁMARA (Lógica Local) ---
	# Actualizamos la cámara AQUÍ o en _process, pero usando rotación local
	camera_mount.rotation = Vector3.ZERO # Reseteamos rotación local
	camera_mount.rotate_object_local(Vector3.UP, cam_rot_h) # Giramos sobre SU eje Y (que es el del planeta)
	spring_arm.rotation = Vector3.ZERO
	spring_arm.rotate_object_local(Vector3.RIGHT, cam_rot_v)
	if held_item:
		var mouse_pos = get_viewport().get_mouse_position()
		var target_pos = camera.project_position(mouse_pos, 4.0) # Flota a 4 metros de la cámara
		held_item.global_position = held_item.global_position.lerp(target_pos, 0.2)

# --- FUNCIÓN MAGICA DE ALINEACIÓN ---
func align_up_with_planet(new_up: Vector3):
	# Esta función evita el jitter alineando solo lo necesario
	var current_up = global_transform.basis.y
	
	# Si ya estamos alineados, no hacemos nada (ahorra cálculos y vibración)
	if current_up.is_equal_approx(new_up):
		return
		
	# Calculamos el quaternion que rota de "current_up" a "new_up"
	var axis = current_up.cross(new_up)
	if axis.length_squared() < 0.0001: 
		return # Son paralelos
	axis = axis.normalized()
	
	var angle = current_up.angle_to(new_up)
	var correction_quat = Quaternion(axis, angle)
	
	# Aplicamos la rotación a la base actual
	global_transform.basis = Basis(correction_quat) * global_transform.basis
	
	# Orto-normalizamos para evitar deformaciones con el tiempo
	global_transform.basis = global_transform.basis.orthonormalized()

func update_gravity_source():
	if debug_planet:
		target_planet_center = debug_planet.global_position
		return

	var planetas = get_tree().get_nodes_in_group("planetas")
	if planetas.is_empty(): return
	
	var closest = planetas[0]
	var d_min = global_position.distance_to(closest.global_position)
	
	for p in planetas:
		var d = global_position.distance_to(p.global_position)
		if d < d_min:
			d_min = d
			closest = p
	target_planet_center = closest.global_position

func toggle_inventory_mode():
	is_inventory_mode = !is_inventory_mode
	if is_inventory_mode:
		is_tool_active = false # Guardar herramienta si abres mochila
		if tool_model: tool_model.hide()
	is_inventory_mode = !is_inventory_mode
	
	var target_zoom = 2.0 if is_inventory_mode else 6.0
	
	# Usamos un Tween para que la transición sea suave
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(spring_arm, "spring_length", target_zoom, 0.4)
	
	if is_inventory_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# Opcional: podrías orientar al jugador un poco para que la mochila se vea mejor
	else:
		# Si no estamos rotando cámara, el ratón sigue visible para interactuar
		if not is_rotating_camera:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func get_object_under_mouse():
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 20.0
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	
	# IMPORTANTE: Detectar AMBOS para que funcionen Slots (Areas) e Items (Bodies)
	query.collide_with_areas = true 
	query.collide_with_bodies = true 
	
	var result = space_state.intersect_ray(query)
	print(held_item)
	return result.get("collider", null)
	
	# ACTIVAR AMBOS:
	query.collide_with_areas = true  # Para los slots (Area3D)
	query.collide_with_bodies = true # Para los items (RigidBody3D)
	
	# Excluir al propio jugador para que el rayo no choque con tu casco
	query.exclude = [self.get_rid()] 
	
	if result:
		print("Raycast golpeó a: ", result.collider.name, " en grupo: ", result.collider.get_groups())
		return result.collider
	return null


func grab_item(item):
	held_item = item
	held_item.set_physics_state(false) # Desactivar colisiones para que no choque contigo
	if held_item.get_parent().has_method("remove_item"): # Si estaba en un slot, avisar al slot
		held_item.get_parent().remove_item()

func drop_item():
	if held_item:
		held_item.set_physics_state(true)
		held_item = null

func try_place_in_slot(slot):
	if held_item.is_in_group("small_items"):
		slot.equip_item(held_item) # Usamos la función que creamos en el script del Slot
		held_item = null
	else:
		print("Este objeto es demasiado grande para este slot")

func toggle_tool_mode():
	is_tool_active = !is_tool_active
	# Si saco la herramienta, cierro la mochila
	if is_tool_active: 
		is_inventory_mode = false
		print("Herramienta equipada")
	# Aquí podrías hacer que el modelo 3D de la herramienta haga .show() o .hide()
