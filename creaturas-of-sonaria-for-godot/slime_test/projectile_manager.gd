extends Node
class_name ProjectileManager

enum ProjType { STICKY, BOUNCY, EXPLOSIVE, STREAM, PAINT, MASS_BAG }

@onready var slime: CharacterBody3D = get_parent()
var current_projectile_type: ProjType = ProjType.STICKY
var extra_mass: float = 0.0
var last_printed_mass: float = 0.0

# 📊 COSTOS DE MASA SEGÚN EL PROYECTIL
const COST_STICKY: float = 0.2
const COST_BOUNCY: float = 0.15
const COST_EXPLOSIVE: float = 0.4
const COST_STREAM: float = 0.05 # Esto será por tick/segundo más adelante
const COST_MASS_BAG: float = 1.0 # Bolsa de masa primitiva: núcleo sólido de una — cuesta caro a propósito
const CHARGE_SAFETY_MARGIN: float = 0.2 # Colchón extra al cargar, por encima del piso duro de MassManager

# ==========================================
# 🔄 CAMBIO DE MUNICIÓN
# ==========================================
func switch_projectile(new_type: ProjType):
	current_projectile_type = new_type
	print("Proyectil cambiado a: ", ProjType.keys()[current_projectile_type])

func cycle_next_projectile():
	var next_type = (current_projectile_type + 1) % ProjType.size()
	switch_projectile(next_type as ProjType)

# ==========================================
# 🔥 GATILLO PRINCIPAL Y FÍSICAS DE SLIME
# ==========================================
func fire():
	var base_cost = _get_current_base_cost()
	var total_mass = base_cost + extra_mass
	
	# Comprobación de seguridad vital (ahora vive en MassManager, no acá)
	if total_mass > slime.mass_manager.max_spendable():
		print("No hay masa suficiente. Núcleo en riesgo.")
		return
		
	# Calculamos qué porcentaje de nuestro cuerpo representa este disparo
	var mass_ratio = total_mass / slime.mass_manager.current_mass_level
	
	# 🚀 CASO 1: AUTOLANZAMIENTO (Masa > 70%)
	if mass_ratio >= 0.7:
		print("¡SOBRECARGA! El Slime se lanza a sí mismo y deja su masa atrás.")
		
		# 1. Generamos el charco de masa ANTES de gastarla
		_drop_residual_mass(total_mass)
		
		# 2. Consumimos la masa del cuerpo
		_consume_mass(total_mass) 
		
		if slime.camera_controller:
			var aim_dir = slime.camera_controller.get_aim_direction()
			slime.global_position.y += 0.2
			# Aplicamos la velocidad del despegue
			slime.velocity = (aim_dir + Vector3(0, 0.5, 0)).normalized() * (40.0 + (total_mass * 3.0))
			
		extra_mass = 0.0
		slime.visuals.scale = Vector3.ONE * slime.current_liquid_scale 
		return
	# 💥 CASO 2: RETROCESO (Masa > 30%)
	if mass_ratio >= 0.3:
		print("Disparo pesado: Aplicando retroceso.")
		if slime.camera_controller:
			var aim_dir = slime.camera_controller.get_aim_direction()
			slime.global_position.y += 0.1 # Pequeño despegue
			slime.velocity -= aim_dir * (15.0 * total_mass) # Empuje hacia atrás
			
	# 💧 CASO 3: DISPARAR PROYECTIL (Normal o con Retroceso)
	match current_projectile_type:
		ProjType.STICKY: _fire_sticky(total_mass)
		ProjType.BOUNCY: _fire_bouncy(total_mass)
		ProjType.EXPLOSIVE: _fire_explosive(total_mass)
		ProjType.STREAM: _fire_stream(total_mass)
		ProjType.PAINT: _fire_paint(total_mass)
		ProjType.MASS_BAG: _fire_mass_bag(total_mass)
	# Reseteamos la carga para el siguiente disparo
	extra_mass = 0.0

