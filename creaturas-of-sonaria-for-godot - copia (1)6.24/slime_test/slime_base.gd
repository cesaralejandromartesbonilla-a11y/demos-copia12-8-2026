extends CharacterBody3D

enum Form { SLIME, STONE, FIRE, SKELETON, DEVOURER } 
var current_form = Form.SLIME
var base_visual_scale: Vector3 = Vector3.ONE

# --- Variables de Movimiento ---
var speed = 5.0
var jump_velocity = 4.5
var gravity: float = 9.8
var default_col_radius: float = 0.5
var default_col_height: float = 1.0
var max_health: float = 100.0
var current_health: float = 100.0
var cached_base_core_mat: StandardMaterial3D

# --- Variables de Cámara ---
@export var mouse_sensitivity: float = 0.003
@export var min_zoom: float = 2.0
@export var max_zoom: float = 10.0
@export var zoom_speed: float = 1.5
@export var zoom_smoothness: float = 8.0

var target_zoom = 5.0

# Referencias a los nodos
@onready var camera_pivot = $CameraPivot
@onready var spring_arm = $CameraPivot/SpringArm3D
@onready var form_label = $HUD/PanelContainer/Label
@onready var visuals = $Visuals
@onready var slime_mesh = $Visuals/SlimeMesh
@onready var stone_mesh = $Visuals/StoneMesh
@onready var FIRE_mesh = $Visuals/fireMesh
@onready var collision_shape = $CollisionShape3D
@onready var anim_player = $AnimationPlayer
@onready var consumer = $ConsumerComponent
@onready var skeleton_mesh = $Visuals/SkeletonMesh
@onready var transformation_module = $TransformationModule
@onready var building_sockets_manager = $BuildingSocketsManager
@onready var aim_ik_coordinator = $AimIKCoordinator
@onready var modular_hands_inventory = $ModularHandsInventory
@onready var magic_inventory = $MagicInventory
@onready var element_core = $Visuals/ElementCore

var is_build_mode: bool = false
var step_cycle: float = 0.0
var visual_base_y: float = 0.0
var unlocked_forms: Array[Form] = [Form.SLIME]
var current_form_index: int = 0
var current_element: String = "BASE"
var unlocked_elements: Array[String] = ["BASE"]
var current_custom_material: Material = null

func consume_element(new_element: String, custom_mat: Material = null):
	if new_element == "" or new_element == "NONE": return
		
	if not unlocked_elements.has(new_element):
		unlocked_elements.append(new_element)
		
	if current_element != new_element or custom_mat != null:
		current_element = new_element
		
		# Si regresamos a BASE, destruimos el material guardado
		if new_element == "BASE":
			current_custom_material = null
		elif custom_mat != null:
			current_custom_material = custom_mat
		
		# Asignamos el material extraído (o uno base si falló)
		var core_mat = current_custom_material
		
		if core_mat == null:
			core_mat = StandardMaterial3D.new()
			core_mat.emission_enabled = true
			core_mat.emission_energy_multiplier = 2.0
			match current_element:
				"FIRE": 
					core_mat.albedo_color = Color(1, 0.3, 0); core_mat.emission = Color(1, 0.3, 0)
				"STONE": 
					core_mat.albedo_color = Color(0.3, 0.8, 0.1); core_mat.emission = Color(0.3, 0.8, 0.1)
				_: 
					core_mat.albedo_color = Color(0, 0.5, 1); core_mat.emission = Color(0, 0.5, 1)
					
		element_core.material_override = core_mat
		transformation_module.apply_element_only(self, current_element)
		form_label.text = "Forma: " + Form.keys()[current_form] + " de " + current_element

# Función para añadir formas al inventario
func unlock_form(new_form: Form):
	if not unlocked_forms.has(new_form):
		unlocked_forms.append(new_form)
		print("¡Nueva forma añadida al inventario!")
		# Opcional: Transformarse automáticamente en lo que acabas de comer
		#switch_to_form_index(unlocked_forms.size() - 1)

