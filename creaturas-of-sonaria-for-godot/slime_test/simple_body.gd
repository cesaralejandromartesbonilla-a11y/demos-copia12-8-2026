extends CharacterBody3D

# ==========================================
# 🧍 CUERPO ORDINARIO
# ==========================================
# Un CharacterBody3D común, sin nada específico del slime — pensado para
# lo que Comprender produzca (un humano, etc.). Ya cumple el contrato de
# BodySwitcher (activate_control/deactivate_control). Usa PlayerCamera
# (autoload de escena) directamente — no hay nada que asignar a mano ni
# ningún nodo de cámara del que este cuerpo dependa.

@export var is_player_controlled: bool = false

@onready var locomotion = $SimpleLocomotion

func _physics_process(delta: float) -> void:
	if not is_player_controlled: return

	PlayerCamera.process_camera(delta) # explícito, antes de leer su transform — mismo frame, orden garantizado

	var camera = PlayerCamera.get_camera()
	if camera == null: return

	var input_vector = Input.get_vector("press_a", "press_d", "press_w", "press_s")
	var is_jump_pressed = Input.is_action_just_pressed("press_space")

	locomotion.process_movement(self, input_vector, is_jump_pressed, camera.global_transform.basis, delta)

func _unhandled_input(event: InputEvent) -> void:
	if not is_player_controlled: return
	PlayerCamera.handle_input(event)

func activate_control() -> void:
	is_player_controlled = true

func deactivate_control() -> void:
	is_player_controlled = false
	velocity = Vector3.ZERO
