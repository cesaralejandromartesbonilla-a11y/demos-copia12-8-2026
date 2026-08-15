extends CollisionObject3D
class_name LogicConnector

@export var is_transmitter: bool = false
@export var transmitter_component: Node3D # nodo padre
@export var receiver_component: LogicReceiverComponent
@export var pre_connected_poles: Array[Node3D] = []
# --- Configuración Visual ---
@export var cable_material: Material 
@export var connection_point: Marker3D
@export var state_light_mesh: MeshInstance3D
@export var highlight_mesh: MeshInstance3D

@onready var mat_blue = preload("res://materiales/luces/luz_azul.tres")
@onready var mat_red = preload("res://materiales/luces/luz_roja.tres")

# --- Variables de Red ---
var my_grid
var connected_nodes: Array[Node3D] = []
var drawn_cables: Array[MeshInstance3D] = []

func _ready() -> void:
	add_to_group("poste_logico") 
	if highlight_mesh: highlight_mesh.visible = false
	
	# Simula la creación de una red lógica propia
	my_grid = {
		"transmitters": [],
		"receivers": []
	}
	
	# Inyectar componentes dependiendo de si es emisor o receptor
	if is_transmitter and transmitter_component:
		my_grid.transmitters.append(transmitter_component)
		if "my_logic_grid" in transmitter_component:
			transmitter_component.my_logic_grid = my_grid
			
	elif not is_transmitter and receiver_component:
		my_grid.receivers.append(receiver_component)
		if "my_logic_grid" in receiver_component:
			receiver_component.my_logic_grid = my_grid

	for target in pre_connected_poles:
		if target != null and not connected_nodes.has(target):
			connect_to_node(target)

func _exit_tree() -> void:
	if my_grid:
		if is_transmitter and transmitter_component:
			my_grid.transmitters.erase(transmitter_component)
		elif not is_transmitter and receiver_component:
			my_grid.receivers.erase(receiver_component)
	
	for cable in drawn_cables:
		if is_instance_valid(cable): cable.queue_free()

func set_hover(is_hovered: bool) -> void:
	if highlight_mesh: highlight_mesh.visible = is_hovered

func connect_to_node(target_node: Node3D) -> void:
	if target_node == self or connected_nodes.has(target_node): return
	
	connected_nodes.append(target_node)
	if "connected_nodes" in target_node:
		target_node.connected_nodes.append(self)
		
	_draw_cable(target_node)
	
	# MÁGIA AQUÍ: Recalcular toda la red tras conectar
	_rebuild_entire_logic_network()

# --- NUEVO SISTEMA DE ESCANEO DE RED ---
func _rebuild_entire_logic_network() -> void:
	# 1. Encontrar absolutamente todos los postes conectados físicamente por cables (Flood Fill)
	var all_poles = []
	var to_check = [self]
	
	while to_check.size() > 0:
		var current = to_check.pop_front()
		if not all_poles.has(current):
			all_poles.append(current)
			for neighbor in current.connected_nodes:
				if is_instance_valid(neighbor):
					to_check.append(neighbor)
					
	# 2. Crear un diccionario de red fresco y limpio
	var unified_grid = {
		"transmitters": [],
		"receivers": []
	}
	
	# 3. Asignarle esta nueva red a todos los postes encontrados
	for pole in all_poles:
		pole.my_grid = unified_grid # Ahora todos los postes saben que están en la misma red
		
		# Guardar a los emisores (Central)
		if pole.is_transmitter and pole.transmitter_component:
			if not unified_grid.transmitters.has(pole.transmitter_component):
				unified_grid.transmitters.append(pole.transmitter_component)
			if "my_logic_grid" in pole.transmitter_component:
				pole.transmitter_component.my_logic_grid = unified_grid
				
		# Guardar a los receptores (Máquinas)
		elif not pole.is_transmitter and pole.receiver_component:
			if not unified_grid.receivers.has(pole.receiver_component):
				unified_grid.receivers.append(pole.receiver_component)
			if "my_logic_grid" in pole.receiver_component:
				pole.receiver_component.my_logic_grid = unified_grid

# obsolota
func _merge_logic_grids(grid_a: Dictionary, grid_b: Dictionary) -> void:
	# Traslada todos los transmisores y receptores a la grid_a
	for t in grid_b.transmitters:
		if not grid_a.transmitters.has(t):
			grid_a.transmitters.append(t)
			if "my_logic_grid" in t: t.my_logic_grid = grid_a
			
	for r in grid_b.receivers:
		if not grid_a.receivers.has(r):
			grid_a.receivers.append(r)
			if "my_logic_grid" in r: r.my_logic_grid = grid_a

func _draw_cable(target_pole: Node3D) -> void:
	var start_pos = connection_point.global_position
	var end_pos = target_pole.connection_point.global_position
	var distance = start_pos.distance_to(end_pos)
	
	var mesh_instance = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.015 # Cable lógico ligeramente más fino
	cylinder.bottom_radius = 0.015
	cylinder.height = distance
	cylinder.material = cable_material
	
	mesh_instance.mesh = cylinder
	get_tree().current_scene.add_child(mesh_instance)
	
	mesh_instance.global_position = (start_pos + end_pos) / 2.0
	mesh_instance.look_at(end_pos, Vector3.UP)
	mesh_instance.rotate_x(PI / 2.0) 
	
	drawn_cables.append(mesh_instance)

func _process(_delta: float) -> void:
	_update_lights()

func _update_lights() -> void:
	if state_light_mesh == null: return
	
	if connected_nodes.is_empty():
		state_light_mesh.set_surface_override_material(0, mat_red)
	elif my_grid and my_grid.transmitters.size() > 0:
		# Luz azul si está conectado a una red con una Central de Comandos
		state_light_mesh.set_surface_override_material(0, mat_blue)
	else:
		state_light_mesh.set_surface_override_material(0, mat_red)

func disconnect_all_cables() -> void:
	for cable in drawn_cables:
		if is_instance_valid(cable): cable.queue_free()
	drawn_cables.clear()
	
	for neighbor in connected_nodes:
		if is_instance_valid(neighbor):
			if "connected_nodes" in neighbor:
				neighbor.connected_nodes.erase(self)
			if neighbor.has_method("_remove_cable_to"):
				neighbor._remove_cable_to(self)
				
	connected_nodes.clear()
	_rebuild_entire_logic_network()

func _remove_cable_to(target_node: Node3D) -> void:
	for cable in drawn_cables:
		if is_instance_valid(cable): cable.queue_free()
	drawn_cables.clear()
	
	var old_connections = connected_nodes.duplicate()
	connected_nodes.clear()
	
	for node in old_connections:
		if node != target_node:
			connected_nodes.append(node)
			_draw_cable(node)
