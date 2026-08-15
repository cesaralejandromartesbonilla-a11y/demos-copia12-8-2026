extends StaticBody3D
class_name MassBagNode

# La Bolsa de Masa Primitiva: a diferencia de SplatNode (que nace en
# collision_layer = 0 y solo se vuelve sólido si cruza blob_threshold por
# circulación), esta nace sólida directamente — es la implementación física
# del Hito 3, pero disparable a mano en vez de esperar a que la red la cruce.
#
# Se integra con SplatNode vía su propio Area3D detector (ver _ready/
# _on_detector_area_entered), que crece junto con la esfera visual — antes
# dependía de que el charco detectara el cuerpo físico de la bolsa
# (body_entered), lo cual se volvía frágil apenas la esfera crecía o se
# movía (el offset de anclaje). Cuando se conecta, se convierte en el
# núcleo de toda la red conectada — la circulación empieza a fluir hacia
# acá en vez de hacia el charco más viejo.

var stored_mass: float = 1.0
var stored_element: String = "BASE"
var surface_normal: Vector3 = Vector3.UP
var current_radius: float = 0.6 # Expuesto para que CameraController sepa hasta dónde puede volar (modo buceo)

var _visual_mesh: MeshInstance3D = null
var _visual_collision: CollisionShape3D = null
var _base_radius: float = 0.6
var _anchor_position: Vector3 = Vector3.ZERO # El punto de impacto real — global_position ahora se offsetea desde acá

var linked_splats: Array = [] # SplatNode que tocan este núcleo directamente
var _detector: Area3D = null # Detecta charcos cercanos con un Area3D propio que crece con la esfera — más confiable que depender de que la esfera (que se mueve y crece) toque la caja fija y delgada del charco.
var _detector_shape: SphereShape3D = null

@export var terrain_check_mask: int = 1 # ⚠️ Verificar: qué capa usan tus paredes/piso reales, para el tope de crecimiento
@export var enable_growth_cap: bool = true # Apagalo si el tope por raycast da problemas y preferís el crecimiento libre de antes
var _max_radius_from_terrain: float = 999.0
var _cap_check_timer: float = 0.0

@export var player_detection_mask: int = 2 # ⚠️ Verificar: qué capa usa el CharacterBody3D del jugador
var _player_detector: Area3D = null
var _player_detector_shape: SphereShape3D = null

func _ready():
	add_to_group("mass_bags")
	# Sin capa propia — no bloquea nada por colisión física (el jugador,
	# proyectiles y andamio la atraviesan). Todo lo que necesita para
	# integrarse a la red pasa por el detector de abajo, no por esto.
	# ⚠️ Si más adelante necesitás que bloquee a otra cosa específica
	# (enemigos, por ejemplo), ahí sí conviene darle una capa dedicada.
	collision_layer = 0
	collision_mask = 0

	# Detector propio: un Area3D hijo, en la misma capa que usan los
	# SplatNode entre sí (8), que se agranda junto con la esfera visual.
	_detector = Area3D.new()
	_detector.name = "MassBagDetector"
	_detector.collision_layer = 0
	_detector.collision_mask = 8
	_detector.monitorable = true
	_detector.monitoring = true
	_detector.area_entered.connect(_on_detector_area_entered)
	_detector.area_exited.connect(_on_detector_area_exited)
	add_child(_detector)

	_detector_shape = SphereShape3D.new()
	var detector_col = CollisionShape3D.new()
	detector_col.shape = _detector_shape
	_detector.add_child(detector_col)

	# Detector de jugador: aparte del de charcos, porque el jugador no
	# necesariamente vive en la misma capa (8) que la red. Como esta bolsa
	# ya no bloquea físicamente (collision_layer = 0), esto es lo único que
	# nos avisa que el jugador está "adentro" para activar el modo buceo.
	_player_detector = Area3D.new()
	_player_detector.name = "MassBagPlayerDetector"
	_player_detector.collision_layer = 0
	_player_detector.collision_mask = player_detection_mask
	_player_detector.monitorable = false
	_player_detector.monitoring = true
	_player_detector.body_entered.connect(_on_player_detector_body_entered)
	_player_detector.body_exited.connect(_on_player_detector_body_exited)
	add_child(_player_detector)

	_player_detector_shape = SphereShape3D.new()
	var player_col = CollisionShape3D.new()
	player_col.shape = _player_detector_shape
	_player_detector.add_child(player_col)

