extends Node3D

@export var player_brain: CharacterBody3D
@export var camera: Camera3D
@export var player_dummy: CharacterBody3D 
@export var assembler_module: AssemblerModule
@onready var hologram_material = preload("res://materiales/logic_conector.tres")

var is_active: bool = false
var hologram_instance: Node3D = null
var current_hovered_socket: InteractiveSocket = null
var selected_part_data: CreaturePartData

func set_build_mode(state: bool):
	is_active = state
	if not is_active:
		_clear_hologram()

func set_selected_part(part_data: CreaturePartData):
	selected_part_data = part_data
	is_active = true
	print("Mesa de Trabajo: Buscando sockets para acoplar: ", part_data.display_name)

func _physics_process(_delta):
	if not is_active or not selected_part_data:
		return
	_handle_raycast()

func _handle_raycast():
	if not camera:
		push_warning("BuildingSocketsManager no tiene una cámara asignada.")
		return
		
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 15.0 
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = 512 
	query.collide_with_areas = true 
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_collider = result.collider
		if hit_collider is InteractiveSocket and not hit_collider.is_occupied:
			_update_hologram(hit_collider)
		else:
			_clear_hologram()
	else:
		_clear_hologram()

func _update_hologram(socket: InteractiveSocket):
	if current_hovered_socket == socket:
		return 
		
	_clear_hologram()
	current_hovered_socket = socket
	
	if selected_part_data and selected_part_data.part_scene:
		hologram_instance = selected_part_data.part_scene.instantiate()
		socket.add_child(hologram_instance)
		_apply_hologram_material(hologram_instance)

func _clear_hologram():
	if hologram_instance:
		hologram_instance.queue_free()
		hologram_instance = null
	current_hovered_socket = null

func _unhandled_input(event):
	if not is_active or not selected_part_data or not current_hovered_socket:
		return
		
	# Si hacemos clic izquierdo y hay un holograma válido
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_build_part()
		# Le decimos a Godot que ya consumimos este clic para que no dispare otras acciones
		get_viewport().set_input_as_handled() 

func _build_part():
	var assembler := assembler_module if assembler_module else get_node_or_null("../AssemblerModule") as AssemblerModule

	if not assembler:
		push_error("BuildingSocketsManager: no encontré el AssemblerModule. Asignalo en 'Assembler Module' en el Inspector.")
		return
	if not player_dummy:
		push_error("BuildingSocketsManager: player_dummy no está asignado en el Inspector.")
		return

	var target_socket := current_hovered_socket
	target_socket.is_occupied = true
	_clear_hologram()

	assembler.add_dynamic_part(target_socket, selected_part_data, player_dummy)

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