# Función para rotar entre las formas del inventario
func cycle_form(direction: int):
	# direction será 1 (siguiente) o -1 (anterior)
	if unlocked_forms.size() <= 1:
		return # No hay nada que cambiar si solo tenemos 1 forma
		
	var new_index = current_form_index + direction
	
	# Hacer que el ciclo sea infinito (si llegas al final, vuelves al inicio)
	if new_index >= unlocked_forms.size():
		new_index = 0
	elif new_index < 0:
		new_index = unlocked_forms.size() - 1
		
	switch_to_form_index(new_index)

func switch_to_form_index(index: int):
	current_form_index = index
	var form_to_apply = unlocked_forms[current_form_index]
	change_form(form_to_apply)
	
	# la interfaz visual
	match form_to_apply:
		Form.SLIME:
			form_label.text = "Forma: SLIME"
		Form.STONE:
			form_label.text = "Forma: PIEDRA"
		Form.FIRE:
			form_label.text = "Forma: FUEGO"
		Form.SKELETON:
			form_label.text = "Forma: ESQUELETO"
		Form.DEVOURER:
			form_label.text = "Forma: DEVORADOR MASIVO"

func change_form(new_form: Form):
	await get_tree().create_timer(0.1).timeout
	
	# ELIMINAMOS el bloque que reseteaba la base_visual_scale a Vector3.ONE.
	# ¡Ahora el tamaño es completamente persistente!
	
	# 1. EVALUAR EXPULSIÓN DE INVENTARIO
	var form_index = int(new_form)
	if transformation_module and not transformation_module.allows_internal_inventory(form_index):
		magic_inventory._expel_internal_inventory()
	else:
		magic_inventory._enforce_capacity_limit(form_index)
		
	current_form = new_form
	
	# Apagamos todas primero para evitar superposiciones raras
	slime_mesh.visible = false
	stone_mesh.visible = false
	FIRE_mesh.visible = false
	skeleton_mesh.visible = false
	
	# Encender la cáscara actual y hacer que el núcleo copie su geometría
	match current_form:
		Form.SLIME:
			slime_mesh.visible = true
			element_core.mesh = slime_mesh.mesh # El núcleo copia la malla
		Form.STONE:
			stone_mesh.visible = true
			element_core.mesh = stone_mesh.mesh
		Form.FIRE:
			FIRE_mesh.visible = true
			element_core.mesh = FIRE_mesh.mesh
		Form.SKELETON:
			skeleton_mesh.visible = true
			element_core.mesh = skeleton_mesh.mesh
			
	element_core.scale = Vector3(0.95, 0.95, 0.95)
		
	# 3. APAGAR O ENCENDER EL IK
	var ik_node = slime_mesh.get_node_or_null("Armature/Skeleton3D/SkeletonIK3D") 
	if ik_node:
		if current_form == Form.SLIME: ik_node.start()
		else: ik_node.stop() 

	# 4. Aplicamos los stats y configuraciones físicas
	transformation_module.apply_transformation(self, new_form)
	
	# Al cambiar de forma, el TransformationModule recrea la caja de colisión.
	# Aquí le forzamos a que vuelva a tener nuestro tamaño gigante actual.
	collision_shape.scale = base_visual_scale
	visuals.scale = base_visual_scale
	visuals.rotation = Vector3.ZERO
	
	# Nos aseguramos de que la cámara se aleje lo suficiente para que no se quede 
	# atascada dentro de tu modelo si eres muy grande.
	var zoom_minimo_seguro = 5.0 + ((base_visual_scale.x - 1.0) * 6.0)
	target_zoom = max(target_zoom, zoom_minimo_seguro)

func take_damage(amount: float):
	current_health -= amount
	current_health = clamp(current_health, 0.0, max_health)
	
	print("Vida actual: ", current_health)
	
	# Calculamos el desgaste: 0.0 es vida llena, 1.0 es casi muerto
	var wear = 1.0 - (current_health / max_health)
	
	# Aplicamos el desgaste al Shader de la malla exterior actual
	var current_mesh = get_current_active_mesh()
	if current_mesh and current_mesh.material_override is ShaderMaterial:
		current_mesh.material_override.set_shader_parameter("damage_level", wear)

	if current_health <= 0:
		print("¡Has muerto o perdido la forma!")
		# Aquí iría tu lógica de muerte (perder el caparazón, volverte slime base, etc.)

