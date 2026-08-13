extends CollisionObject3D
class_name MachineConnector

@export var is_generator: bool = false
@export var generator_component: PowerGeneratorComponent
@export var receiver_component: PowerReceiverComponent
@export var pre_connected_poles: Array[Node3D] = []

# --- Configuración Visual ---
@export var cable_material: Material 
@export var connection_point: Marker3D
@export var state_light_mesh: MeshInstance3D
@export var highlight_mesh: MeshInstance3D

@onready var mat_red = preload("res://materiales/luces/luz_roja.tres")
@onready var mat_green = preload("res://materiales/luces/luz_verde.tres")
@onready var mat_yellow = preload("res://materiales/luces/luz_amarilla.tres")

var my_grid: PowerGrid
var connected_nodes: Array[Node3D] = []
var drawn_cables: Array[MeshInstance3D] = []

func _ready() -> void:
	add_to_group("poste_electrico") 
	if highlight_mesh: highlight_mesh.visible = false
	
	# 1. Al nacer, creamos una red aislada para nosotros mismos
	my_grid = PowerManager.create_new_grid(self)
	
	# 2. Metemos los componentes de la máquina a nuestra nueva red local
	if is_generator and generator_component:
		my_grid.generators.append(generator_component)
		generator_component.my_connector = self
		
	if not is_generator and receiver_component:
		my_grid.receivers.append(receiver_component)
		receiver_component.my_connector = self
	my_grid = PowerManager.create_new_grid(self)
	for target in pre_connected_poles:
		if target != null and not connected_nodes.has(target):
			connect_to_node(target)

func _exit_tree() -> void:
	# Limpieza al destruir la máquina: ahora nos borramos de nuestra red local (Grid)
	if my_grid:
		if is_generator and generator_component:
			my_grid.generators.erase(generator_component)
		elif not is_generator and receiver_component:
			my_grid.receivers.erase(receiver_component)
	
	# Desconectar cables (lógica visual)
	for cable in drawn_cables:
		if is_instance_valid(cable): cable.queue_free()

# --- Funciones de Interacción (Llamadas por BuilderManager) ---
func set_hover(is_hovered: bool) -> void:
	if highlight_mesh: highlight_mesh.visible = is_hovered

func connect_to_node(target_node: Node3D) -> void:
	if target_node == self or connected_nodes.has(target_node): return
	
	if target_node.get("my_grid") and target_node.my_grid != self.my_grid:
		my_grid = PowerManager.merge_grids(self.my_grid, target_node.my_grid)
	
	connected_nodes.append(target_node)
	
	# Usamos una forma segura de inyectarnos en el otro nodo sin importar si es poste o máquina
	if "connected_nodes" in target_node:
		target_node.connected_nodes.append(self)
		
	_draw_cable(target_node)

func _draw_cable(target_pole: Node3D) -> void:
	var start_pos = connection_point.global_position
	var end_pos = target_pole.connection_point.global_position
	var distance = start_pos.distance_to(end_pos)
	
	# Creamos la malla del cable
	var mesh_instance = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.02 # Grosor del cable
	cylinder.bottom_radius = 0.02
	cylinder.height = distance
	cylinder.material = cable_material
	
	mesh_instance.mesh = cylinder
	get_tree().current_scene.add_child(mesh_instance)
	
	# Lo posicionamos exactamente en el medio de los dos postes
	mesh_instance.global_position = (start_pos + end_pos) / 2.0
	
	# Hacemos que el cable mire hacia el objetivo y lo acostamos
	mesh_instance.look_at(end_pos, Vector3.UP)
	mesh_instance.rotate_x(PI / 2.0) # Lo rotamos 90 grados para que acople
	
	drawn_cables.append(mesh_instance)

func _process(_delta: float) -> void:
	_update_lights()

func _update_lights() -> void:
	if state_light_mesh == null: return
	
	if connected_nodes.is_empty():
		state_light_mesh.set_surface_override_material(0, mat_red)
	# AHORA LE PREGUNTAMOS A NUESTRA RED LOCAL (my_grid), NO AL POWERMANAGER
	elif my_grid and my_grid.satisfaction >= 1.0:
		state_light_mesh.set_surface_override_material(0, mat_green)
	elif my_grid and my_grid.satisfaction > 0.0:
		state_light_mesh.set_surface_override_material(0, mat_yellow)
	else:
		state_light_mesh.set_surface_override_material(0, mat_red)

# --- FUNCIONES DE DESCONEXIÓN MANUAL ---

func disconnect_all_cables() -> void:
	# 1. Borramos los cables visuales que creó ESTE nodo
	for cable in drawn_cables:
		if is_instance_valid(cable): cable.queue_free()
	drawn_cables.clear()
	
	# 2. Nos desvinculamos de todos los vecinos
	for neighbor in connected_nodes:
		if is_instance_valid(neighbor):
			# Nos borramos de su lista de amigos
			if "connected_nodes" in neighbor:
				neighbor.connected_nodes.erase(self)
			# Le pedimos al vecino que borre los cables que ÉL tiró hacia nosotros
			if neighbor.has_method("_remove_cable_to"):
				neighbor._remove_cable_to(self)
				
	connected_nodes.clear()
	
	# 3. Le decimos al jefe que recalcule las redes ahora que faltan cables
	if my_grid:
		PowerManager.rebuild_grid(my_grid)

# Función de apoyo: Permite a un nodo borrar un cable específico y redibujar el resto
func _remove_cable_to(target_node: Node3D) -> void:
	# Borramos todos los cables visuales de este nodo momentáneamente
	for cable in drawn_cables:
		if is_instance_valid(cable): cable.queue_free()
	drawn_cables.clear()
	
	# Guardamos las conexiones actuales y limpiamos la lista
	var old_connections = connected_nodes.duplicate()
	connected_nodes.clear()
	
	# Volvemos a conectar visualmente todos EXCEPTO el que acabamos de cortar
	for node in old_connections:
		if node != target_node:
			connected_nodes.append(node)
			_draw_cable(node)
