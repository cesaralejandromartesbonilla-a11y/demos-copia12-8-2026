class_name HookController
extends Node
## Node that is responsible for managing the hook, and the hook interface.
@export var is_enabled: bool = false # Por defecto desactivado

# HookController.gd - Al principio
@export_group("Custom Physics Profile")
@export var custom_mass_limit_min: float = 3.0
@export var custom_mass_limit_max: float = 7.0
@export var custom_max_tension: float = 2.0

@export_group("Rope Settings")
@export var min_rope_length: float = 1.5
@export var max_rope_length: float = 25.0
@export var rope_change_speed: float = 5.0
@export var max_tension_tolerance: float = 2.0 # Cuántos metros extra puede estirarse antes de romperse
@export var snap_force_threshold: float = 15.0 # Umbral de fuerza para rotura inmediata
var current_rope_limit: float = 0.0

@export_category("Hook Controller")
@export_group("Required Settings")
@export var hook_raycast: RayCast3D
## Usually the parent of the player's scene
@export var player_body: CharacterBody3D
## Input Map action name that triggers hook's launch
@export var launch_action_name: String
## Input Map action name that triggers hook's retraction
@export var retract_action_name: String
@export_group("Optional Settings")
@export var pull_speed: float = 1.0
## A 3D node that serves as the beginning on the rope model
@export var hook_source: Node3D
@export_group("Advanced Settings")
@export var hook_scene: PackedScene = preload("res://grappling-hook-3d-main/addons/grappling_hook_3d/src/hook.tscn")

var is_hook_launched: bool = false
var _hook_model: Node3D = null
var hook_target_normal: Vector3 = Vector3.ZERO
var hook_target_node: Marker3D = null

signal hook_launched()
signal hook_attached(body)
signal hook_detached()

func _physics_process(delta: float) -> void:
	# Si el gancho no está habilitado, no hace nada y se asegura de estar retraído
	#if not is_enabled:
		#return

	# ... resto del código (Input.is_action_just_pressed, etc) ...

	
	if Input.is_action_just_pressed(launch_action_name):
		hook_launched.emit()
		match is_hook_launched:
			false: _launch_hook()
			true: _retract_hook()
	
	if is_hook_launched:
		_handle_hook(delta)

# Función para cambiar el perfil desde la grúa
func apply_profile(min_m: float, max_m: float, tension: float, source: Node3D):
	custom_mass_limit_min = min_m
	custom_mass_limit_max = max_m
	custom_max_tension = tension
	hook_source = source
	is_enabled = true


func _launch_hook() -> void:
	if not hook_raycast.is_colliding():
		return
	
	is_hook_launched = true
	hook_attached.emit()
	
	var body: Node3D = hook_raycast.get_collider()
	
	hook_target_node = Marker3D.new()
	body.add_child(hook_target_node)
	
	hook_target_node.position = hook_raycast.get_collision_point() - body.global_position
	hook_target_normal = hook_raycast.get_collision_normal()
	
	_hook_model = hook_scene.instantiate()
	add_child(_hook_model)
	custom_mass_limit_min = player_body.global_position.distance_to(hook_raycast.get_collision_point())

func _retract_hook() -> void:
	if is_instance_valid(hook_target_node):
		hook_target_node.queue_free()
	if is_instance_valid(_hook_model):
		_hook_model.queue_free()
	is_hook_launched = false
	hook_detached.emit()

# AQUI EMPIEZA LA FUNCION CORREGIDA DE _handle_hook
func _handle_hook(delta: float) -> void:
	if not is_instance_valid(hook_target_node): return
	
	var body = hook_target_node.get_parent()
	var anchor_pos = hook_target_node.global_position
	var player_pos = player_body.global_position
	var distance = player_pos.distance_to(anchor_pos)
	
	# --- CONTROL DE LONGITUD (RECARGADO) ---
	if Input.is_action_just_pressed("scroll_up"):
		custom_mass_limit_min = clamp(custom_mass_limit_min - 1.0, custom_mass_limit_max, max_rope_length)
	if Input.is_action_just_pressed("scroll_down"):
		custom_mass_limit_min = clamp(custom_mass_limit_min + 1.0, custom_mass_limit_max, max_rope_length)

	# --- LÓGICA DE DEGRADADO Y MASA ---
	var weight_ratio = 1.0 
	if body is RigidBody3D:
		weight_ratio = clamp((body.mass - 3.0) / (7.0 - 3.0), 0.0, 1.0)
	
	var dir_to_player = (player_pos - anchor_pos).normalized()
	var dir_to_anchor = (anchor_pos - player_pos).normalized()
	
	# Aplicar fuerza al objeto (El camión casi no sentirá al jugador si weight_ratio es ~1.0)
	if body is RigidBody3D:
		var object_pull = (1.0 - weight_ratio) * pull_speed * 500.0
		body.apply_central_force(dir_to_player * object_pull)
	
	# --- TENSIÓN Y ROTURA DEL CABLE ---
	if distance > custom_mass_limit_min:
		# Si el jugador está atorado, la distancia crecerá aunque el cable intente tirar
		var stretch_distance = distance - custom_mass_limit_min
		
		# Si se estira más de lo permitido (camión tirando o jugador atorado), el cable se rompe
		if stretch_distance > max_tension_tolerance:
			_break_rope()
			return

		# Aplicar tensión al jugador
		var tension_magnitude = weight_ratio * stretch_distance * 25.0
		player_body.velocity += dir_to_anchor * tension_magnitude * delta * 60
	
	# Limitar velocidad del jugador
	player_body.velocity = player_body.velocity.limit_length(pull_speed * 15.0)

	# --- VISUALS ---
	var source_position = hook_source.global_position if hook_source else player_body.global_position
	_hook_model.extend_from_to(source_position, anchor_pos, hook_target_normal)

# Función para romper el cable con efecto visual o sonido opcional
func _break_rope() -> void:
	# Aquí podrías añadir un sonido de "snap" o partículas
	print("¡El cable se ha roto por exceso de tensión!")
	_retract_hook()

# AQUI TERMINA LA FUNCION CORREGIDA DE _handle_hook

# AQUI SE AÑADE LA FUNCION AUXILIAR is_smaller_than_player
func is_smaller_than_player(target: Node3D) -> bool:
	var target_col_shape = target.find_child("CollisionShape3D", true)
	if target_col_shape and target_col_shape.shape:
		var shape_data = target_col_shape.shape
		
		if shape_data.has_method("get_height"):
			return shape_data.get_height() < 1.5
		elif shape_data.has_method("get_extents"):
			return shape_data.get_extents().y < 0.75
	
	return false