func get_current_active_mesh() -> MeshInstance3D:
	match current_form:
		Form.SLIME: return slime_mesh
		Form.STONE: return stone_mesh
		Form.FIRE: return FIRE_mesh
		Form.SKELETON: return skeleton_mesh
	return slime_mesh

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spring_arm.spring_length = target_zoom
	visual_base_y = visuals.position.y
	
	# PRE-COMPILAMOS EL MATERIAL BASE
	cached_base_core_mat = StandardMaterial3D.new()
	cached_base_core_mat.emission_enabled = true
	cached_base_core_mat.emission_energy_multiplier = 2.0
	cached_base_core_mat.albedo_color = Color(0, 0.5, 1)
	cached_base_core_mat.emission = Color(0, 0.5, 1)
	var proj_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	if proj_gravity != null:
		gravity = float(proj_gravity)
	if collision_shape.shape is CapsuleShape3D:
		default_col_radius = collision_shape.shape.radius
		default_col_height = collision_shape.shape.height
	elif collision_shape.shape is SphereShape3D:
		default_col_radius = collision_shape.shape.radius

func _input(event):
	if event.is_action_pressed("press_tab"):
		if building_sockets_manager:
			is_build_mode = !is_build_mode
			building_sockets_manager.set_build_mode(is_build_mode)
			
			if is_build_mode:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Liberamos el ratón
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # Atrapamos el ratón

	# 1. Rotar la cámara con el ratón
	if event is InputEventMouseMotion and not is_build_mode:
		rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, -PI/4, PI/3)
	
	# 2. Controlar el Zoom objetivo
	if event.is_action_pressed("scroll_up"):
		target_zoom -= zoom_speed
	elif event.is_action_pressed("scroll_down"):
		target_zoom += zoom_speed
		
	# Limitar el zoom para que no se acerque ni se aleje al infinito
	target_zoom = clamp(target_zoom, min_zoom, max_zoom)

	# 3. Cambiar de forma o Cambiar de objeto sostenido
	if event.is_action_pressed("press_r"):
		if consumer.held_item != null:
			consumer.cycle_held_item(1) # Rota el objeto en la cabeza
		else:
			cycle_form(1) # Cambia de forma
			
	elif event.is_action_pressed("press_q"):
		if consumer.held_item != null:
			consumer.cycle_held_item(-1) # Rota el objeto en la cabeza
		else:
			cycle_form(-1) # Cambia de forma
	# 4. Expulsar Materia (Mitosis)
	if event.is_action_pressed("press_c"):
		expel_mass()
	# 5. Tirar la cáscara actual como un objeto
	if event.is_action_pressed("press_g"):
		shed_shell_as_item()

# --- Gestor Modular de Extremidades ---
var active_limbs: Array[ProceduralLimb] = []

func register_limb(limb: ProceduralLimb):
	if not active_limbs.has(limb):
		active_limbs.append(limb)
		print("Sistema conectado: ", limb.name, " tipo: ", limb.limb_type)
		
		# Pasarle el brazo al inventario
		if modular_hands_inventory:
			modular_hands_inventory.register_arm(limb)

func unregister_limb(limb: ProceduralLimb):
	if active_limbs.has(limb):
		active_limbs.erase(limb)
		
		# Quitar el brazo del inventario si se destruye o cambia de forma
		if modular_hands_inventory:
			modular_hands_inventory.unregister_arm(limb)