func _drop_residual_mass(mass_amount: float):
	var current_element = slime.matter_controller.current_element
	var custom_mat = slime.matter_controller.current_custom_material
	
	var residual_blob = StickyNode.new()
	residual_blob.add_to_group("slime_projectiles")
	residual_blob.stored_mass = mass_amount 
	residual_blob.stored_element = current_element
	
	residual_blob.mass = mass_amount * 3.0 # Muy pesado para que no rebote lejos
	residual_blob.gravity_scale = 2.0
	
	var material = _resolve_blob_material(custom_mat, current_element)
	_attach_blob_visuals_and_collision(residual_blob, 0.5 * mass_amount, 1.0 * mass_amount, material)
	
	# Lo instanciamos ligeramente ABAJO y ATRÁS del slime para que no lo re-absorba 
	# inmediatamente al salir disparado en el mismo frame.
	if slime.camera_controller:
		var aim_dir = slime.camera_controller.get_aim_direction()
		residual_blob.global_position = slime.global_position - (aim_dir * 1.0)

func _consume_mass(amount: float):
	if slime.mass_manager: slime.mass_manager.take_elemental_damage(amount)
	
	var tween = get_tree().create_tween()
	tween.tween_property(slime.visuals, "scale", Vector3.ONE * (slime.current_liquid_scale * 0.8), 0.05)
	tween.tween_property(slime.visuals, "scale", Vector3.ONE * slime.current_liquid_scale, 0.2).set_trans(Tween.TRANS_BOUNCE)

# ==========================================
# 🧩 HELPERS COMPARTIDOS (Hito 0)
# Solo lo que es 100% idéntico entre proyectiles: resolución de material
# y armado de mesh/collision. La instanciación del nodo, sus físicas y su
# impulso de disparo siguen viviendo en cada _fire_X por separado a propósito.
# ==========================================
func _resolve_blob_material(custom_mat: Material, current_element: String) -> Material:
	if custom_mat != null:
		return custom_mat
	if slime.transformation_module and slime.transformation_module.elemental_materials.has(current_element):
		return slime.transformation_module.elemental_materials[current_element]
	return slime.matter_controller.cached_base_liquid_mat

func _attach_blob_visuals_and_collision(blob: Node3D, radius: float, height: float, material: Material) -> void:
	var mesh_inst = MeshInstance3D.new()
	var blob_mesh = SphereMesh.new()
	blob_mesh.radius = radius
	blob_mesh.height = height
	mesh_inst.mesh = blob_mesh
	mesh_inst.material_override = material

	var col = CollisionShape3D.new()
	col.shape = SphereShape3D.new()
	col.shape.radius = radius

	blob.add_child(mesh_inst)
	blob.add_child(col)

	get_tree().current_scene.add_child(blob)
	if blob.has_method("inherit_slime_visuals"):
		blob.inherit_slime_visuals(material)

# ==========================================
# 🕸️ PROYECTIL PEGAJOSO
# ==========================================
func _fire_sticky(total_mass: float):
	_consume_mass(total_mass)
	
	var current_element = slime.matter_controller.current_element
	var custom_mat = slime.matter_controller.current_custom_material
	
	var sticky_blob = StickyNode.new()
	sticky_blob.add_to_group("slime_projectiles")
	sticky_blob.stored_mass = total_mass # <-- Guarda TODA la masa cargada
	sticky_blob.stored_element = current_element
	
	sticky_blob.mass = total_mass * 2.5 # Físicas pesadas
	sticky_blob.gravity_scale = 1.2
	sticky_blob.continuous_cd = true 
	
	# <-- El tamaño visual escala con la masa
	var material = _resolve_blob_material(custom_mat, current_element)
	_attach_blob_visuals_and_collision(sticky_blob, 0.5 * total_mass, 1.0 * total_mass, material)
	
	if slime.camera_controller:
		var aim_dir = slime.camera_controller.get_aim_direction()
		# Lo spawneamos más lejos si es más grande para que no choque al salir
		sticky_blob.global_position = slime.hold_position.global_position + (aim_dir * (1.5 + total_mass))
		sticky_blob.apply_central_impulse((aim_dir + Vector3(0, 0.1, 0)).normalized() * 25.0)

