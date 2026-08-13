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

enum MassState { PUDDLE, INERT_BLOB }

@export var blob_threshold: float = 1.5     # cuánta stored_mass necesita el núcleo para volverse sólido (Hito 3)
@export var min_vein_mass: float = 0.05     # antes 0.3 — los disparos base rondan 0.1, así que nunca había excedente para circular
@export var circulation_rate: float = 0.05  # tasa de circulación en decimales, solo para excedentes menores a un paquete
@export var core_growth_rate: float = 0.5   # cuánto escala visualmente el núcleo por unidad de stored_mass (Hito 2)
@export var packet_size: float = 1.0        # tamaño de cada paquete; el umbral para mandarlo es este mismo valor
@export var packet_cooldown_time: float = 1.0 # segundos de espera entre paquetes (si no, se mandarían uno por frame)
@export var idle_cleanup_time: float = 8.0 # segundos parado en el mínimo (sin servir de relevo para nadie más) antes de autodestruirse
@export var debug_print_network_stats: bool = false # Activá esto solo cuando quieras ver los números en consola

var current_state: MassState = MassState.PUDDLE
var _idle_timer: float = 0.0 # Para la limpieza por inactividad
signal state_changed(new_state: MassState)

var _cached_core = null # SplatNode o MassBagNode — sin tipo estricto porque puede ser cualquiera de los dos
var _cached_network_size: int = 1 # Cuántos charcos hay en la red conectada
var _cached_hop_distance: int = 0 # A cuántos saltos de charco-a-charco está del núcleo
var _cached_next_hop = null # A quién le manda su excedente por circulación (un charco vecino, o el núcleo directo si está a un salto)
var _packet_cooldown: float = 0.0 # Evita mandar un paquete de 1.0 por frame (60/seg sería instantáneo)
var _visual_mesh: MeshInstance3D = null # Solo se escala si este nodo termina siendo el núcleo
var _visual_decal: Decal = null

var connected_mass_bag: MassBagNode = null # Si hay uno cerca, gana como núcleo de toda la red
var _mass_bag_bridge: MeshInstance3D = null

static var _material_cache: Dictionary = {} # Un material por color, no uno por charco/vena

static func _get_cached_material(color: Color) -> StandardMaterial3D:
	if not _material_cache.has(color):
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		_material_cache[color] = mat
	return _material_cache[color]

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
	# La detección de MassBagNode ya no vive acá — MassBagNode tiene su
	# propio Area3D detector que crece junto con su esfera (ver
	# MassBagNode._on_detector_area_entered). Antes, este SplatNode
	# escuchaba body_entered/body_exited del cuerpo físico de la bolsa,
	# pero eso se volvía frágil apenas la esfera crecía o se movía.

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
	_visual_decal = decal
	
	var mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.05 
	mesh.mesh = cyl
	mesh.material_override = _get_cached_material(splat_color)
	add_child(mesh)
	_visual_mesh = mesh

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
		_mark_network_dirty()

func _on_area_exited(area: Area3D):
	if not area.is_in_group("splats"): return
	if area != self and connected_splats.has(area):
		connected_splats.erase(area)
		if visual_bridges.has(area):
			if is_instance_valid(visual_bridges[area]):
				visual_bridges[area].queue_free()
			visual_bridges.erase(area)
		_mark_network_dirty()

# connected_mass_bag y _mass_bag_bridge ahora los administra MassBagNode
# directamente (_on_detector_area_entered/_exited) — ver MassBagNode.gd.

func _create_mass_bag_bridge():
	if connected_mass_bag == null or not is_instance_valid(connected_mass_bag):
		return
	_mass_bag_bridge = MeshInstance3D.new()
	_mass_bag_bridge.mesh = BoxMesh.new()
	_mass_bag_bridge.material_override = _get_cached_material(current_color)
	add_child(_mass_bag_bridge)
	_update_mass_bag_bridge_transform()

func _update_mass_bag_bridge_transform():
	if _mass_bag_bridge == null or not is_instance_valid(_mass_bag_bridge):
		return
	if connected_mass_bag == null or not is_instance_valid(connected_mass_bag):
		return
	_mass_bag_bridge.global_position = (global_position + connected_mass_bag.global_position) / 2.0
	var up_vec = surface_normal if surface_normal.length_squared() > 0 else Vector3.UP
	if _mass_bag_bridge.global_position.distance_squared_to(connected_mass_bag.global_position) > 0.001:
		if up_vec.abs() == Vector3.UP:
			_mass_bag_bridge.look_at(connected_mass_bag.global_position, Vector3.RIGHT)
		else:
			_mass_bag_bridge.look_at(connected_mass_bag.global_position, up_vec)

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
	bridge.material_override = _get_cached_material(current_color)
	
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
		_cleanup_and_free()

