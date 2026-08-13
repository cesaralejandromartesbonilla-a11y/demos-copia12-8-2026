class_name CameraController extends Node3D

# --- Variables de Cámara ---
@export var mouse_sensitivity: float = 0.003
@export var min_zoom: float = 2.0
@export var max_zoom: float = 10.0
@export var zoom_speed: float = 1.5
@export var zoom_smoothness: float = 8.0

var target_zoom: float = 5.0
var player: CharacterBody3D

# 🟢 ACUMULADORES NUMÉRICOS PUROS: Evitan que las físicas deformen los ejes de control
var cam_yaw: float = 0.0
var cam_pitch: float = 0.0

@onready var spring_arm = $SpringArm3D

var tracking_target: Node3D = null
var default_offset: Vector3 = Vector3(0, 0.5, 0) # Altura normal de tu cámara cuando estás en el suelo

func _ready():
	player = get_parent() as CharacterBody3D
	spring_arm.spring_length = target_zoom
	
	cam_yaw = global_transform.basis.get_euler().y
	cam_pitch = spring_arm.rotation.x
	
	# 🌟 LA MAGIA QUE PEDISTE: Esto independiza la cámara de la jerarquía del Slime
	top_level = true 

func handle_input(event: InputEvent, is_build_mode: bool):
	# 1. Rotar el horizonte de la cámara con el ratón
	if event is InputEventMouseMotion and not is_build_mode:
		# Modificamos los acumuladores directos en vez de multiplicar transformaciones del nodo
		cam_yaw -= event.relative.x * mouse_sensitivity
		cam_pitch -= event.relative.y * mouse_sensitivity
		
		# Clampeamos el cabeceo vertical (para no dar la vuelta al revés de cabeza)
		cam_pitch = clamp(cam_pitch, deg_to_rad(-65), deg_to_rad(65))
	
	# 2. Controlar el Zoom objetivo
	if event.is_action_pressed("scroll_up"):
		target_zoom -= zoom_speed
	elif event.is_action_pressed("scroll_down"):
		target_zoom += zoom_speed
		
	target_zoom = clamp(target_zoom, min_zoom, max_zoom)

func process_camera(delta: float):
	if is_instance_valid(tracking_target):
		# Si tenemos un objetivo (ej. el andamio), lo seguimos a la perfección
		global_position = tracking_target.global_position
	elif is_instance_valid(player):
		# Si no hay andamio, seguimos al Slime en el suelo con su altura normal
		global_position = player.global_position + default_offset
	# Suavizado del Zoom
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_zoom, zoom_smoothness * delta)
	
	# 🟢 ESTABILIZACIÓN GEOMÉTRICA DE LA VISTA
	# Usamos la rotación actual del cuerpo del jugador (que ya transiciona suavemente)
	var surface_up = player.global_transform.basis.y
	
	# Construimos una base matemática orientada a la superficie pero libre de torsión
	var basis_surface = Basis()
	basis_surface.y = surface_up
	if abs(surface_up.dot(Vector3.UP)) < 0.99:
		basis_surface.x = Vector3.UP.cross(surface_up).normalized()
	else:
		basis_surface.x = surface_up.cross(Vector3.FORWARD).normalized()
	basis_surface.z = basis_surface.x.cross(basis_surface.y).normalized()
	basis_surface = basis_surface.orthonormalized()
	
	# Aplicamos nuestro Yaw y Pitch de manera limpia sobre este marco estable
	var target_basis = basis_surface
	target_basis = target_basis.rotated(target_basis.y, cam_yaw)   # Giro horizontal relativo al charco
	target_basis = target_basis.rotated(target_basis.x, cam_pitch) # Giro vertical relativo a la pantalla
	
	# Forzamos la orientación global del pivote
	global_transform.basis = target_basis
	
	# Mantenemos el spring_arm en cero local, ya que todo el cálculo se procesa en este nodo padre
	spring_arm.rotation = Vector3.ZERO

# --- Funciones Utilitarias ---

func get_aim_direction() -> Vector3:
	var cam = spring_arm.get_child(0) as Camera3D
	if cam:
		return -cam.global_transform.basis.z.normalized()
	return -global_transform.basis.z.normalized()

func force_min_safe_zoom(safe_distance: float):
	target_zoom = max(target_zoom, safe_distance)

func adjust_zoom_for_size(amount: float):
	spring_arm.spring_length += amount
	target_zoom = max(min_zoom, spring_arm.spring_length)
