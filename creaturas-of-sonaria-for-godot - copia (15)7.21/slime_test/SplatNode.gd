extends Area3D
class_name SplatNode

var surface_normal: Vector3 = Vector3.UP
var stored_mass: float = 0.2
var stored_element: String = "BASE"
var connected_splats: Array[SplatNode] = []
var is_draining: bool = false

var vein_like_connections: bool = true # Activa las venas 3D
var max_drain_height: float = 1.5      # Distancia máxima por encima del charco
var min_drain_depth: float = -0.2      # Límite por debajo (evita succionar desde la otra habitación)

var current_color: Color = Color.WHITE
var visual_bridges: Dictionary = {}

func _ready():
	add_to_group("splats")
	add_to_group("slime_projectiles") 
	collision_layer = 8 
	collision_mask = 8 
	gravity_space_override = Area3D.SPACE_OVERRIDE_DISABLED
	monitorable = true
	monitoring = true
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func setup(impact_position: Vector3, impact_normal: Vector3, splat_color: Color):
	global_position = impact_position
	surface_normal = impact_normal
	current_color = splat_color # Guardamos el color para los puentes
	
	var x_axis = Vector3.UP.cross(surface_normal).normalized()
	if x_axis.length_squared() == 0:
		x_axis = Vector3.RIGHT
		
	var z_axis = surface_normal.cross(x_axis).normalized()
	global_transform.basis = Basis(x_axis, surface_normal, z_axis)

	# --- Visual del Charco ---
	var decal = Decal.new()
	decal.extents = Vector3(1.0, 0.5, 1.0) 
	decal.modulate = splat_color
	add_child(decal)
	
	var mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.05 
	mesh.mesh = cyl
	var mat = StandardMaterial3D.new()
	mat.albedo_color = splat_color
	mesh.material_override = mat
	add_child(mesh)

	var col = CollisionShape3D.new()
	var exact_box = BoxShape3D.new()
	exact_box.size = Vector3(1.8, 0.05, 1.8) 
	col.shape = exact_box
	add_child(col)

# ==========================================
# 🤝 CONEXIÓN DE RED (CON PUENTES VISUALES)
# ==========================================
func _on_area_entered(area: Area3D):
	if not area.is_in_group("splats"): return
	if area != self and not connected_splats.has(area):
		connected_splats.append(area)
		_create_visual_bridge(area)

func _on_area_exited(area: Area3D):
	if not area.is_in_group("splats"): return
	if area != self and connected_splats.has(area):
		connected_splats.erase(area)
		if visual_bridges.has(area):
			if is_instance_valid(visual_bridges[area]):
				visual_bridges[area].queue_free()
			visual_bridges.erase(area)

func _create_visual_bridge(neighbor: SplatNode):
	# Solo el nodo más antiguo dibuja el puente (evita duplicados)
	if self.get_instance_id() > neighbor.get_instance_id():
		return
		
	var bridge = MeshInstance3D.new()
	var box = BoxMesh.new()
	var dist = global_position.distance_to(neighbor.global_position)
	
	# 🩸 LÓGICA DE LAS VENAS
	if vein_like_connections:
		box.size = Vector3(0.4, 0.3, dist) # Más grueso y abultado
	else:
		box.size = Vector3(0.8, 0.05, dist) # Plano y pegado al suelo
		
	bridge.mesh = box
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = current_color
	bridge.material_override = mat
	
	add_child(bridge)
	
	bridge.global_position = (global_position + neighbor.global_position) / 2.0
	var up_vec = surface_normal if surface_normal.length_squared() > 0 else Vector3.UP
	
	if vein_like_connections:
		bridge.global_position += up_vec * 0.15
	
	# Posicionamos y rotamos el puente hacia el vecino
	bridge.global_position = (global_position + neighbor.global_position) / 2.0
	
	# Pequeña corrección matemática segura para el look_at
	if bridge.global_position.distance_squared_to(neighbor.global_position) > 0.001:
		# Si la normal es totalmente vertical, usamos un UP diferente para que no tire error
		if up_vec.abs() == Vector3.UP:
			bridge.look_at(neighbor.global_position, Vector3.RIGHT)
		else:
			bridge.look_at(neighbor.global_position, up_vec)
			
	visual_bridges[neighbor] = bridge

# ==========================================
# 🌪️ LÓGICA DE DRENAJE
# ==========================================
func process_network_drain(slime_node: CharacterBody3D, delta: float):
	var local_slime_pos = to_local(slime_node.global_position)
	# Y positivo es "encima" del charco. Y negativo es "enterrado" en la pared.
	if local_slime_pos.y < min_drain_depth or local_slime_pos.y > max_drain_height:
		return
	
	var network = _get_entire_network()
	network.sort_custom(func(a, b): 
		var dist_a = a.global_position.distance_squared_to(slime_node.global_position)
		var dist_b = b.global_position.distance_squared_to(slime_node.global_position)
		return dist_a < dist_b
	)
	
	var target_to_drain = null
	for i in range(network.size() - 1, -1, -1):
		var node = network[i]
		if is_instance_valid(node) and node.stored_mass > 0:
			target_to_drain = node
			break
			
	if target_to_drain != null:
		target_to_drain._drain_step(slime_node, delta)

func _drain_step(slime_node: CharacterBody3D, delta: float):
	var drain_speed = 1.5 * delta
	var amount = min(drain_speed, stored_mass)
	
	stored_mass -= amount
	scale = scale.lerp(Vector3(0.1, 1.0, 0.1), delta * 5.0)
	
	if slime_node.mass_manager:
		slime_node.mass_manager.add_mass(amount)
		
	if stored_mass <= 0.05:
		# Avisamos a los vecinos para que limpien sus referencias y destruyan los puentes
		for neighbor in connected_splats:
			if is_instance_valid(neighbor):
				neighbor.connected_splats.erase(self)
				if neighbor.visual_bridges.has(self):
					if is_instance_valid(neighbor.visual_bridges[self]):
						neighbor.visual_bridges[self].queue_free()
					neighbor.visual_bridges.erase(self)
					
		# Limpiamos nuestros propios puentes antes de morir
		for bridge in visual_bridges.values():
			if is_instance_valid(bridge):
				bridge.queue_free()
				
		queue_free()

func _get_entire_network() -> Array:
	var visited = []
	var queue = [self]
	
	while queue.size() > 0:
		var current = queue.pop_front()
		if not visited.has(current) and is_instance_valid(current):
			visited.append(current)
			for neighbor in current.connected_splats:
				if not visited.has(neighbor):
					queue.append(neighbor)
	return visited
