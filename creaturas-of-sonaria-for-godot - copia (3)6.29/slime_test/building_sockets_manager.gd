extends Node3D
class_name BuildingSocketsManager

@export var selected_part_scene: PackedScene
@export var camera: Camera3D
@onready var hologram_material = preload("res://materiales/logic_conector.tres")

var is_active: bool = false
var hologram_instance: Node3D = null
var current_hovered_socket: InteractiveSocket = null

# Referencia al padre (el jugador) para registrar el IK al construir
@onready var player_brain: CharacterBody3D = get_parent()

func set_build_mode(state: bool):
	is_active = state
	if not is_active:
		_clear_hologram()

# Función pública para que la UI le diga qué pieza queremos construir
func set_selected_part(scene_path: String):
	selected_part_scene = load(scene_path)

func _physics_process(_delta):
	if not is_active or not selected_part_scene:
		return
	_handle_raycast()

func _handle_raycast():
	if not camera:
		push_warning("BuildingSocketsManager no tiene una cámara asignada.")
		return
		
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Raycast desde la pantalla hacia el mundo 3D
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 15.0 
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	# IMPORTANTE: Asegúrate de que esta capa coincida con la de tus Area3D de los Sockets
	query.collision_mask = 512 
	query.collide_with_areas = true 
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_collider = result.collider
		# Verificamos si tocamos un enchufe que está libre
		if hit_collider is InteractiveSocket and not hit_collider.is_occupied:
			_update_hologram(hit_collider)
			
			# Si hacemos clic izquierdo -> CONSTRUIR
			if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_build_part()
		else:
			_clear_hologram()
	else:
		_clear_hologram()

func _update_hologram(socket: InteractiveSocket):
	if current_hovered_socket == socket:
		return 
		
	_clear_hologram()
	current_hovered_socket = socket
	
	# Creamos el holograma transparente
	hologram_instance = selected_part_scene.instantiate()
	socket.add_child(hologram_instance)
	_apply_hologram_material(hologram_instance)

func _clear_hologram():
	if hologram_instance:
		hologram_instance.queue_free()
		hologram_instance = null
	current_hovered_socket = null

func _unhandled_input(event):
	if not is_active or not selected_part_scene or not current_hovered_socket:
		return
		
	# Si hacemos clic izquierdo y hay un holograma válido
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_build_part()
		# Le decimos a Godot que ya consumimos este clic para que no dispare otras acciones
		get_viewport().set_input_as_handled() 

func _build_part():
	var target_bone = current_hovered_socket.bone_name
	var scene_path = selected_part_scene.resource_path 
	
	current_hovered_socket.is_occupied = true 
	_clear_hologram()
	
	if player_brain.transformation_module:
		player_brain.transformation_module.add_dynamic_part(
			player_brain.current_form,
			target_bone, 
			scene_path, 
			player_brain
		)

func _apply_hologram_material(node: Node):
	if node is MeshInstance3D:
		node.material_override = hologram_material
	for child in node.get_children():
		_apply_hologram_material(child)

func _remove_hologram_material(node: Node):
	if node is MeshInstance3D:
		node.material_override = null
	for child in node.get_children():
		_remove_hologram_material(child)