# Compartida entre _drain_step (drenado manual hasta el fondo) y la limpieza
# por inactividad de más abajo. Antes esta lógica vivía duplicada solo en
# _drain_step, y nunca avisaba al MassBagNode si el charco destruido estaba
# conectado a uno — linked_splats se quedaba con una referencia obsoleta.
func _cleanup_and_free():
	var surviving_neighbor = null
	for neighbor in connected_splats:
		if is_instance_valid(neighbor):
			neighbor.connected_splats.erase(self)
			if neighbor.visual_bridges.has(self):
				if is_instance_valid(neighbor.visual_bridges[self]):
					neighbor.visual_bridges[self].queue_free()
				neighbor.visual_bridges.erase(self)
			surviving_neighbor = neighbor

	if connected_mass_bag != null and is_instance_valid(connected_mass_bag):
		connected_mass_bag.linked_splats.erase(self)

	for bridge in visual_bridges.values():
		if is_instance_valid(bridge):
			bridge.queue_free()
	if _mass_bag_bridge != null and is_instance_valid(_mass_bag_bridge):
		_mass_bag_bridge.queue_free()

	# Si queda algún vecino (charco o el MassBagNode), que recalcule la red sin nosotros
	if surviving_neighbor != null:
		surviving_neighbor._mark_network_dirty()
	elif connected_mass_bag != null and is_instance_valid(connected_mass_bag) and connected_mass_bag.linked_splats.size() > 0:
		connected_mass_bag.linked_splats[0]._mark_network_dirty()

	queue_free()

# Un charco que ya dio todo su excedente y quedó en min_vein_mass, sin ser
# el núcleo ni servir de relevo para más de un vecino (una "hoja" de la
# red), se autodestruye después de idle_cleanup_time segundos quieto.
# Antes esto no pasaba nunca fuera del drenado manual del jugador — con
# redes grandes, terminaban acumulándose charcos gastados sin usar,
# causando lag por seguir cargándolos (BFS, _process, etc.) sin necesidad.
func _check_idle_cleanup(delta: float, core):
	if self == core:
		_idle_timer = 0.0
		return
	var total_connections = connected_splats.size() + (1 if connected_mass_bag != null else 0)
	if total_connections > 1:
		# Es un relevo para más de un vecino — borrarlo partiría la red en dos
		_idle_timer = 0.0
		return
	if stored_mass <= min_vein_mass + 0.01:
		_idle_timer += delta
		if _idle_timer >= idle_cleanup_time:
			_cleanup_and_free()
	else:
		_idle_timer = 0.0

# ==========================================
# 💧 CANALIZAR MASA (Hito 6: jugador → charco)
# Espejo de process_network_drain, pero más simple: en vez de buscar el
# nodo más lejano con masa, alimenta directamente donde el jugador está
# tocando — la circulación que ya corre en _process (_circulate_excess_mass)
# se encarga de llevar el excedente hacia el núcleo, así que no hace falta
# buscar nada acá.
# ==========================================
func process_network_feed(slime_node: CharacterBody3D, delta: float):
	var local_slime_pos = to_local(slime_node.global_position)
	if local_slime_pos.y < min_drain_depth or local_slime_pos.y > max_drain_height:
		return
	_feed_step(slime_node, delta)

func _feed_step(slime_node: CharacterBody3D, delta: float):
	if not slime_node.mass_manager:
		return
	var feed_speed = 0.3 * delta
	var available = slime_node.mass_manager.max_spendable()
	var amount = min(feed_speed, available)
	if amount <= 0.0:
		return
	slime_node.mass_manager.take_elemental_damage(amount)
	stored_mass += amount

