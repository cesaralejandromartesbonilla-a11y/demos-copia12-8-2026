extends CharacterBody3D

# ==========================================
# 🧍 CUERPO HUMANOIDE — más complejo que SimpleBody
# ==========================================
# El torso ES este CharacterBody3D — se mueve con SimpleLocomotion, igual
# que SimpleBody. Brazos y piernas SÍ son Limb, colgando del torso,
# reaccionando físicamente sin caminar de forma activa (misma decisión
# de siempre: sin IK, sin gait real — solo se sostienen y se balancean).
#
# Requiere un CollisionShape3D propio (ej. CapsuleShape3D) como hijo,
# igual que cualquier CharacterBody3D — no viene incluido, agrégalo en
# el editor representando el torso.

@export var is_player_controlled: bool = false

@export_group("Proporciones (silueta humana)")
@export var leg_segments: int = 3
@export var leg_segment_height: float = 0.35
@export var arm_segments: int = 3
@export var arm_segment_height: float = 0.28
@export var shoulder_height: float = 1.3
@export var shoulder_width: float = 0.25
@export var hip_width: float = 0.15

@onready var locomotion = $SimpleLocomotion

var limbs: Array[Limb] = []

func _ready() -> void:
	_build_limb("PiernaIzq", Vector3(-hip_width, 0, 0), Vector3(180, 0, 0), leg_segments, leg_segment_height)
	_build_limb("PiernaDer", Vector3(hip_width, 0, 0), Vector3(180, 0, 0), leg_segments, leg_segment_height)
	_build_limb("BrazoIzq", Vector3(-shoulder_width, shoulder_height, 0), Vector3(180, 0, 0), arm_segments, arm_segment_height)
	_build_limb("BrazoDer", Vector3(shoulder_width, shoulder_height, 0), Vector3(180, 0, 0), arm_segments, arm_segment_height)

func _build_limb(limb_name: String, local_pos: Vector3, rot_degrees: Vector3, count: int, seg_height: float) -> void:
	var limb = Limb.new()
	limb.name = limb_name
	limb.segment_count = count
	limb.segment_height = seg_height
	# Posición/rotación ANTES de add_child — propiedades locales, seguras
	# sin importar el orden (a diferencia de global_transform).
	limb.position = local_pos
	limb.rotation_degrees = rot_degrees
	limb.collision_exempt_body = self # no pelear contra el torso del que cuelga
	add_child(limb)
	limbs.append(limb)

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
	PlayerCamera.handle_input(event, PlayerCamera.is_build_mode)

func activate_control() -> void:
	is_player_controlled = true

func deactivate_control() -> void:
	is_player_controlled = false
	velocity = Vector3.ZERO

func destroy_limbs() -> void:
	for limb in limbs:
		if is_instance_valid(limb):
			limb.destroy()
	limbs.clear()