func shed_shell_as_item():
	if current_form == Form.SLIME:
		print("No tienes ninguna cáscara puesta para tirar.")
		return
		
	var shell_item = ConsumableItem.new()
	shell_item.form_to_grant = Form.keys()[current_form]
	shell_item.set("element_to_grant", current_element)
	shell_item.item_weight = 0.5 
	
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D"
	
	# 1. Copiamos EXACTAMENTE la malla y el material actual
	var source_mesh = get_current_active_mesh()
	mesh_inst.mesh = source_mesh.mesh
	
	if source_mesh.material_override != null:
		mesh_inst.material_override = source_mesh.material_override
	elif current_custom_material != null:
		mesh_inst.material_override = current_custom_material
	elif transformation_module and transformation_module.elemental_materials.has(current_element):
		mesh_inst.material_override = transformation_module.elemental_materials[current_element]
		
	var col = CollisionShape3D.new()
	col.shape = SphereShape3D.new()
	col.shape.radius = 0.5 
	
	shell_item.add_child(mesh_inst)
	shell_item.add_child(col)
	
	# 2. Le damos EXACTAMENTE tu escala global actual (Sin achicarlo)
	shell_item.scale = base_visual_scale
	
	get_tree().current_scene.add_child(shell_item)
	shell_item.add_collision_exception_with(self)
	
	var aim_dir = -camera_pivot.global_transform.basis.z.normalized()
	shell_item.global_position = hold_position.global_position + (aim_dir * 2.0)
	var throw_dir = (aim_dir + Vector3(0, 0.4, 0)).normalized()
	shell_item.apply_central_impulse(throw_dir * 12.0)
	
	lose_elemental_shell()

func shed_shell_and_hold():
	if current_form == Form.SLIME:
		return # No hay cáscara que quitar
		
	var shell_item = ConsumableItem.new()
	shell_item.form_to_grant = Form.keys()[current_form]
	shell_item.set("element_to_grant", current_element)
	shell_item.item_weight = 0.5 
	
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D"
	
	# Copiamos la malla actual
	var source_mesh = get_current_active_mesh()
	mesh_inst.mesh = source_mesh.mesh
	shell_item.set("item_mesh", source_mesh.mesh) 
	
	if source_mesh.material_override != null:
		mesh_inst.material_override = source_mesh.material_override
	elif current_custom_material != null:
		mesh_inst.material_override = current_custom_material
	elif transformation_module and transformation_module.elemental_materials.has(current_element):
		mesh_inst.material_override = transformation_module.elemental_materials[current_element]
		
	var col = CollisionShape3D.new()
	col.shape = SphereShape3D.new()
	col.shape.radius = 0.5 
	
	shell_item.add_child(mesh_inst)
	shell_item.add_child(col)
	
	# La hacemos un poquito más pequeña para que se vea bien como un objeto que sostienes
	shell_item.scale = Vector3(0.8, 0.8, 0.8)
	
	# La metemos al mundo
	get_tree().current_scene.add_child(shell_item)
	
	# ¡Perdemos la cáscara y volvemos a ser Slime!
	lose_elemental_shell()
	
	# 🔥 EL TOQUE MÁGICO: Autoseleccionarla
	if consumer:
		# Si ya tenías algo en la cabeza, intentamos guardarlo en el estómago
		if consumer.held_item != null:
			consumer.put_back_item()
			# Si el estómago estaba lleno y no se pudo guardar, lo tiramos al suelo
			if consumer.held_item != null: 
				consumer.drop_item()
		
		# Ponemos la nueva cáscara en tu cabeza/manos
		consumer.place_on_head(shell_item)
		if aim_ik_coordinator:
			aim_ik_coordinator.set_grab_target(shell_item)

func _physics_process(delta):
	# --- Suavizado de la Cámara ---
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_zoom, zoom_smoothness * delta)

	# --- Gravedad y Salto ---
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("press_space") and is_on_floor():
		velocity.y = jump_velocity

	# --- Entrada de Movimiento (WASD) ---
	var input_dir = Input.get_vector("press_a", "press_d", "press_w", "press_s")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	# 1. Empaquetamos todo lo que las extremidades podrían querer saber
	var aim_point = camera_pivot.global_position + (-camera_pivot.global_transform.basis.z * 50.0)
	
	# Le pedimos la posición de agarre a tu nodo coordinador
	var grab_pos = aim_ik_coordinator.get_grab_position()
	
	var brain_data = {
		"velocity": velocity,
		"is_on_floor": is_on_floor(),
		"aim_target": aim_point,
		"grab_target": grab_pos # Puede ser un Vector3 o null
	}

	for i in range(active_limbs.size() - 1, -1, -1):
		var limb = active_limbs[i]
		if is_instance_valid(limb):
			limb.update_limb(delta, brain_data)
		else:
			active_limbs.remove_at(i)
			
	# 3. Animación y Aplicación Real del Movimiento (¡Crucial!)
	_apply_procedural_animation(delta)
	move_and_slide()

