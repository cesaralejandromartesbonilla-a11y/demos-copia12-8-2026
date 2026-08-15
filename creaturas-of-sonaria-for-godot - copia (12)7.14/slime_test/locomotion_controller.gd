class_name LocomotionController extends Node

# --- Variables Exportadas (Ajustes de Diseño) ---
@export_group("Estadísticas Base")
@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8

@export_group("Súper Movilidad")
@export var jump_boost_force: float = 18.0     # Cuánta fuerza extra da mantener el salto
@export var max_jump_hold_time: float = 0.3    # Cuánto tiempo máximo puedes mantener el salto
@export var wall_escape_cooldown: float = 0.4  # Segundos que ignora la pared tras saltar de ella

@export_group("Física de Tensión Líquida")
@export var tether_rest_length: float = 2.0 
@export var tether_spring_force: float = 12.0 
@export var tether_break_distance: float = 18.0 
@export var min_rope_length: float = 1.5
@export var max_rope_length: float = 25.0
@export var rope_scroll_speed: float = 2.0

@export_group("Anclaje Líquido")
@export var grapple_speed: float = 35.0
@export var grapple_acceleration: float = 8.0 

@export_group("Suavizado")
@export var acceleration: float = 20.0
@export var friction: float = 25.0

# --- Estado Interno ---
var is_movement_enabled: bool = true
var active_grapple_nodes: Array[Node3D] = []
var is_grappling: bool = false

# Variables de control de salto
var splat_cooldown_timer: float = 0.0
var jump_hold_timer: float = 0.0

func start_multi_grapple(target_nodes: Array[Node3D]):
	active_grapple_nodes = target_nodes
	is_grappling = true

func stop_grapple():
	is_grappling = false
	for node in active_grapple_nodes:
		if is_instance_valid(node) and node.has_method("update_tether"):
			node.update_tether(Vector3.ZERO, false)
	active_grapple_nodes.clear()

func process_movement(slime_body: CharacterBody3D, input_vector: Vector2, is_jump_pressed: bool, is_build_mode: bool, delta: float):
	if is_grappling:
		_process_grapple_movement(slime_body, input_vector, is_jump_pressed, delta)
		return

	if is_build_mode or not is_movement_enabled:
		_apply_only_gravity_and_stop(slime_body, delta)
		return

	# 1. Temporizador para escapar de las paredes (Ignorar charcos temporalmente)
	if splat_cooldown_timer > 0:
		splat_cooldown_timer -= delta

	# ==========================================
	# 🕷️ LÓGICA DE WALL-WALKING Y ADHERENCIA
	# ==========================================
	var target_normal = Vector3.UP
	var is_on_splat = false

	if splat_cooldown_timer <= 0:
		var all_splats = slime_body.get_tree().get_nodes_in_group("splats")
		var detection_radius = 2.5 * slime_body.current_liquid_scale 
		
		var blended_normal = Vector3.ZERO
		var total_weight = 0.0
		
		for splat in all_splats:
			var dist = slime_body.global_position.distance_to(splat.global_position)
			if dist < detection_radius:
				is_on_splat = true
				var weight = 1.0 - (dist / detection_radius)
				weight = weight * weight * (3.0 - 2.0 * weight)
				blended_normal += splat.surface_normal * weight
				total_weight += weight

		if total_weight > 0.0:
			target_normal = (blended_normal / total_weight).normalized()

	if not is_on_splat:
		target_normal = Vector3.UP
		
	slime_body.up_direction = target_normal
	
	# 🟢 ADHERENCIA MAGNÉTICA (Evita que salga volando en las esquinas)
	if is_on_splat:
		slime_body.floor_max_angle = deg_to_rad(85)
		# Empujamos suavemente al slime contra la pared/suelo para que abrace las esquinas
		slime_body.velocity -= target_normal * gravity * 1.5 * delta
	else:
		slime_body.floor_max_angle = deg_to_rad(45)

	# ==========================================
	# 🎮 INPUTS RELATIVOS A LA SUPERFICIE (Efecto 2D)
	# ==========================================
	# 1. Tomamos la Derecha de la cámara y la pegamos a la superficie
	var cam_right = slime_body.camera_controller.global_transform.basis.x
	var surface_right = (cam_right - cam_right.project(slime_body.up_direction)).normalized()
	
	# 2. Producto Cruz: Generamos un "Adelante/Arriba" perfecto en la pared basándonos en la Derecha.
	var surface_forward = surface_right.cross(slime_body.up_direction).normalized()
	
	# 3. Aplicamos el input. (Asumiendo que W da input_vector.y negativo como es estándar en Godot)
	var direction = (surface_right * input_vector.x + surface_forward * input_vector.y).normalized()

	# ==========================================
	# APLICAR FUERZAS Y MOVIMIENTO
	# ==========================================
	_apply_gravity(slime_body, delta)

	# Lógica de súper salto...
	if is_jump_pressed and slime_body.is_on_floor():
		_apply_jump(slime_body)
		jump_hold_timer = max_jump_hold_time
		
		if target_normal != Vector3.UP:
			splat_cooldown_timer = wall_escape_cooldown
			# Damos un impulso en la normal de la pared para "despegarlo"
			slime_body.velocity += target_normal * jump_velocity 

	if Input.is_action_pressed("press_space") and jump_hold_timer > 0:
		jump_hold_timer -= delta
		slime_body.velocity += slime_body.up_direction * jump_boost_force * delta
	else:
		jump_hold_timer = 0.0 

	_apply_horizontal_velocity(slime_body, direction, delta)

	slime_body.move_and_slide()

