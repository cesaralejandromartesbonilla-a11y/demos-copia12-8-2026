extends Node3D

@export var target: Node3D # Arrastra aquí tu PlayerDummy desde el inspector
@export var rotation_speed: float = 0.005
@export var zoom_speed: float = 0.5
@export var min_zoom: float = 1.0
@export var max_zoom: float = 8.0

@onready var spring_arm: SpringArm3D = $SpringArm3D

var is_rotating: bool = false

func _ready():
	if target:
		global_position = target.global_position + Vector3(0, 1, 0) # Centrar al pecho

func _unhandled_input(event):
	# Activar/Desactivar rotación con el clic derecho
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		is_rotating = event.pressed
		if is_rotating:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) # Esconde el ratón al girar
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) # Lo devuelve al soltar

	# Control del movimiento (Orbitar)
	if event is InputEventMouseMotion and is_rotating:
		# Girar horizontalmente (Eje Y)
		rotate_y(-event.relative.x * rotation_speed)
		
		# Girar verticalmente (Eje X del SpringArm para no romper el eje Y global)
		spring_arm.rotate_x(-event.relative.y * rotation_speed)
		
		# Limitamos la inclinación vertical para evitar el Gimbal Lock
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-85), deg_to_rad(85))

	# Control del Zoom (Rueda del ratón)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = clamp(spring_arm.spring_length - zoom_speed, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = clamp(spring_arm.spring_length + zoom_speed, min_zoom, max_zoom)

func _process(_delta):
	# Si tu PlayerDummy llega a moverse o cambiar de tamaño, el pivote lo seguirá suavemente
	if target:
		global_position = global_position.lerp(target.global_position + Vector3(0, 1, 0), 0.1)
