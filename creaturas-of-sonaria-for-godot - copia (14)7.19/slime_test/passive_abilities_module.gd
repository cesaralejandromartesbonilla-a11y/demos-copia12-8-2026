extends Node
class_name PassiveAbilitiesModule

@export_group("Habilidades Pasivas")
@export var can_climb_slopes: bool = true
@export var slope_adhesion_force: float = 4.0 
@export var rotation_speed: float = 12.0
@export var max_climb_angle: float = deg_to_rad(65.0) 

@export_group("Agarre de Gota (Shift)")
@export var magnetic_grip_force: float = 8.0 
@export var edge_lookahead: float = 0.8 
@export var real_gravity: float = 15.0 # Fuerza que te hace resbalar hacia abajo

@onready var slime: CharacterBody3D = get_parent()
@onready var locomotion = slime.get_node_or_null("LocomotionController")

var is_grip_active: bool = false
var base_speed: float = 5.0 # Valor seguro por defecto

func _ready():
	if locomotion:
		# Intentamos detectar la variable de velocidad de tu script de Locomotion
		if "speed" in locomotion: base_speed = locomotion.speed
		elif "max_speed" in locomotion: base_speed = locomotion.max_speed

func _physics_process(delta: float) -> void:
	if not is_instance_valid(slime): return
	
	if can_climb_slopes:
		_handle_slope_alignment(delta)

func _handle_slope_alignment(delta: float) -> void:
	# Por defecto, el cielo es arriba
	var target_normal = Vector3.UP
	var is_valid_slope = false
	var is_shift_pressed = Input.is_action_pressed("press_shift")
	
	if slime.is_on_floor() or slime.is_on_wall() or slime.is_on_ceiling():
		var collision_normal = Vector3.UP
		
		if slime.is_on_floor(): collision_normal = slime.get_floor_normal()
		elif slime.is_on_wall(): collision_normal = slime.get_wall_normal()
		elif slime.is_on_ceiling(): collision_normal = slime.get_ceiling_normal()
			
		var is_steep = collision_normal.angle_to(Vector3.UP) > max_climb_angle
		
		# Solo consideramos la superficie válida si NO es empinada, o si lo es y apretamos Shift
		if not is_steep or is_shift_pressed:
			var safe_to_adhere = true
			if is_steep and is_shift_pressed:
				safe_to_adhere = _is_surface_continuing(collision_normal)
			
			if safe_to_adhere:
				target_normal = collision_normal
				is_valid_slope = true
				
	# ==========================================
	# 💧 EFECTO "GOTA DE AGUA" EN PAREDES EMPINADAS
	# ==========================================
	if is_valid_slope and target_normal.angle_to(Vector3.UP) > max_climb_angle:
		if not is_grip_active:
			is_grip_active = true
			_set_locomotion_speed(base_speed * 0.3) # Eres un 70% más lento
		
		# 1. Adhesión para no salir volando de la pared hacia los lados
		var outward_vel = slime.velocity.dot(target_normal)
		if outward_vel > 0:
			slime.velocity -= target_normal * outward_vel
		slime.velocity -= target_normal * magnetic_grip_force * delta
		
		# 2. Gravedad Natural (Te empuja hacia abajo por la pared)
		var earth_gravity = Vector3.DOWN * real_gravity * delta
		var slide_gravity = earth_gravity - earth_gravity.project(target_normal)
		slime.velocity += slide_gravity

	else:
		# ==========================================
		# 🚶 MODO NORMAL (SUELO O AIRE)
		# ==========================================
		if is_grip_active:
			is_grip_active = false
			_set_locomotion_speed(base_speed) # Restauramos tu velocidad normal
			
		if is_valid_slope and target_normal != Vector3.UP:
			slime.velocity -= target_normal * slope_adhesion_force * delta
			
	# 🌟 SOLUCIÓN AL "SHIFT ATASCADO":
	if not is_valid_slope and not slime.is_on_floor():
		target_normal = Vector3.UP

	# --- 🚨 SOLUCIÓN AL ERROR VECTOR ZERO 🚨 ---
	# Si por un fallo de colisión de Godot la normal es (0,0,0), la forzamos hacia arriba.
	if target_normal.is_zero_approx():
		target_normal = Vector3.UP

	slime.up_direction = target_normal
	_rotate_visuals_to_normal(target_normal, delta)

func _set_locomotion_speed(new_speed: float):
	if not locomotion: return
	if "speed" in locomotion: locomotion.speed = new_speed
	elif "max_speed" in locomotion: locomotion.max_speed = new_speed


func _is_surface_continuing(surface_normal: Vector3) -> bool:
	var move_dir = slime.velocity - slime.velocity.project(surface_normal)
	if move_dir.length_squared() < 0.1: return true 
		
	var space_state = slime.get_world_3d().direct_space_state
	var start_pos = slime.global_position + (move_dir.normalized() * edge_lookahead)
	var end_pos = start_pos - (surface_normal * 1.5) 
	
	var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	query.exclude = [slime.get_rid()]
	return not space_state.intersect_ray(query).is_empty()

func _rotate_visuals_to_normal(target_normal: Vector3, delta: float) -> void:
	if target_normal.is_zero_approx(): return
	if not is_instance_valid(slime.visuals) or not is_instance_valid(slime.camera_controller): return
	
	var current_scale = slime.visuals.scale
	var target_basis = Basis()
	target_basis.y = target_normal
	
	var cam_back = slime.camera_controller.global_transform.basis.z 
	target_basis.x = target_normal.cross(cam_back).normalized()
	
	if target_basis.x.length_squared() < 0.01:
		target_basis.x = target_normal.cross(Vector3.RIGHT).normalized()
		
	target_basis.z = target_basis.x.cross(target_basis.y).normalized()
	
	var current_quat = slime.visuals.global_transform.basis.orthonormalized().get_rotation_quaternion()
	var target_quat = target_basis.get_rotation_quaternion()
	
	var new_quat = current_quat.slerp(target_quat, rotation_speed * delta)
	slime.visuals.global_transform.basis = Basis(new_quat).scaled(current_scale)