func setup(impact_position: Vector3, impact_normal: Vector3, mass: float, element: String, bag_color: Color):
	_anchor_position = impact_position
	surface_normal = impact_normal
	stored_mass = mass
	stored_element = element
	_base_radius = 0.6 + stored_mass * 0.3  # tamaño de partida, según la masa con la que se disparó

	# Misma orientación robusta que usa SplatNode.setup()
	var x_axis = Vector3.UP.cross(surface_normal).normalized()
	if x_axis.length_squared() == 0:
		x_axis = Vector3.RIGHT
	var z_axis = surface_normal.cross(x_axis).normalized()
	global_transform.basis = Basis(x_axis, surface_normal, z_axis)

	# Offset a lo largo de la normal: antes global_position quedaba en el
	# punto de impacto mismo, así que la esfera nacía medio enterrada en la
	# superficie y crecía cada vez más adentro. Ahora crece hacia afuera.
	global_position = _anchor_position + surface_normal * _base_radius

	_build_visuals_and_collision(bag_color)

func _build_visuals_and_collision(bag_color: Color):
	var mesh_inst = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = _base_radius
	sphere.height = _base_radius * 1.6
	mesh_inst.mesh = sphere
	# Reutiliza el mismo caché de materiales por color que SplatNode (static),
	# para no sumar un material único más por cada bolsa.
	mesh_inst.material_override = SplatNode._get_cached_material(bag_color)
	add_child(mesh_inst)
	_visual_mesh = mesh_inst

	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = _base_radius
	col.shape = shape
	add_child(col)
	_visual_collision = col

# Sigue creciendo si una red de SplatNode conectada le sigue mandando masa
# por circulación (ver SplatNode._circulate_excess_mass). StaticBody3D
# permite redimensionar la shape en vivo sin el jitter que tendría un
# RigidBody3D simulado. El tope por raycast evita que crezca a través de
# paredes/techo cercanos — se revisa cada medio segundo, no cada frame.
func _process(delta: float):
	_cap_check_timer -= delta
	if enable_growth_cap and _cap_check_timer <= 0.0:
		_update_terrain_cap()
		_cap_check_timer = 0.5

	var target_radius = 0.6 + stored_mass * 0.3
	var radius = min(target_radius, _max_radius_from_terrain) if enable_growth_cap else target_radius

	global_position = _anchor_position + surface_normal * radius
	current_radius = radius
	if _visual_mesh and _visual_mesh.mesh is SphereMesh:
		_visual_mesh.mesh.radius = radius
		_visual_mesh.mesh.height = radius * 1.6
	if _visual_collision and _visual_collision.shape is SphereShape3D:
		_visual_collision.shape.radius = radius
	if _player_detector_shape:
		_player_detector_shape.radius = radius
	if _detector_shape:
		_detector_shape.radius = radius + 0.5 # margen extra, para detectar charcos un poco antes de que la esfera los toque

