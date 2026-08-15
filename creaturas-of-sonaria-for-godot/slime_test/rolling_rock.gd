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
# Cámara: usa el modo orbital de PlayerCamera (el mismo del editor tipo
# Spore) en vez de un estabilizador propio — resuelve el mareo gratis,
# ya que la rotación orbital nunca depende de cómo gira la roca, solo
# del mouse. Menos código, mismo resultado, reutilizando lo que ya
# funciona bien.
#
# Requiere un CollisionShape3D propio (SphereShape3D es lo natural para
# que ruede bien) y opcionalmente un MeshInstance3D — no vienen incluidos.

@export_group("Rodado")
@export var roll_torque: float = 12.0
@export var max_angular_velocity: float = 6.0

@export var is_player_controlled: bool = false

func _physics_process(delta: float) -> void:
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

func _unhandled_input(event: InputEvent) -> void:
	if not is_player_controlled: return
	PlayerCamera.handle_input(event)

func activate_control() -> void:
	is_player_controlled = true
	PlayerCamera.orbital_target = self
	PlayerCamera.is_build_mode = true

func deactivate_control() -> void:
	is_player_controlled = false
	PlayerCamera.is_build_mode = false
	angular_velocity = Vector3.ZERO
	linear_velocity = Vector3.ZERO