# --- Animación en Tiempo Real (Procedural) ---
func _apply_procedural_animation(delta):
	# 1. Squash y Stretch
	var vertical_speed = 0.0
	if jump_velocity > 0.0:
		vertical_speed = clamp(velocity.y / jump_velocity, -1.0, 1.0)
		
	var anim_scale = Vector3(1.0 - (vertical_speed * 0.2), 1.0 + (abs(vertical_speed) * 0.3), 1.0 - (vertical_speed * 0.2))
	var target_scale = base_visual_scale * anim_scale 
	
	visuals.scale = visuals.scale.lerp(target_scale, delta * 10.0)
	
	# 2. Inclinación al moverse y Bobbing (simular pasos)
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	var move_direction = (transform.basis.inverse() * velocity).normalized() # Dirección relativa local
	
	if horizontal_speed > 0.1 and is_on_floor():
		step_cycle += horizontal_speed * delta * 2.0
		# Pequeño salto en Y (bobbing) al caminar
		visuals.position.y = visual_base_y + sin(step_cycle * PI) * 0.1 
		# Inclinarse hacia la dirección en la que camina
		visuals.rotation.x = lerp(visuals.rotation.x, move_direction.z * 0.15, delta * 8.0)
		visuals.rotation.z = lerp(visuals.rotation.z, -move_direction.x * 0.15, delta * 8.0)
	else:
		# Regresar suavemente al reposo
		step_cycle = 0.0
		visuals.position.y = lerp(visuals.position.y, visual_base_y, delta * 10.0)
		visuals.rotation.x = lerp(visuals.rotation.x, 0.0, delta * 8.0)
		visuals.rotation.z = lerp(visuals.rotation.z, 0.0, delta * 8.0)

@onready var hold_position = $HoldPosition # Asegúrate de que la ruta sea correcta
@onready var default_hold_parent = hold_position.get_parent()
@onready var default_hold_transform = hold_position.transform

# Función para mudar el inventario visual a una extremidad
func move_hold_position_to(new_parent: Node3D):
	if hold_position.get_parent() == new_parent:
		return # Ya estamos ahí
		
	# Lo desvinculamos de su padre actual
	hold_position.get_parent().remove_child(hold_position)
	# Lo añadimos al nuevo padre (ej. El marcador de la mano)
	new_parent.add_child(hold_position)
	
	if new_parent == default_hold_parent:
		# Si vuelve a ser un Slime, lo ponemos en su posición original (arriba de la cabeza)
		hold_position.transform = default_hold_transform
	else:
		# Si está en una mano, se centra exactamente en la palma
		hold_position.position = Vector3.ZERO
		hold_position.rotation = Vector3.ZERO

func update_physics_size():
	var current_radius = default_col_radius
	var current_height = default_col_height
	
	# Ajustamos las dimensiones reales de la forma del cuerpo
	if collision_shape.shape is CapsuleShape3D:
		current_radius = default_col_radius * base_visual_scale.x
		current_height = default_col_height * base_visual_scale.y
		collision_shape.shape.radius = current_radius
		collision_shape.shape.height = current_height
	elif collision_shape.shape is SphereShape3D:
		current_radius = default_col_radius * base_visual_scale.x
		current_height = current_radius * 2.0 # Aproximación para la altura
		collision_shape.shape.radius = current_radius

	# Le pasamos las nuevas medidas al ConsumerComponent para que mantenga el margen
	if consumer and consumer.has_method("update_area_size"):
		consumer.update_area_size(current_radius, current_height)