# ==========================================
# 🏀 2. PROYECTIL SALTARÍN (EN ESPERA)
# ==========================================
func _fire_bouncy(total_mass: float):
	_consume_mass(total_mass)
	var current_element = slime.matter_controller.current_element
	var custom_mat = slime.matter_controller.current_custom_material
	
	var bouncy_blob = BouncyNode.new()
	bouncy_blob.add_to_group("slime_projectiles")
	bouncy_blob.stored_mass = total_mass
	bouncy_blob.stored_element = current_element
	
	bouncy_blob.mass = total_mass * 1.5 # Más ligero que el pegajoso
	bouncy_blob.gravity_scale = 1.0
	bouncy_blob.continuous_cd = true
	
	# Añadimos un material de rebote
	var phys_mat = PhysicsMaterial.new()
	phys_mat.bounce = 0.85 # 85% de energía conservada al chocar
	phys_mat.friction = 0.1  # Resbala fácil
	bouncy_blob.physics_material_override = phys_mat
	
	var material = _resolve_blob_material(custom_mat, current_element)
	_attach_blob_visuals_and_collision(bouncy_blob, 0.5 * total_mass, 1.0 * total_mass, material)
	
	if slime.camera_controller:
		var aim_dir = slime.camera_controller.get_aim_direction()
		bouncy_blob.global_position = slime.hold_position.global_position + (aim_dir * (1.5 + total_mass))
		# Se lanza un poco más rápido por ser aerodinámico
		bouncy_blob.apply_central_impulse((aim_dir + Vector3(0, 0.15, 0)).normalized() * 30.0)

# ==========================================
# 💣 3. PROYECTIL EXPLOSIVO
# ==========================================
func _fire_explosive(total_mass: float):
	_consume_mass(total_mass)
	var current_element = slime.matter_controller.current_element
	var custom_mat = slime.matter_controller.current_custom_material
	
	var bomb_blob = ExplosiveNode.new()
	bomb_blob.add_to_group("slime_projectiles")
	bomb_blob.stored_mass = total_mass
	bomb_blob.stored_element = current_element
	
	# 🔥 FÍSICAS PESADAS: Es denso y cae rápido
	bomb_blob.mass = total_mass * 4.0 
	bomb_blob.gravity_scale = 1.8
	bomb_blob.continuous_cd = true
	
	# Lo hacemos un poco más grande visualmente para imponer
	var material = _resolve_blob_material(custom_mat, current_element)
	_attach_blob_visuals_and_collision(bomb_blob, 0.6 * total_mass, 1.2 * total_mass, material)
	
	if slime.camera_controller:
		var aim_dir = slime.camera_controller.get_aim_direction()
		bomb_blob.global_position = slime.hold_position.global_position + (aim_dir * (2.0 + total_mass))
		bomb_blob.apply_central_impulse((aim_dir + Vector3(0, 0.25, 0)).normalized() * 35.0)

# ==========================================
# 💦 4. CHORRO
# ==========================================
func _fire_stream(total_mass: float):
	_consume_mass(total_mass) 
	
	var stream = StreamEmitter.new()
	stream.fuel = total_mass 
	stream.current_element = slime.matter_controller.current_element
	
	if slime.matter_controller.current_custom_material:
		stream.stream_material = slime.matter_controller.current_custom_material
	else:
		stream.stream_material = slime.matter_controller.cached_base_liquid_mat
	
	if slime.hold_position:
		slime.hold_position.add_child(stream)

# ==========================================
# 🎨 5. PROYECTIL DE PINTURA (SPLAT)
# ==========================================
func _fire_paint(total_mass: float):
	_consume_mass(total_mass)
	var current_element = slime.matter_controller.current_element
	var custom_mat = slime.matter_controller.current_custom_material
	var space_state = slime.get_world_3d().direct_space_state
	var cam = slime.camera_controller.spring_arm
	var start = cam.global_position
	var end = start + (-cam.global_transform.basis.z * 50.0)
	var query = PhysicsRayQueryParameters3D.create(start, end)
	query.exclude = [slime.get_rid()] 
	var result = space_state.intersect_ray(query)
	
	if result:
		# ¡Impacto en superficie! Generamos el área de pintura instantáneamente
		var splat = SplatNode.new()
		splat.add_to_group("slime_projectiles")
		
		# Transferimos los datos de masa y elemento al charco
		splat.stored_mass = total_mass
		splat.stored_element = current_element
		
		# Intentamos extraer el color del material para teñir al Decal
		var paint_color = Color(0.2, 0.8, 0.2)
		if custom_mat != null and custom_mat is StandardMaterial3D:
			paint_color = custom_mat.albedo_color
		elif slime.matter_controller.cached_base_liquid_mat is StandardMaterial3D:
			paint_color = slime.matter_controller.cached_base_liquid_mat.albedo_color
			
		get_tree().current_scene.add_child(splat)
		
		# Llamamos a la función de anclaje direccional que definimos en el SplatNode
		splat.setup(result.position, result.normal, paint_color)
		
		# Efecto de retroceso muy ligero al disparar
		if slime.camera_controller:
			var aim_dir = slime.camera_controller.get_aim_direction()
			slime.velocity -= aim_dir * 5.0

