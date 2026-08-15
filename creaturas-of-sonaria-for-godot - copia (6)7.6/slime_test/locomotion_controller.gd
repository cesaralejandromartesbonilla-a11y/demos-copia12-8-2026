class_name LocomotionController extends Node

# --- Variables Exportadas (Ajustes de Diseño) ---
@export_group("Estadísticas Base")
@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8

@export_group("Física de Tensión Líquida")
@export var tether_rest_length: float = 2.0 # Distancia a la que la cuerda se destensa
@export var tether_spring_force: float = 12.0 # Fuerza de atracción elástica
@export var tether_break_distance: float = 18.0 # Límite para que se rompa el enlace
@export var min_rope_length: float = 1.5
@export var max_rope_length: float = 25.0
@export var rope_scroll_speed: float = 2.0

@export_group("Anclaje Líquido")
@export var grapple_speed: float = 35.0
@export var grapple_acceleration: float = 8.0 # Menor valor = más elástico/fluido (como agua)

@export_group("Suavizado")
# A mayor valor, más rápido reacciona el movimiento. Valores bajos dan sensación de "pista de hielo".
@export var acceleration: float = 20.0
@export var friction: float = 25.0

# --- Estado Interno ---
var is_movement_enabled: bool = true
var active_grapple_nodes: Array[Node3D] = []
var is_grappling: bool = false

func start_multi_grapple(target_nodes: Array[Node3D]):
	active_grapple_nodes = target_nodes
	is_grappling = true

func stop_grapple():
	is_grappling = false
	for node in active_grapple_nodes:
		if is_instance_valid(node) and node.has_method("update_tether"):
			node.update_tether(Vector3.ZERO, false) # Al mandar false, revisará si debe borrarse
	active_grapple_nodes.clear()