func grow_slime(weight: float):
	var growth_factor = weight * 0.05 
	base_visual_scale += Vector3(growth_factor, growth_factor, growth_factor)
	
	var tween = get_tree().create_tween()
	tween.tween_property(visuals, "scale", Vector3(base_visual_scale.x * 1.2, base_visual_scale.y * 0.8, base_visual_scale.z * 1.2), 0.1)
	tween.tween_property(visuals, "scale", base_visual_scale, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Llamamos a la función segura
	update_physics_size()
	
	spring_arm.spring_length += (growth_factor * 2.0) 
	target_zoom = spring_arm.spring_length

# --- SISTEMA DE MITOSIS Y MASA ---

func expel_mass():
	if base_visual_scale.x > 1.01: 
		var mass_to_lose = 0.2 
		
		# 🔥 NUEVO: Detectar si este es el último disparo que agota la masa
		if base_visual_scale.x - mass_to_lose <= 1.01:
			print("¡Última masa! La cáscara se auto-equipa.")
			mass_to_lose = base_visual_scale.x - 1.0 # Vaciamos lo que quede
			base_visual_scale = Vector3.ONE # Regresamos a escala 1.0 exacta
			
			update_physics_size()
			
			# En lugar de disparar, convertimos la cáscara en un objeto en nuestras manos
			shed_shell_and_hold()
			
		else:
			# Disparo normal (aún tenemos masa de sobra)
			base_visual_scale -= Vector3(mass_to_lose, mass_to_lose, mass_to_lose)
			update_physics_size()
			spawn_matter_projectile()
			
		# Efecto visual de contracción para ambos casos
		var tween = get_tree().create_tween()
		tween.tween_property(visuals, "scale", base_visual_scale * 0.8, 0.05)
		tween.tween_property(visuals, "scale", base_visual_scale, 0.2).set_trans(Tween.TRANS_BOUNCE)
		
		collision_shape.scale = base_visual_scale
		target_zoom = max(min_zoom, target_zoom - (mass_to_lose * 5.0))
		
	else:
		print("¡No tienes suficiente masa para expulsar!")

func lose_elemental_shell():
	print("¡Masa extra agotada! Perdiendo cáscara elemental...")
	current_element = "BASE"
	current_custom_material = null
	
	# Usamos el material precargado, ¡Cero Lag!
	element_core.material_override = cached_base_core_mat
	
	switch_to_form_index(0)

func spawn_matter_projectile():
	var blob = ConsumableItem.new()
	blob.add_to_group("expelled_mass")
	
	blob.set_meta("mass_value", 0.2) 
	blob.item_weight = 0.2 
	blob.form_to_grant = "SLIME"
	blob.set("element_to_grant", current_element)
	
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D" 
	
	var sphere = SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	mesh_inst.mesh = sphere
	
	# 🔥 FIX VISUAL: Aseguramos que el proyectil SIEMPRE tenga un material
	if current_custom_material != null:
		mesh_inst.material_override = current_custom_material
	elif transformation_module and transformation_module.elemental_materials.has(current_element):
		mesh_inst.material_override = transformation_module.elemental_materials[current_element]
	else:
		mesh_inst.material_override = cached_base_core_mat # Respaldo: Azul brillante
		
	var col = CollisionShape3D.new()
	col.shape = SphereShape3D.new()
	col.shape.radius = 0.3
	
	blob.add_child(mesh_inst)
	blob.add_child(col)
	
	# Forzamos que la variable del ConsumableItem reconozca la malla por si acaso
	blob.set("item_mesh", sphere) 
	
	get_tree().current_scene.add_child(blob)
	
	var aim_dir = -camera_pivot.global_transform.basis.z.normalized()
	blob.global_position = hold_position.global_position + (aim_dir * 1.5)
	var throw_dir = (aim_dir + Vector3(0, 0.2, 0)).normalized()
	blob.apply_central_impulse(throw_dir * 15.0)