# ==========================================
# 🫧 6. BOLSA DE MASA PRIMITIVA (núcleo sólido, a mano)
# Mismo patrón hitscan que _fire_paint (tiene sentido como estructura
# anclada, no como proyectil físico lanzado). Crea un MassBagNode: la
# implementación del Hito 3 (núcleo sólido), disparable directamente en
# vez de esperar a que una red la cruce por circulación.
# ==========================================
func _fire_mass_bag(total_mass: float):
	_consume_mass(total_mass)
	var current_element = slime.matter_controller.current_element
	var custom_mat = slime.matter_controller.current_custom_material
	var space_state = slime.get_world_3d().direct_space_state
	var cam = slime.camera_controller.spring_arm
	var start = cam.global_position
	var end = start + (-cam.global_transform.basis.z * 50.0)
	var query = PhysicsRayQueryParameters3D.create(start, end)
	query.exclude = [slime.get_rid()]
	var result = space_state.intersect_ray(query)

	if result:
		var mass_bag = MassBagNode.new()

		var bag_color = Color(0.2, 0.8, 0.2)
		if custom_mat != null and custom_mat is StandardMaterial3D:
			bag_color = custom_mat.albedo_color
		elif slime.matter_controller.cached_base_liquid_mat is StandardMaterial3D:
			bag_color = slime.matter_controller.cached_base_liquid_mat.albedo_color

		get_tree().current_scene.add_child(mass_bag)
		mass_bag.setup(result.position, result.normal, total_mass, current_element, bag_color)

		if slime.camera_controller:
			var aim_dir = slime.camera_controller.get_aim_direction()
			slime.velocity -= aim_dir * 8.0 # Retroceso notorio: es un disparo caro

# ==========================================
# ⚖️ SISTEMA DE CARGA DE MASA
# ==========================================


func adjust_mass(amount: float):
	var base_cost = _get_current_base_cost()
	var max_available = slime.mass_manager.max_spendable(CHARGE_SAFETY_MARGIN)
	
	extra_mass += amount
	if extra_mass < 0.0: extra_mass = 0.0
	
	if (base_cost + extra_mass) > max_available:
		extra_mass = max(0.0, max_available - base_cost)
		
	var total = base_cost + extra_mass
	
	# Imprime solo cuando sube/baja 0.1 de masa
	var rounded_total = snapped(total, 0.1)
	if rounded_total != last_printed_mass:
		print("⚡ Masa cargada: ", rounded_total, " / ", snapped(slime.mass_manager.current_mass_level, 0.1))
		last_printed_mass = rounded_total
		
		# 🔥 EFECTO VISUAL DE CARGA: El slime "infla" la boca o el cuerpo un poco
		if slime.visuals:
			var charge_bulge = 1.0 + (extra_mass * 0.15)
			slime.visuals.scale = Vector3(slime.current_liquid_scale * charge_bulge, slime.current_liquid_scale * 0.9, slime.current_liquid_scale * charge_bulge)

func _get_current_base_cost() -> float:
	match current_projectile_type:
		ProjType.STICKY: return COST_STICKY
		ProjType.BOUNCY: return COST_BOUNCY
		ProjType.EXPLOSIVE: return COST_EXPLOSIVE
		ProjType.STREAM: return COST_STREAM
		ProjType.MASS_BAG: return COST_MASS_BAG
	return 0.1
