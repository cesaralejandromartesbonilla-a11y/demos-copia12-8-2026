extends Node3D
class_name EnsambladorMecanicoUI

## Adaptado casi directo de BuildingSocketsManager.gd (proyecto de
## criaturas) — mismo flujo de raycast + holograma + click. Lo único que
## cambia son los tipos (SocketMecanico en vez de InteractiveSocket,
## DatosPiezaMecanica en vez de CreaturePartData) y que _confirmar_pieza()
## llama a EnsambladorMecanico.acoplar_pieza() en vez de
## AssemblerModule.add_dynamic_part().

@export var camera: Camera3D
@export var ensamblador: EnsambladorMecanico
@export var hologram_material: Material
@export var socket_collision_mask: int = 1 << 10  # capa 11 por defecto — debe coincidir con la collision_layer de tus SocketMecanico

var is_active: bool = false
var hologram_instance: Node3D = null
var current_hovered_socket: SocketMecanico = null
var selected_part_data: DatosPiezaMecanica


func set_selected_part(datos: DatosPiezaMecanica) -> void:
	selected_part_data = datos
	is_active = true


func _physics_process(_delta: float) -> void:
	if not is_active or not selected_part_data:
		return
	_handle_raycast()


func _handle_raycast() -> void:
	if not camera:
		push_warning("EnsambladorMecanicoUI: falta asignar 'camera' en el Inspector.")
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_end := ray_origin + camera.project_ray_normal(mouse_pos) * 15.0

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = socket_collision_mask

	var result := get_world_3d().direct_space_state.intersect_ray(query)

	if result and result.collider is SocketMecanico and not result.collider.is_occupied:
		_update_hologram(result.collider)
	else:
		_clear_hologram()


func _update_hologram(socket: SocketMecanico) -> void:
	if current_hovered_socket == socket:
		return
	_clear_hologram()
	current_hovered_socket = socket

	if selected_part_data and selected_part_data.part_scene:
		hologram_instance = selected_part_data.part_scene.instantiate()
		socket.add_child(hologram_instance)
		if hologram_material:
			_apply_hologram_material(hologram_instance)


func _clear_hologram() -> void:
	if hologram_instance:
		hologram_instance.queue_free()
		hologram_instance = null
	current_hovered_socket = null


func _unhandled_input(event: InputEvent) -> void:
	if not is_active or not selected_part_data or not current_hovered_socket:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_confirmar_pieza()
		get_viewport().set_input_as_handled()


func _confirmar_pieza() -> void:
	if not ensamblador:
		push_error("EnsambladorMecanicoUI: falta asignar 'ensamblador' en el Inspector.")
		return

	var socket := current_hovered_socket
	_clear_hologram()
	ensamblador.acoplar_pieza(socket, selected_part_data)


func _apply_hologram_material(node: Node) -> void:
	if node is MeshInstance3D:
		node.material_override = hologram_material
	for child in node.get_children():
		_apply_hologram_material(child)
