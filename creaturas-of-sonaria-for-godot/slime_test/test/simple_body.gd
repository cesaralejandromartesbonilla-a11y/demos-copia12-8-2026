extends CharacterBody3D

# ==========================================
# 🧍 CUERPO ORDINARIO — simple_body.gd + Comprender
# ==========================================
# La base es idéntica a la que usan las otras 8 clases de cuerpo (perros,
# caballos, aves, etc.) — cumple el contrato de BodySwitcher
# (activate_control/deactivate_control) y usa PlayerCamera directo, sin
# nada que asignar a mano.
#
# Encima de eso, lo que necesita el ensamblador de quimeras: collision_shape,
# default_hold_parent, active_limbs, register_limb(), move_hold_position_to().
# Nunca le agregues lógica de sockets ni de chasis acá — eso vive en
# CreatureChassis.gd, dentro de Visuals/ActiveChassis, no en este script.

@export var is_player_controlled: bool = false

@onready var locomotion = $SimpleLocomotion

# --- Lo que agrega el ensamblador de quimeras ---
@export var collision_shape: CollisionShape3D
@export var default_hold_parent: Node3D  ## Marker3D bajo Visuals — lo genera RequirementsBootstrapper si falta

var active_limbs: Array = []
var current_hold_parent: Node3D

# speed/jump_velocity ya no viven acá — viven en SimpleLocomotion. Estos dos
# son pass-through para que AssemblerModule.apply_stat_contract() pueda
# seguir escribiendo 'player.speed = ...' sin enterarse del cambio.
var speed: float:
	get: return locomotion.speed if locomotion else 0.0
	set(value):
		if locomotion: locomotion.speed = value

var jump_velocity: float:
	get: return locomotion.jump_velocity if locomotion else 0.0
	set(value):
		if locomotion: locomotion.jump_velocity = value

# Solo están acá para que CameraController.gd (modo buceo/gravity gun, Tab)
# no truene si alguna vez se activa poseyendo una quimera del ensamblador.
# No representan nada real para un cuerpo no-slime.
var default_col_radius: float = 0.5
var current_liquid_scale: float = 1.0


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


## Llamado por AssemblerModule cada vez que una pieza con 'update_limb()' se acopla.
func register_limb(limb: Node) -> void:
	if limb and not active_limbs.has(limb):
		active_limbs.append(limb)


## Llamado por AssemblerModule para mover el "punto de sujeción".
func move_hold_position_to(marker: Node3D) -> void:
	if not marker:
		push_warning("simple_body: move_hold_position_to() recibió un marker nulo.")
		return
	current_hold_parent = marker
	# TODO: reparentar acá el objeto "en mano" cuando exista esa lógica.
