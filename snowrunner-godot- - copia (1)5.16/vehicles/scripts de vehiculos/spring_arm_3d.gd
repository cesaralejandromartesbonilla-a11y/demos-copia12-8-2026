extends SpringArm3D

@export var mouse_sensitivity: float = 0.05
@export var suavizado_seguimiento: float = 10.0
@export var distancia_zoom_min: float = 4.0
@export var distancia_zoom_max: float = 10.0

func _ready():
	# IMPORTANTE: Hacemos que el SpringArm sea independiente de la rotación del camión
	set_as_top_level(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Inicializamos la longitud del brazo
	spring_length = 6.0

func _process(delta):
	# Obtenemos la posición del padre (La camioneta)
	var target_node = get_parent()
	if target_node:
		# Lerp para un seguimiento suave (efecto amortiguador)
		global_position = global_position.lerp(target_node.global_position, delta * suavizado_seguimiento)

func _input(event):
	# Rotación con Mouse
	if event is InputEventMouseMotion:
		rotation_degrees.x -= event.relative.y * mouse_sensitivity
		rotation_degrees.x = clamp(rotation_degrees.x, -60, 10) # Limites verticales
		
		rotation_degrees.y -= event.relative.x * mouse_sensitivity
		# Mantenemos la rotación Y en 360 grados limpios
		rotation_degrees.y = wrapf(rotation_degrees.y, 0, 360)

	# Zoom con rueda del ratón
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_length = clamp(spring_length - 0.5, distancia_zoom_min, distancia_zoom_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_length = clamp(spring_length + 0.5, distancia_zoom_min, distancia_zoom_max)

func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		return
	
	if event is InputEventMouseMotion:
		rotation_degrees.x -= event.relative.y * mouse_sensitivity
		rotation_degrees.x = clamp(rotation_degrees.x, -90.0, 30.0)
		
		rotation_degrees.y -= event.relative.x * mouse_sensitivity
		rotation_degrees.y = wrapf(rotation_degrees.y, 0.0, 360.0)