func process_movement(slime_body: CharacterBody3D, input_vector: Vector2, is_jump_pressed: bool, is_build_mode: bool, delta: float):
	if is_grappling:
		_process_grapple_movement(slime_body, input_vector, is_jump_pressed, delta)
		return

	if is_build_mode or not is_movement_enabled:
		_apply_only_gravity_and_stop(slime_body, delta)
		return

	# ==========================================
	# 🕷️ LÓGICA DE WALL-WALKING (Sensor de Charcos)
	# ==========================================
	var floor_normal = Vector3.UP
	var space_state = slime_body.get_world_3d().direct_space_state
	
	# Lanzamos un rayo desde el slime, hacia donde apunten sus "pies" actuales
	var query = PhysicsRayQueryParameters3D.create(slime_body.global_position, slime_body.global_position - (slime_body.up_direction * 1.5))
	var result = space_state.intersect_ray(query)
	
	# Si pisamos un charco, robamos su dirección (su pared o techo)
	if result and result.collider is PuddleNode:
		floor_normal = result.collider.surface_normal
		
	# Alineamos las físicas internas de Godot a esta nueva pared
	slime_body.up_direction = floor_normal
	
	# Rotamos suavemente el cuerpo visual del Slime para que sus pies toquen la pared/techo
	if slime_body.transform.basis.y.distance_to(floor_normal) > 0.01:
		var right = floor_normal.cross(slime_body.transform.basis.z).normalized()
		# Prevención de Gimbal Lock (si estamos mirando directamente arriba/abajo)
		if right.length_squared() < 0.01: right = floor_normal.cross(slime_body.transform.basis.x).normalized()
		var forward = right.cross(floor_normal).normalized()
		
		var target_basis = Basis(right, floor_normal, forward).orthonormalized()
		slime_body.global_transform.basis = slime_body.global_transform.basis.slerp(target_basis, 10.0 * delta)

	# ==========================================
	# MOVIMIENTO RELATIVO AL PLANO
	# ==========================================
	_apply_gravity(slime_body, delta)

	if is_jump_pressed and slime_body.is_on_floor():
		_apply_jump(slime_body)

	# Ahora el WASD se adapta automáticamente a si estás en el suelo, pared o techo
	var direction = (slime_body.transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()

	_apply_horizontal_velocity(slime_body, direction, delta)

	slime_body.move_and_slide()

func _process_grapple_movement(slime_body: CharacterBody3D, input_vector: Vector2, is_jump_pressed: bool, delta: float):
	active_grapple_nodes = active_grapple_nodes.filter(func(n): return is_instance_valid(n) and n.is_anchored)
	if active_grapple_nodes.size() == 0:
		stop_grapple()
		return

	# --- ⚙️ LÓGICA DE CABRESTANTE (SCROLL DEL RATÓN) ---
	# Acortamos o alargamos la distancia de descanso de TODA la red
	if Input.is_action_just_pressed("scroll_up"):
		tether_rest_length = clamp(tether_rest_length - rope_scroll_speed, min_rope_length, max_rope_length)
	elif Input.is_action_just_pressed("scroll_down"):
		tether_rest_length = clamp(tether_rest_length + rope_scroll_speed, min_rope_length, max_rope_length)

	# 1. Dirección de Movimiento de WASD + Cámara
	var direction = (slime_body.transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
	
	# --- ⚙️ LÓGICA DE CABRESTANTE INTUITIVA ---
	if active_grapple_nodes.size() > 0 and direction.length_squared() > 0.1:
		var avg_dir_to_nodes = Vector3.ZERO
		for node in active_grapple_nodes:
			avg_dir_to_nodes += (node.global_position - slime_body.global_position).normalized()
		avg_dir_to_nodes = avg_dir_to_nodes.normalized()
		
		# Producto punto: 1.0 (miras directo al nodo), -1.0 (miras en contra)
		var movement_intent = direction.dot(avg_dir_to_nodes)
		
		# Si intent es positivo (vas hacia el nodo), el cable se acorta. Si es negativo (retrocedes), cede.
		tether_rest_length -= movement_intent * 4.0 * delta # 4.0 es la velocidad de enrollado
		tether_rest_length = clamp(tether_rest_length, min_rope_length, max_rope_length)

	# 2. Aplicar Gravedad y Movimiento libre
	_apply_gravity(slime_body, delta)
	_apply_horizontal_velocity(slime_body, direction, delta)
	var tension_force = Vector3.ZERO
	var nodes_to_disconnect = []

	for node in active_grapple_nodes:
		var dist = slime_body.global_position.distance_to(node.global_position)
		if node.has_method("update_tether"): node.update_tether(slime_body.global_position, true)

		# Si nos estiramos más allá del límite de rotura, se rompe este anclaje
		if dist > tether_break_distance:
			nodes_to_disconnect.append(node)
			continue

		# Comportamiento de Cabrestante elástico
		if dist > tether_rest_length:
			var stretch = dist - tether_rest_length
			var dir_to_node = (node.global_position - slime_body.global_position).normalized()
			
			# Hacemos que la tensión aumente mientras más te estiras
			tension_force += dir_to_node * (stretch * tether_spring_force) 

	for node in nodes_to_disconnect:
		if node.has_method("update_tether"): node.update_tether(slime_body.global_position, false)
		active_grapple_nodes.erase(node)

	# 3. Aplicamos la Tensión
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
	
	# Extraemos solo la velocidad que está yendo hacia adelante/lados (ignorando la caída)
	var current_vel_planar = slime_body.velocity - slime_body.velocity.project(up)

	if direction.length() > 0:
		current_vel_planar = current_vel_planar.move_toward(target_vel, acceleration * delta)
	else:
		current_vel_planar = current_vel_planar.move_toward(Vector3.ZERO, friction * delta)

	# Reconstruimos la velocidad sumando el avance + la caída/salto
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

# --- Métodos de Actualización Dinámica (Invocados por Formas/Elementos) ---

func update_movement_stats(new_speed: float, new_jump: float, new_gravity: float = 9.8):
	speed = new_speed
	jump_velocity = new_jump
	gravity = new_gravity # Opcional: El mundo suele fijar la gravedad

# --- Métodos Utilitarios para Efectos Visuales/Animaciones ---

func get_horizontal_speed() -> float:
	# Devuelve la velocidad horizontal actual (útil para el 'bamboleo' procedural)
	var player = get_parent() as CharacterBody3D
	if not player: return 0.0
	return Vector2(player.velocity.x, player.velocity.z).length()

func get_movement_direction_relative() -> Vector3:
	# Devuelve la dirección de movimiento relativa local (útil para la 'inclinación' procedural)
	var player = get_parent() as CharacterBody3D
	if not player: return Vector3.ZERO
	return (player.transform.basis.inverse() * player.velocity).normalized()
