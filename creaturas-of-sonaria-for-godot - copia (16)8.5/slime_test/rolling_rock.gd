extends RigidBody3D

# ==========================================
# 🪨 ROCA RODANTE — prototipo aislado de control por RigidBody3D
# ==========================================
# Antes de decidir cómo controlar el torso de HumanoidBody como
# RigidBody3D, esto prueba la sensación de control físico puro en el
# caso más simple posible: una roca que rueda (tipo Rock of Ages 2).
#
# El "empuje" se calcula por código (torque según la dirección de
# input), no con un nodo de viento/área — mismo efecto, pero explícito y
# bajo control directo en vez de depender de un campo de fuerza externo.
#
# La cámara NO sigue a la roca directo — la roca gira sin control propio
# al rodar, y si la cámara hereda ese giro, marea. Sigue a un
# "estabilizador": un nodo aparte que copia la POSICIÓN de la roca, pero
# calcula su propia rotación a partir de hacia dónde se mueve (inercia),
# no de cómo está girando físicamente.
#
# Requiere un CollisionShape3D propio (SphereShape3D es lo natural para
# que ruede bien) y opcionalmente un MeshInstance3D — no vienen incluidos.

@export_group("Rodado")
@export var roll_torque: float = 12.0
@export var max_angular_velocity: float = 6.0

@export_group("Cámara")
@export var camera_turn_speed: float = 8.0 # qué tan rápido el estabilizador gira hacia la nueva dirección
@export var camera_position_smooth: float = 12.0 # qué tan rápido sigue la posición — más bajo = más filtrado, más "flotante"

@export var is_player_controlled: bool = false

var _camera_target: Node3D

func _ready() -> void:
	_camera_target = Node3D.new()
	_camera_target.name = "CameraStabilizer"
	_camera_target.top_level = true # posición y rotación propias, no heredadas de la roca
	add_child(_camera_target)
	_camera_target.global_position = global_position

func _physics_process(delta: float) -> void:
	_update_camera_stabilizer(delta)

	if not is_player_controlled: return

	PlayerCamera.process_camera(delta) # explícito, antes de leer su transform — mismo frame, orden garantizado

	var camera = PlayerCamera.get_camera()
	if camera == null: return

	var input_vector = Input.get_vector("press_a", "press_d", "press_w", "press_s")
	if input_vector.length() < 0.01:
		return

	var cam_forward = -camera.global_transform.basis.z
	cam_forward.y = 0
	cam_forward = cam_forward.normalized()
	var cam_right = camera.global_transform.basis.x
	cam_right.y = 0
	cam_right = cam_right.normalized()

	var direction = (cam_right * input_vector.x + cam_forward * input_vector.y).normalized()

	# Eje de torque perpendicular a la dirección deseada y a "arriba" — esto
	# hace que la roca gire y, por fricción con el piso, se traduzca en esa
	# dirección. ⚠️ Sin verificar el signo (no puedo correr el motor): si
	# rueda al revés de lo esperado, invertí a (-direction).cross(Vector3.UP).
	var torque_axis = direction.cross(Vector3.UP)
	if angular_velocity.length() < max_angular_velocity:
		apply_torque(torque_axis * roll_torque)

func _update_camera_stabilizer(delta: float) -> void:
	if not is_instance_valid(_camera_target): return

	_camera_target.global_position = _camera_target.global_position.lerp(global_position, delta * camera_position_smooth)

	var flat_velocity = linear_velocity
	flat_velocity.y = 0
	if flat_velocity.length() > 0.3: # umbral para no girar por microvibraciones al estar casi quieta
		var target_basis = Basis.looking_at(flat_velocity.normalized(), Vector3.UP)
		_camera_target.global_transform.basis = _camera_target.global_transform.basis.slerp(target_basis, delta * camera_turn_speed)

func get_camera_target() -> Node3D:
	return _camera_target

func _unhandled_input(event: InputEvent) -> void:
	if not is_player_controlled: return
	PlayerCamera.handle_input(event, PlayerCamera.is_build_mode)

func activate_control() -> void:
	is_player_controlled = true

func deactivate_control() -> void:
	is_player_controlled = false
	angular_velocity = Vector3.ZERO
	linear_velocity = Vector3.ZERO
