extends Node
class_name ProjectileManager

enum ProjType { STICKY, BOUNCY, EXPLOSIVE, STREAM, PAINT }

@onready var slime: CharacterBody3D = get_parent()
var current_projectile_type: ProjType = ProjType.STICKY
var extra_mass: float = 0.0
var last_printed_mass: float = 0.0

# 📊 COSTOS DE MASA SEGÚN EL PROYECTIL
const COST_STICKY: float = 0.2
const COST_BOUNCY: float = 0.15
const COST_EXPLOSIVE: float = 0.4
const COST_STREAM: float = 0.05 # Esto será por tick/segundo más adelante

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
	
	# Comprobación de seguridad vital
	if slime.mass_manager.current_mass_level - total_mass < 1.0:
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
	
	var mesh_inst = MeshInstance3D.new()
	var blob_mesh = SphereMesh.new()
	blob_mesh.radius = 0.5 * mass_amount
	blob_mesh.height = 1.0 * mass_amount
	mesh_inst.mesh = blob_mesh
	
	if custom_mat != null: mesh_inst.material_override = custom_mat
	elif slime.transformation_module and slime.transformation_module.elemental_materials.has(current_element): 
		mesh_inst.material_override = slime.transformation_module.elemental_materials[current_element]
	else: mesh_inst.material_override = slime.matter_controller.cached_base_liquid_mat
		
	var col = CollisionShape3D.new()
	col.shape = SphereShape3D.new()
	col.shape.radius = 0.5 * mass_amount
	
	residual_blob.add_child(mesh_inst)
	residual_blob.add_child(col)
	
	get_tree().current_scene.add_child(residual_blob)
	if residual_blob.has_method("inherit_slime_visuals"): residual_blob.inherit_slime_visuals(mesh_inst.material_override)
	
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
	
	var mesh_inst = MeshInstance3D.new()
	var blob_mesh = SphereMesh.new()
	# <-- El tamaño visual escala con la masa
	blob_mesh.radius = 0.5 * total_mass
	blob_mesh.height = 1.0 * total_mass
	mesh_inst.mesh = blob_mesh
	
	if custom_mat != null: mesh_inst.material_override = custom_mat
	elif slime.transformation_module and slime.transformation_module.elemental_materials.has(current_element): 
		mesh_inst.material_override = slime.transformation_module.elemental_materials[current_element]
	else: mesh_inst.material_override = slime.matter_controller.cached_base_liquid_mat
		
	var col = CollisionShape3D.new()
	col.shape = SphereShape3D.new()
	col.shape.radius = 0.5 * total_mass
	
	sticky_blob.add_child(mesh_inst)
	sticky_blob.add_child(col)
	
	get_tree().current_scene.add_child(sticky_blob)
	if sticky_blob.has_method("inherit_slime_visuals"): sticky_blob.inherit_slime_visuals(mesh_inst.material_override)
	
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
	
	var mesh_inst = MeshInstance3D.new()
	var blob_mesh = SphereMesh.new()
	blob_mesh.radius = 0.5 * total_mass
	blob_mesh.height = 1.0 * total_mass
	mesh_inst.mesh = blob_mesh
	
	# Añadir material visual
	if custom_mat != null: mesh_inst.material_override = custom_mat
	elif slime.transformation_module and slime.transformation_module.elemental_materials.has(current_element): 
		mesh_inst.material_override = slime.transformation_module.elemental_materials[current_element]
	else: mesh_inst.material_override = slime.matter_controller.cached_base_liquid_mat
		
	var col = CollisionShape3D.new()
	col.shape = SphereShape3D.new()
	col.shape.radius = 0.5 * total_mass
	
	bouncy_blob.add_child(mesh_inst)
	bouncy_blob.add_child(col)
	
	get_tree().current_scene.add_child(bouncy_blob)
	if bouncy_blob.has_method("inherit_slime_visuals"): bouncy_blob.inherit_slime_visuals(mesh_inst.material_override)
	
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
	
	var mesh_inst = MeshInstance3D.new()
	var blob_mesh = SphereMesh.new()
	# Lo hacemos un poco más grande visualmente para imponer
	blob_mesh.radius = 0.6 * total_mass
	blob_mesh.height = 1.2 * total_mass
	mesh_inst.mesh = blob_mesh
	
	if custom_mat != null: mesh_inst.material_override = custom_mat
	elif slime.transformation_module and slime.transformation_module.elemental_materials.has(current_element): 
		mesh_inst.material_override = slime.transformation_module.elemental_materials[current_element]
	else: mesh_inst.material_override = slime.matter_controller.cached_base_liquid_mat
		
	var col = CollisionShape3D.new()
	col.shape = SphereShape3D.new()
	col.shape.radius = 0.6 * total_mass
	
	bomb_blob.add_child(mesh_inst)
	bomb_blob.add_child(col)
	
	get_tree().current_scene.add_child(bomb_blob)
	if bomb_blob.has_method("inherit_slime_visuals"): bomb_blob.inherit_slime_visuals(mesh_inst.material_override)
	
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
# ⚖️ SISTEMA DE CARGA DE MASA
# ==========================================


func adjust_mass(amount: float):
	var base_cost = _get_current_base_cost()
	var max_available = max(0.0, slime.mass_manager.current_mass_level - 1.2)
	
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
	return 0.1
