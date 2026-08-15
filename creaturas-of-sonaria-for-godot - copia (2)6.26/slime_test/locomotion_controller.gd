class_name LocomotionController extends Node

# --- Variables Exportadas (Ajustes de Diseño) ---
@export_group("Estadísticas Base")
@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8 # Valor de respaldo seguro

@export_group("Suavizado")
# A mayor valor, más rápido reacciona el movimiento. Valores bajos dan sensación de "pista de hielo".
@export var acceleration: float = 10.0
@export var friction: float = 15.0

# --- Estado Interno ---
var is_movement_enabled: bool = true

# --- Función Principal (Invocada por el Jugador en _physics_process) ---
# Esta función recibe la instancia del CharacterBody3D y los parámetros de entrada puros.
func process_movement(slime_body: CharacterBody3D, input_vector: Vector2, is_jump_pressed: bool, is_build_mode: bool, delta: float):
	
	# Caso 1: Movimiento deshabilitado o modo construcción
	if is_build_mode or not is_movement_enabled:
		_apply_only_gravity_and_stop(slime_body, delta)
		return

	# Caso 2: Movimiento Normal (Decoupled Physics)
	
	# 1. Aplicamos Gravedad
	_apply_gravity(slime_body, delta)

	# 2. Gestionamos Salto
	if is_jump_pressed and slime_body.is_on_floor():
		_apply_jump(slime_body)

	# 3. Calculamos Dirección Global basada en WASD y orientación del cuerpo
	var direction = (slime_body.transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()

	# 4. Aplicamos Velocidad Horizontal (con aceleración y fricción para suavizar)
	_apply_horizontal_velocity(slime_body, direction, delta)

	# 5. Ejecutamos el movimiento real
	slime_body.move_and_slide()

# --- Métodos de Lógica Interna ---

func _apply_gravity(slime_body: CharacterBody3D, delta: float):
	if not slime_body.is_on_floor():
		slime_body.velocity.y -= gravity * delta

func _apply_jump(slime_body: CharacterBody3D):
	slime_body.velocity.y = jump_velocity

func _apply_horizontal_velocity(slime_body: CharacterBody3D, direction: Vector3, delta: float):
	# Separamos la velocidad horizontal actual (X, Z) para suavizarla
	var current_velocity_horizontal = Vector2(slime_body.velocity.x, slime_body.velocity.z)
	
	# Calculamos el objetivo de velocidad
	var target_velocity_horizontal = Vector2(direction.x * speed, direction.z * speed)

	# APLICAMOS EL DESACOPLAMIENTO DE VELOCIDAD
	if direction.length() > 0:
		# Estamos Acelerando o cambiando de dirección
		current_velocity_horizontal = current_velocity_horizontal.move_toward(target_velocity_horizontal, acceleration * delta)
	else:
		# Estamos frenando (Fricción)
		current_velocity_horizontal = current_velocity_horizontal.move_toward(Vector2.ZERO, friction * delta)

	# Actualizamos la velocidad final en el cuerpo
	slime_body.velocity.x = current_velocity_horizontal.x
	slime_body.velocity.z = current_velocity_horizontal.y

func _apply_only_gravity_and_stop(slime_body: CharacterBody3D, delta: float):
	# Para cuando el jugador está quieto o inmovilizado
	if not slime_body.is_on_floor():
		slime_body.velocity.y -= gravity * delta
	
	# Frenado instantáneo en X, Z
	slime_body.velocity.x = move_toward(slime_body.velocity.x, 0, friction * delta)
	slime_body.velocity.z = move_toward(slime_body.velocity.z, 0, friction * delta)
	
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
