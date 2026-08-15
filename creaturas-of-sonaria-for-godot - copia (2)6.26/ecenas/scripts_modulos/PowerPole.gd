extends StaticBody3D
class_name PowerPole

var connected_nodes: Array[Node3D] = []
var drawn_cables: Array[MeshInstance3D] = []
var my_grid: PowerGrid

@export_group("Conexiones")
@export var cable_material: Material 
@export var connection_point: Marker3D 
@export var pre_connected_poles: Array[Node3D] = []

@export_group("Visuales")
@export var state_light_mesh: MeshInstance3D # La bombilla del poste
@export var highlight_mesh: MeshInstance3D # Un cilindro blanco transparente
@export var mat_red: Material   # Desconectado / Sin Energía
@export var mat_yellow: Material # Baja Tensión / Sobrecargado
@export var mat_green: Material  # Operativo 100%

func _ready() -> void:
	add_to_group("poste_electrico")
	if highlight_mesh: highlight_mesh.visible = false
	
	# Al nacer, cada objeto crea su propia red minúscula
	my_grid = PowerManager.create_new_grid(self)
	for target in pre_connected_poles:
		if target != null and not connected_nodes.has(target):
			connect_to_node(target)

func _exit_tree() -> void:
	# 1. Limpieza visual: Borramos los cables que generó este poste
	for cable in drawn_cables:
		if is_instance_valid(cable): cable.queue_free()
		
	# 2. Desvincularse de los vecinos: Le decimos a los otros postes que ya no existimos
	for neighbor in connected_nodes:
		if is_instance_valid(neighbor) and "connected_nodes" in neighbor:
			neighbor.connected_nodes.erase(self)
			
	# 3. Recalcular la red: Mandamos a reconstruir la red dividida
	if my_grid:
		PowerManager.rebuild_grid(my_grid)

func set_hover(is_hovered: bool) -> void:
	if highlight_mesh: highlight_mesh.visible = is_hovered

func _process(_delta: float) -> void:
	if state_light_mesh == null: return
	
	if connected_nodes.is_empty():
		state_light_mesh.set_surface_override_material(0, mat_red)
	# AHORA LE PREGUNTA A SU RED LOCAL (my_grid)
	elif my_grid and my_grid.satisfaction >= 1.0:
		state_light_mesh.set_surface_override_material(0, mat_green)
	elif my_grid and my_grid.satisfaction > 0.0:
		state_light_mesh.set_surface_override_material(0, mat_yellow)
	else:
		state_light_mesh.set_surface_override_material(0, mat_red)

func connect_to_node(target_node: Node3D) -> void:
	if target_node == self or connected_nodes.has(target_node): return
	
	if target_node.get("my_grid") and target_node.my_grid != self.my_grid:
		my_grid = PowerManager.merge_grids(self.my_grid, target_node.my_grid)
	
	connected_nodes.append(target_node)
	
	if "connected_nodes" in target_node:
		target_node.connected_nodes.append(self)
		
	_draw_cable(target_node)

func _draw_cable(target_pole: Node3D) -> void:
	var start_pos = connection_point.global_position
	var end_pos = target_pole.connection_point.global_position
	var distance = start_pos.distance_to(end_pos)
	
	var mesh_instance = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.02
	cylinder.bottom_radius = 0.02
	cylinder.height = distance
	cylinder.material = cable_material
	
	mesh_instance.mesh = cylinder
	get_tree().current_scene.add_child(mesh_instance)
	
	mesh_instance.global_position = (start_pos + end_pos) / 2.0
	mesh_instance.look_at(end_pos, Vector3.UP)
	mesh_instance.rotate_x(PI / 2.0)
	
	drawn_cables.append(mesh_instance)

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
