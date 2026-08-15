extends CharacterBody3D
class_name Player

const HOOK_AVAILIBLE_TEXTURE = preload("res://addons/grappling_hook_3d/example/hook_availible.png")
const HOOK_NOT_AVAILIBLE_TEXTURE = preload("res://addons/grappling_hook_3d/example/hook_not_availible.png")

@onready var camera := $Camera
@onready var hook_raycast: RayCast3D = $"Camera/Hook Raycast"
@onready var crosshair: TextureRect = $HUD/Crosshair

@export var movement_speed := 2.0
@export var friction_ground := 0.8  # Frena rápido en el suelo
@export var friction_air := 0.75     # Mantiene velocidad en el aire (cercano a 1.0)
@export var jump_force := 10.0
@export var gravity := 0.5
@export var mouse_sensetivity := 5.0
@onready var hook_controller: HookController = $HookController

func _physics_process(delta: float) -> void:
	# Horizontal movement
	var movement_direction: Vector2 = Input.get_vector("press_a", "press_d", "press_s", "press_w")
	var movement_vector: Vector3 = (transform.basis * Vector3(movement_direction.x, 0, -movement_direction.y)).normalized()
	
	# Esto permite controlar la dirección en el aire ligeramente, 
	# pero la fricción se encarga del frenado gradual.
	velocity += movement_vector * movement_speed * delta * 60
	
	match is_on_floor():
		true: velocity *= Vector3(friction_ground, 1, friction_ground) # Freno fuerte
		false: velocity *= Vector3(friction_air, 1, friction_air)       # Freno suave/inercia
	
	
	# Gravity & Jumping
	if not is_on_floor():
		velocity.y -= gravity
	
	elif Input.is_action_pressed("press_space"):
		velocity.y = jump_force
	
	move_and_slide()
	
	# UI
	crosshair.texture = HOOK_AVAILIBLE_TEXTURE if hook_raycast.is_colliding() and not hook_controller.is_hook_launched else HOOK_NOT_AVAILIBLE_TEXTURE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation_degrees.y -= event.relative.x * 0.06 * mouse_sensetivity
		
		camera.rotation_degrees.x -= event.relative.y * 0.06 * mouse_sensetivity
		
		camera.rotation_degrees.x = clamp(camera.rotation_degrees.x, -90, 90)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
