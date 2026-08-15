extends Node

# ==========================================
# 🚶 LOCOMOCIÓN MÍNIMA — mover y saltar, nada más
# ==========================================
# A diferencia de LocomotionController (wall-walking, charcos, resortera,
# anclaje líquido), esto es lo mínimo que necesita un cuerpo "ordinario"
# vía Comprender: gravedad, salto, caminar relativo a cámara.

@export_group("Estadísticas Base")
@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8

@export_group("Suavizado")
@export var acceleration: float = 20.0
@export var friction: float = 25.0

func process_movement(body: CharacterBody3D, input_vector: Vector2, is_jump_pressed: bool, camera_basis: Basis, delta: float) -> void:
	if not body.is_on_floor():
		body.velocity.y -= gravity * delta

	if is_jump_pressed and body.is_on_floor():
		body.velocity.y = jump_velocity

	# Movimiento relativo a la cámara, aplanado (sin componente vertical)
	var cam_forward = -camera_basis.z
	cam_forward.y = 0
	cam_forward = cam_forward.normalized()
	var cam_right = camera_basis.x
	cam_right.y = 0
	cam_right = cam_right.normalized()

	var direction = (cam_right * input_vector.x + cam_forward * input_vector.y).normalized()
	var target_vel = direction * speed
	var current_horizontal = Vector3(body.velocity.x, 0, body.velocity.z)

	if direction.length() > 0:
		current_horizontal = current_horizontal.move_toward(target_vel, acceleration * delta)
	else:
		current_horizontal = current_horizontal.move_toward(Vector3.ZERO, friction * delta)

	body.velocity.x = current_horizontal.x
	body.velocity.z = current_horizontal.z

	# Gira el cuerpo para encarar hacia donde se mueve — el slime hace algo
	# similar (por eso su raycast rota correctamente); esto es la versión
	# más simple de lo mismo. Si el comportamiento real del slime es
	# distinto (ej. encarar la cámara en vez del movimiento), compartime
	# esa parte de locomotion_controller.gd y lo ajusto para que coincida.
	if direction.length() > 0.01:
		var target_rotation = atan2(direction.x, direction.z)
		body.rotation.y = lerp_angle(body.rotation.y, target_rotation, delta * 10.0)

	body.move_and_slide()