# Tira rayos desde el punto de anclaje en varias direcciones (la normal de
# la superficie, y los 4 costados según la orientación) para encontrar el
# obstáculo más cercano, y usa esa distancia como techo del radio. Es una
# aproximación (no un chequeo de forma real), pero evita el caso más obvio
# de "crecer directo a través de una pared".
func _update_terrain_cap():
	var space_state = get_world_3d().direct_space_state
	var directions = [
		surface_normal,
		global_transform.basis.x,
		-global_transform.basis.x,
		global_transform.basis.z,
		-global_transform.basis.z,
	]
	var closest = 999.0
	for dir in directions:
		var query = PhysicsRayQueryParameters3D.create(_anchor_position, _anchor_position + dir.normalized() * 25.0)
		query.collision_mask = terrain_check_mask
		query.exclude = [get_rid()]
		var result = space_state.intersect_ray(query)
		if result:
			var dist = _anchor_position.distance_to(result.position)
			if dist < closest:
				closest = dist
	_max_radius_from_terrain = max(0.6, closest * 0.9) # margen chico para no quedar pegado justo a la pared

# Reemplaza la vieja detección basada en body_entered del lado de SplatNode
# (que dependía de que la esfera, moviéndose y creciendo, tocara justo la
# caja fija y delgada de detección del charco — muy frágil). Acá el que
# detecta es este Area3D propio, que se agranda junto con la esfera.
func _on_detector_area_entered(area: Area3D):
	if area is SplatNode and area.connected_mass_bag == null:
		area.connected_mass_bag = self
		linked_splats.append(area)
		area._create_mass_bag_bridge()
		area._mark_network_dirty()

func _on_detector_area_exited(area: Area3D):
	if area is SplatNode and area.connected_mass_bag == self:
		linked_splats.erase(area)
		area.connected_mass_bag = null
		if area._mass_bag_bridge != null and is_instance_valid(area._mass_bag_bridge):
			area._mass_bag_bridge.queue_free()
		area._mass_bag_bridge = null
		area._mark_network_dirty()

# El jugador "entra" a la bolsa (ya no lo bloquea físicamente, ver _ready) —
# esto activa el modo buceo en su cámara, acotado al radio de esta bolsa
# en vez del propio cuerpo del jugador. Sin la pinza de ítems del estómago,
# que no aplica acá.
# El jugador "entra" a la bolsa (ya no lo bloquea físicamente, ver _ready) —
# esto activa el modo buceo en su cámara, acotado al radio de esta bolsa
# en vez del propio cuerpo del jugador. Sin la pinza de ítems del estómago,
# que no aplica acá.
# Sin exigir CharacterBody3D: el jugador ahora también puede ser un
# RigidBody3D en ciertas formas — lo que importa es que tenga camera_controller.
func _on_player_detector_body_entered(body: Node3D):
	if "camera_controller" in body and body.camera_controller:
		body.camera_controller.enter_mass_bag_mode(self)

func _on_player_detector_body_exited(body: Node3D):
	if "camera_controller" in body and body.camera_controller:
		body.camera_controller.exit_mass_bag_mode()

# Interacción directa (Hito 6/7) para cuando esta bolsa está sola, sin
# ninguna red de SplatNode alrededor — get_overlapping_areas() no la
# encuentra (es un cuerpo, no un área), así que slime_base.gd la busca
# aparte entre get_overlapping_bodies() y llama a estas dos directamente.
func process_network_feed(slime_node: CharacterBody3D, delta: float):
	if not slime_node.mass_manager:
		return
	var feed_speed = 0.3 * delta
	var available = slime_node.mass_manager.max_spendable()
	var amount = min(feed_speed, available)
	if amount <= 0.0:
		return
	slime_node.mass_manager.take_elemental_damage(amount)
	stored_mass += amount

func process_network_drain(slime_node: CharacterBody3D, delta: float):
	if not slime_node.mass_manager:
		return
	var drain_speed = 1.5 * delta
	var amount = min(drain_speed, stored_mass)
	if amount <= 0.0:
		return
	stored_mass -= amount
	slime_node.mass_manager.add_mass(amount)

# Mismos contratos vacíos que SplatNode, reservados para Fase 3.
func try_infuse_element(element: String) -> bool:
	return false  # TODO Fase 3: trampa elemental (FIRE/STONE) o brea

func try_capture_item(item: Node3D) -> bool:
	return false  # TODO Fase 3: envolver ítems arrojados dentro de la masa