func _get_entire_network() -> Array:
	var visited := {} # Dictionary usado como set: .has() es O(1), Array.has() es O(n)
	var result := []
	var queue = [self]
	
	while queue.size() > 0:
		var current = queue.pop_front()
		if not visited.has(current) and is_instance_valid(current):
			visited[current] = true
			result.append(current)
			for neighbor in current.connected_splats:
				if not visited.has(neighbor):
					queue.append(neighbor)
			# Si este nodo toca un MassBagNode, sumamos también a los demás
			# charcos que tocan el MISMO núcleo — si no, cada charco que solo
			# toca al núcleo (sin tocarse entre sí) cuenta como una red de
			# tamaño 1, e infla la densidad de las venas sin sentido.
			if current.connected_mass_bag != null and is_instance_valid(current.connected_mass_bag):
				for sibling in current.connected_mass_bag.linked_splats:
					if is_instance_valid(sibling) and not visited.has(sibling):
						queue.append(sibling)
	return result

# ==========================================
# 🩺 NÚCLEO Y SISTEMA CIRCULATORIO (Hito 1)
# El núcleo es el nodo más antiguo de la red (mismo criterio que ya se usa
# para decidir quién dibuja el puente) — SALVO que haya un MassBagNode
# conectado en algún punto de la red, en cuyo caso ese siempre gana como
# núcleo (es el "punto central" que pediste). Se cachea en _cached_core y
# solo se recalcula cuando cambia una conexión (_mark_network_dirty), no
# cada frame — recalcular la red entera por nodo por frame es lo que
# causaba los tirones con varios charcos conectados.
# Sin tipo estricto en "core" porque puede ser un SplatNode o un MassBagNode.
# ==========================================
func get_network_core():
	if _cached_core == null or not is_instance_valid(_cached_core):
		_mark_network_dirty()
	return _cached_core

# Recalcula la red UNA vez y le avisa el resultado a todos los miembros,
# en vez de que cada uno la recalcule por su cuenta. También cachea el
# tamaño de la red (_cached_network_size), que _update_bridge_thickness
# usa para calcular densidad sin volver a recorrer la red cada frame.
func _mark_network_dirty():
	var network = _get_entire_network()
	var core = self
	var found_mass_bag = null
	for node in network:
		if not is_instance_valid(node):
			continue
		if node.connected_mass_bag != null and is_instance_valid(node.connected_mass_bag):
			found_mass_bag = node.connected_mass_bag
		if node.get_instance_id() < core.get_instance_id():
			core = node
	var size = network.size()
	if found_mass_bag != null:
		core = found_mass_bag
		size += 1

	# BFS enraizado en el núcleo: calcula, por cada charco, a cuántos saltos
	# de charco-a-charco está del núcleo (_cached_hop_distance) y a quién le
	# manda su excedente (_cached_next_hop). Con esto, _circulate_excess_mass
	# ya no manda todo directo al núcleo — lo releva de salto en salto, así
	# los charcos cerca del núcleo terminan con más masa (retransmiten lo de
	# los que están más lejos) y el degradado sale solo, sin fórmula aparte.
	var hop_distance = {}
	var next_hop = {}
	var queue = []

	if core is MassBagNode:
		for splat in core.linked_splats:
			if is_instance_valid(splat) and network.has(splat):
				hop_distance[splat] = 1
				next_hop[splat] = core
				queue.append(splat)
	else:
		hop_distance[core] = 0
		next_hop[core] = core
		queue.append(core)

	while queue.size() > 0:
		var current = queue.pop_front()
		for neighbor in current.connected_splats:
			if is_instance_valid(neighbor) and not hop_distance.has(neighbor):
				hop_distance[neighbor] = hop_distance[current] + 1
				next_hop[neighbor] = current
				queue.append(neighbor)

	for node in network:
		if is_instance_valid(node):
			node._cached_core = core
			node._cached_network_size = size
			node._cached_hop_distance = hop_distance.get(node, 0)
			node._cached_next_hop = next_hop.get(node, core)

func _process(delta: float):
	var core = get_network_core()
	_circulate_excess_mass(delta, core)
	_update_bridge_thickness(core)
	_check_core_state(core)
	_update_core_visual_scale(core)
	_check_idle_cleanup(delta, core)