func _process_grapple_movement(slime_body: CharacterBody3D, input_vector: Vector2, is_jump_pressed: bool, delta: float):
	active_grapple_nodes = active_grapple_nodes.filter(func(n): return is_instance_valid(n) and n.is_anchored)
	if active_grapple_nodes.size() == 0:
		stop_grapple()
		return

	if Input.is_action_just_pressed("scroll_up"):
		tether_rest_length = clamp(tether_rest_length - rope_scroll_speed, min_rope_length, max_rope_length)
	elif Input.is_action_just_pressed("scroll_down"):
		tether_rest_length = clamp(tether_rest_length + rope_scroll_speed, min_rope_length, max_rope_length)

	var cam_basis = slime_body.camera_controller.global_transform.basis
	var cam_forward = -cam_basis.z
	cam_forward = (cam_forward - cam_forward.project(slime_body.up_direction)).normalized()
	var cam_right = cam_basis.x
	cam_right = (cam_right - cam_right.project(slime_body.up_direction)).normalized()
	
	var direction = (cam_right * input_vector.x + cam_forward * input_vector.y).normalized()
	
	if active_grapple_nodes.size() > 0 and direction.length_squared() > 0.1:
		var avg_dir_to_nodes = Vector3.ZERO
		for node in active_grapple_nodes:
			avg_dir_to_nodes += (node.global_position - slime_body.global_position).normalized()
		avg_dir_to_nodes = avg_dir_to_nodes.normalized()
		
		var movement_intent = direction.dot(avg_dir_to_nodes)
		tether_rest_length -= movement_intent * 4.0 * delta 
		tether_rest_length = clamp(tether_rest_length, min_rope_length, max_rope_length)

	_apply_gravity(slime_body, delta)
	_apply_horizontal_velocity(slime_body, direction, delta)
	var tension_force = Vector3.ZERO
	var nodes_to_disconnect = []

	for node in active_grapple_nodes:
		var dist = slime_body.global_position.distance_to(node.global_position)
		if node.has_method("update_tether"): node.update_tether(slime_body.global_position, true)

		if dist > tether_break_distance:
			nodes_to_disconnect.append(node)
			continue

		if dist > tether_rest_length:
			var stretch = dist - tether_rest_length
			var dir_to_node = (node.global_position - slime_body.global_position).normalized()
			tension_force += dir_to_node * (stretch * tether_spring_force) 

	for node in nodes_to_disconnect:
		if node.has_method("update_tether"): node.update_tether(slime_body.global_position, false)
		active_grapple_nodes.erase(node)

	if active_grapple_nodes.size() > 0:
		tension_force /= active_grapple_nodes.size()
		slime_body.velocity += tension_force * delta

	slime_body.move_and_slide()

# --- Métodos de Lógica Interna ---

func _apply_gravity(slime_body: CharacterBody3D, delta: float):
	if not slime_body.is_on_floor():
		slime_body.velocity -= slime_body.up_direction * gravity * delta

func _apply_jump(slime_body: CharacterBody3D):
	slime_body.velocity += slime_body.up_direction * jump_velocity

func _apply_horizontal_velocity(slime_body: CharacterBody3D, direction: Vector3, delta: float):
	var up = slime_body.up_direction
	var target_vel = direction * speed
	var current_vel_planar = slime_body.velocity - slime_body.velocity.project(up)

	if direction.length() > 0:
		current_vel_planar = current_vel_planar.move_toward(target_vel, acceleration * delta)
	else:
		current_vel_planar = current_vel_planar.move_toward(Vector3.ZERO, friction * delta)

	var vertical_vel = slime_body.velocity.project(up)
	slime_body.velocity = current_vel_planar + vertical_vel

func _apply_only_gravity_and_stop(slime_body: CharacterBody3D, delta: float):
	if not slime_body.is_on_floor():
		slime_body.velocity -= slime_body.up_direction * gravity * delta
		
	var up = slime_body.up_direction
	var current_vel_planar = slime_body.velocity - slime_body.velocity.project(up)
	current_vel_planar = current_vel_planar.move_toward(Vector3.ZERO, friction * delta)
	slime_body.velocity = current_vel_planar + slime_body.velocity.project(up)
	slime_body.move_and_slide()

func update_movement_stats(new_speed: float, new_jump: float, new_gravity: float = 9.8):
	speed = new_speed
	jump_velocity = new_jump
	gravity = new_gravity

func get_horizontal_speed() -> float:
	var player_node = get_parent() as CharacterBody3D
	if not player_node: return 0.0
	return Vector2(player_node.velocity.x, player_node.velocity.z).length()

func get_movement_direction_relative() -> Vector3:
	var player_node = get_parent() as CharacterBody3D
	if not player_node: return Vector3.ZERO
	return (player_node.transform.basis.inverse() * player_node.velocity).normalized()
