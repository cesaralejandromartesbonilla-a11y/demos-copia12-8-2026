class_name CameraController extends Node3D

# --- Variables de Cámara ---
@export var mouse_sensitivity: float = 0.003
@export var min_zoom: float = 2.0
@export var max_zoom: float = 10.0
@export var zoom_speed: float = 1.5
@export var zoom_smoothness: float = 8.0

var target_zoom: float = 5.0
var player: CharacterBody3D

@onready var spring_arm = $SpringArm3D

func _ready():
	# Guardamos la referencia al jugador (el padre de este nodo) para poder rotarlo
	player = get_parent() as CharacterBody3D
	spring_arm.spring_length = target_zoom

# El jugador le pasará los eventos del teclado/ratón a esta función
func handle_input(event: InputEvent, is_build_mode: bool):
	# 1. Rotar la cámara con el ratón
	if event is InputEventMouseMotion and not is_build_mode:
		# Rotamos al jugador en el eje Y (Izquierda/Derecha)
		player.rotate_y(-event.relative.x * mouse_sensitivity)
		# Rotamos el brazo del pivote en el eje X (Arriba/Abajo)
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, -PI/4, PI/3)
	
	# 2. Controlar el Zoom objetivo
	if event.is_action_pressed("scroll_up"):
		target_zoom -= zoom_speed
	elif event.is_action_pressed("scroll_down"):
		target_zoom += zoom_speed
		
	target_zoom = clamp(target_zoom, min_zoom, max_zoom)

# El jugador llamará a esto en su _physics_process
func process_camera(delta: float):
	# Suavizado del Zoom
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_zoom, zoom_smoothness * delta)

# --- Funciones Utilitarias para que el Jugador las use ---

func get_aim_direction() -> Vector3:
	# Devuelve hacia dónde está mirando la cámara (útil para disparar o lanzar cosas)
	return -global_transform.basis.z.normalized()

func force_min_safe_zoom(safe_distance: float):
	# Evita que la cámara se quede dentro del modelo si el slime es muy grande
	target_zoom = max(target_zoom, safe_distance)

func adjust_zoom_for_size(amount: float):
	# Ajusta instantáneamente el brazo y el objetivo cuando el slime crece o se encoge bruscamente
	spring_arm.spring_length += amount
	target_zoom = max(min_zoom, spring_arm.spring_length)