# Todo lo que un charco periférico junte por encima de min_vein_mass fluye
# hacia SU vecino más cercano al núcleo (_cached_next_hop) — no directo al
# núcleo. Con una tasa fija en decimales, entrada y salida se igualaban al
# mismo ritmo en todos los charcos por igual y no quedaba degradado real.
# Ahora, si el excedente alcanza para un paquete completo (packet_size), se
# manda entero (con cooldown, para no mandar uno por frame) — eso obliga a
# acumular antes de soltar, y los charcos cerca del núcleo (reciben de
# varios detrás) acumulan y sueltan paquetes más seguido que los lejanos.
# Si el excedente no alcanza para un paquete, circula en decimales chicos.
func _circulate_excess_mass(delta: float, core):
	if core == self:
		return
	_packet_cooldown -= delta
	if stored_mass <= min_vein_mass:
		return
	var target = core
	if _cached_next_hop != null and is_instance_valid(_cached_next_hop):
		target = _cached_next_hop
	var surplus = stored_mass - min_vein_mass
	# El umbral para mandar paquete es packet_size, no un valor más alto
	# aparte (packet_threshold) — si no, un charco puede recibir un paquete
	# y quedar en una "zona muerta" (más que packet_size pero menos que el
	# umbral viejo), goteando en decimales lentísimos en vez de seguir la
	# cadena. Así, apenas tiene para mandar un paquete completo, lo manda.
	if surplus >= packet_size and _packet_cooldown <= 0.0:
		stored_mass -= packet_size
		target.stored_mass += packet_size
		_packet_cooldown = packet_cooldown_time
		# El que RECIBE también entra en cooldown, como si él mismo lo
		# hubiera mandado — si no, como todos arrancan en cooldown 0, un
		# paquete puede retransmitirse salto tras salto en el mismo frame
		# ("teletransportarse") en vez de tardar un cooldown por salto.
		if target is SplatNode:
			target._packet_cooldown = target.packet_cooldown_time
	elif surplus > 0.0:
		var excess = min(circulation_rate * delta, surplus)
		stored_mass -= excess
		target.stored_mass += excess

# El grosor de cada vena refleja la masa LOCAL de sus dos extremos (el
# mínimo entre ambos, como un cuello de botella) — ya no la densidad de
# toda la red. Antes esto no funcionaba porque todos los periféricos
# convergían al mismo min_vein_mass; ahora que la circulación releva de
# salto en salto, los charcos cerca del núcleo sí acumulan más que los
# lejanos, así que el grosor local ya refleja el degradado por distancia.
func _update_bridge_thickness(core):
	if not vein_like_connections:
		return
	for neighbor in visual_bridges.keys():
		if not is_instance_valid(neighbor) or not is_instance_valid(visual_bridges[neighbor]):
			continue
		var box: BoxMesh = visual_bridges[neighbor].mesh
		var flow_mass = min(stored_mass, neighbor.stored_mass)
		var thickness = 0.1 + clamp(flow_mass * 0.8, 0.0, 2.0)
		box.size.x = thickness
		box.size.y = thickness * 0.75

	if connected_mass_bag != null and is_instance_valid(connected_mass_bag) and _mass_bag_bridge != null and is_instance_valid(_mass_bag_bridge):
		var bag_box: BoxMesh = _mass_bag_bridge.mesh
		var bag_flow = min(stored_mass, connected_mass_bag.stored_mass)
		var bag_thickness = 0.1 + clamp(bag_flow * 0.8, 0.0, 2.0)
		bag_box.size.x = bag_thickness
		bag_box.size.y = bag_thickness * 0.75
		_update_mass_bag_bridge_transform()

	# DEBUG TEMPORAL: activá debug_print_network_stats en el inspector cuando
	# quieras ver estos números — por defecto está apagado para no spamear.
	if debug_print_network_stats and Engine.get_frames_drawn() % 60 == 0:
		print("[SplatNode] hop=%d  stored_mass=%.3f  next_hop_es_massbag=%s  core_es_massbag=%s" % [_cached_hop_distance, stored_mass, _cached_next_hop is MassBagNode, core is MassBagNode])

# Solo el núcleo puede volverse sólido — los periféricos existen para
# extender el área, nunca pasan a INERT_BLOB. Al cruzar blob_threshold se
# reemplaza a sí mismo por un MassBagNode real (Hito 3 completo: antes solo
# cambiaba esta bandera y nada la escuchaba, así que un núcleo orgánico
# podía cruzar el umbral y no pasaba nada).
# Si el núcleo ya es un MassBagNode, self nunca es == core, así que esto
# no hace nada — correcto: ya está sólido, no hay nada que transicionar.
func _check_core_state(core):
	if self != core:
		return
	if current_state == MassState.PUDDLE and stored_mass >= blob_threshold:
		current_state = MassState.INERT_BLOB
		state_changed.emit(current_state)
		_solidify()

