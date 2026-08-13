extends SpringArm3D

@export var mouse_sensitivity: float = 0.05
@export var suavizado_seguimiento: float = 10.0
@export var distancia_zoom_min: float = 4.0
@export var distancia_zoom_max: float = 10.0

@export_group("Control de Cámara")
# Falso = Mantener click derecho para girar. Verdadero = Click para atrapar/soltar.
@export var usar_toggle_para_camara: bool = false 

func _ready():
	set_as_top_level(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	spring_length = 6.0

func _process(delta):
	var target_node = get_parent()
	if target_node:
		global_position = global_position.lerp(target_node.global_position, delta * suavizado_seguimiento)

func _unhandled_input(event: InputEvent) -> void:
	
	# 1. Control para atrapar/liberar el mouse con Click Derecho
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if usar_toggle_para_camara:
			# MODO TOGGLE: Un clic atrapa, otro clic libera
			if event.pressed:
				if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				else:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			# MODO MANTENER: Atrapa al presionar, libera al soltar
			if event.pressed:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# 2. Rotación con Mouse (SOLO gira si el mouse está atrapado)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation_degrees.x -= event.relative.y * mouse_sensitivity
		rotation_degrees.x = clamp(rotation_degrees.x, -70.0, 20.0) # Limites verticales
		
		rotation_degrees.y -= event.relative.x * mouse_sensitivity
		rotation_degrees.y = wrapf(rotation_degrees.y, 0.0, 360.0)

	# 3. Zoom con rueda del ratón (Funciona siempre, no requiere atrapar el mouse)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_length = clamp(spring_length - 0.5, distancia_zoom_min, distancia_zoom_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_length = clamp(spring_length + 0.5, distancia_zoom_min, distancia_zoom_max)