# Reemplaza este SplatNode (Area3D) por un MassBagNode (StaticBody3D) real,
# en la misma posición y con la misma masa/color. Los periféricos no
# necesitan que nadie los avise: al perder este nodo (_on_area_exited)
# recalculan la red sin él, y el detector del MassBagNode nuevo (que nace
# en el mismo lugar) los detecta solo.
func _solidify():
	var mass_bag = MassBagNode.new()
	get_tree().current_scene.add_child(mass_bag)
	mass_bag.setup(global_position, surface_normal, stored_mass, stored_element, current_color)
	queue_free()

# Solo el núcleo escala su propio mesh/decal — los periféricos se quedan
# chicos por diseño (Hito 1). Escala solo lo visual, no el nodo entero,
# para no alterar sin querer el radio de detección de red/circulación.
# Mismo razonamiento que arriba: si el núcleo es un MassBagNode, esto no
# hace nada acá (MassBagNode escala su propio visual por su cuenta).
func _update_core_visual_scale(core):
	if self != core:
		return
	var target_scale = Vector3.ONE * (1.0 + stored_mass * core_growth_rate)
	if _visual_mesh:
		_visual_mesh.scale = target_scale
	if _visual_decal:
		_visual_decal.scale = target_scale

# ==========================================
# 🩸 SLIME COMO "SACO DE RESERVA" (mantener F)
# Todavía puramente visual: dibuja y engorda una vena entre el charco de la
# red más cercano al jugador y el propio jugador, mientras se mantiene F.
# El traspaso real de masa queda para cuando se defina el Cordón Umbilical
# (Hito 6) — acá solo se conecta y engorda según current_mass_level del
# jugador, para no adelantarse a esa decisión.
# `press_f` ya existe y ya llama a _drain_puddles() en slime_base.gd — esto
# se engancha ahí mismo, no es un input nuevo (ver edición en slime_base.gd).
# ==========================================
var _reserve_bridge: MeshInstance3D = null

func process_reserve_link(slime_node: Node3D, is_holding: bool):
	if not is_holding:
		if _reserve_bridge != null and is_instance_valid(_reserve_bridge):
			_reserve_bridge.queue_free()
			_reserve_bridge = null
		return

	var network = _get_entire_network()
	if network.is_empty():
		return

	# El charco físicamente más cercano al jugador es el que dibuja la conexión,
	# para que la vena tenga sentido espacial (no necesariamente el núcleo).
	var closest: SplatNode = network[0]
	var closest_dist = closest.global_position.distance_squared_to(slime_node.global_position)
	for node in network:
		if not is_instance_valid(node):
			continue
		var d = node.global_position.distance_squared_to(slime_node.global_position)
		if d < closest_dist:
			closest = node
			closest_dist = d

	closest._draw_reserve_bridge(slime_node)

func _draw_reserve_bridge(slime_node: Node3D):
	if _reserve_bridge == null or not is_instance_valid(_reserve_bridge):
		_reserve_bridge = MeshInstance3D.new()
		_reserve_bridge.mesh = BoxMesh.new()
		_reserve_bridge.material_override = _get_cached_material(current_color)
		add_child(_reserve_bridge)

	var box: BoxMesh = _reserve_bridge.mesh
	var dist = global_position.distance_to(slime_node.global_position)

	# Grosor según cuánta masa "de reserva" trae el jugador encima.
	var reserve_mass = 0.0
	if "mass_manager" in slime_node and slime_node.mass_manager:
		reserve_mass = slime_node.mass_manager.current_mass_level
	var thickness = 0.15 + clamp(reserve_mass * 0.15, 0.0, 1.0)
	box.size = Vector3(thickness, thickness * 0.75, dist)

	_reserve_bridge.global_position = (global_position + slime_node.global_position) / 2.0
	if _reserve_bridge.global_position.distance_squared_to(slime_node.global_position) > 0.001:
		_reserve_bridge.look_at(slime_node.global_position, Vector3.UP)

# ==========================================
# 📦 Contratos vacíos reservados para Fase 3 (Hito 1) — no implementar todavía
# ==========================================
func try_infuse_element(element: String) -> bool:
	return false  # TODO Fase 3: trampa elemental (FIRE/STONE) o brea

func try_capture_item(item: Node3D) -> bool:
	return false  # TODO Fase 3: envolver ítems arrojados dentro de la masa
