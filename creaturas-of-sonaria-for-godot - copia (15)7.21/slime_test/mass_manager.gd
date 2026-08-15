extends Node3D
class_name MassManager

signal mass_scale_changed(new_scale: float)
signal liquid_mass_depleted

@export var target_collision_shape: CollisionShape3D

@onready var slime: CharacterBody3D = get_parent()
@onready var core_mesh: MeshInstance3D = $CoreMesh
@onready var liquid_mass_mesh: MeshInstance3D = $LiquidMassMesh
@onready var shell_mesh: MeshInstance3D = $ShellMesh

var absorption_area: Area3D
var absorption_col: CollisionShape3D

var current_mass_level: float = 1.0
const MAX_MASS_LEVEL: float = 5.0 
const MIN_MASS_LEVEL: float = 1.0
@export var liquid_material: ShaderMaterial
var default_core_mat: StandardMaterial3D 
var environment_cast: ShapeCast3D
var _cached_material: ShaderMaterial
var squish_weight_1: float = 0.0
var squish_weight_2: float = 0.0
var contact_pos_1: Vector3 = Vector3.ZERO
var contact_pos_2: Vector3 = Vector3.ZERO
var current_floor_y: float = -0.55
var current_ceil_y: float = 0.55

# Variable para aislar la animación de comer del estiramiento continuo
var bounce_scale_multiplier: Vector3 = Vector3.ONE

func _ready():
	# 1. CREAR EL MATERIAL DEL NÚCLEO
	default_core_mat = StandardMaterial3D.new()
	default_core_mat.emission_enabled = true
	default_core_mat.albedo_color = Color(1, 1, 1)
	default_core_mat.emission = Color(1, 1, 1)
	default_core_mat.emission_energy_multiplier = 4.0
	
	change_core_shape("SPHERE")
	
	# 2. LÍQUIDO BASE
	var mass_sphere = SphereMesh.new()
	mass_sphere.radius = 0.5 
	mass_sphere.height = 1.0
	liquid_mass_mesh.mesh = mass_sphere
	liquid_mass_mesh.scale = Vector3.ONE
	_cached_material = load("res://slime_test/slime_jelly.tres") as ShaderMaterial
	
	if _cached_material == null:
		push_error("¡ERROR CRÍTICO! No se encontró el Shader. Verifica que la ruta 'res://slime_test/slime_jelly.tres' sea correcta.")
	
	_apply_shader_protection()
	_setup_absorption_area()
	_setup_environment_cast()

func _apply_shader_protection():
	if not liquid_mass_mesh: return
	if liquid_mass_mesh.material_override != _cached_material:
		liquid_mass_mesh.material_override = _cached_material

func _setup_environment_cast():
	environment_cast = ShapeCast3D.new()
	environment_cast.name = "EnvironmentCast"
	var sensor_shape = SphereShape3D.new()
	sensor_shape.radius = 0.52 
	environment_cast.shape = sensor_shape
	environment_cast.target_position = Vector3.ZERO 
	environment_cast.collision_mask = 0xFFFFFFFF 
	environment_cast.add_exception(get_parent()) 
	add_child(environment_cast)

func _setup_absorption_area():
	absorption_area = Area3D.new()
	absorption_area.name = "AbsorptionArea"
	absorption_area.collision_layer = 0 
	absorption_area.collision_mask = 2 | 4 | 8 
	
	absorption_col = CollisionShape3D.new()
	absorption_col.shape = SphereShape3D.new()
	absorption_col.shape.radius = 0.5 
	
	absorption_area.add_child(absorption_col)
	add_child(absorption_area)
	
	absorption_area.body_entered.connect(_on_absorption_body_entered)
	absorption_area.area_entered.connect(_on_absorption_area_entered)

# ==========================================
# 🔮 MAGIA VISUAL: LEVITACIÓN E INERCIA
# ==========================================
func _process(delta):
	var slime = get_parent()
	if not slime: return
	if slime and slime.has_node("InternalInventory"): 
		slime.get_node("InternalInventory").recalculate_internal_bounds(current_mass_level)
		
	var visual_scale = current_mass_level
	if slime.get("visuals"):
		visual_scale = slime.visuals.scale.y
		
	_apply_shader_protection()
	
	# --- 🧅 FASE 2: CONSERVACIÓN DE VOLUMEN (Andamio) ---
	var target_scale = Vector3.ONE * current_mass_level
	var current_stretch = 0.0
	var scaffold_tilt = Vector2.ZERO
	var s_ratio = 0.0
	
	if slime.get("stretch_ratio") != null:
		s_ratio = slime.stretch_ratio
		current_stretch = slime.current_stretch_height
		scaffold_tilt = slime.scaffold_tilt
	
	var final_scale = target_scale * bounce_scale_multiplier
	liquid_mass_mesh.scale = final_scale
	absorption_col.scale = Vector3.ONE * current_mass_level 
	if shell_mesh.mesh != null:
		shell_mesh.scale = target_scale * 1.15
	
	# --- SHADER Y COLISIONES ---
	if liquid_mass_mesh.material_override == _cached_material:
		var safe_velocity = slime.velocity.limit_length(8.0)
		_cached_material.set_shader_parameter("velocity_wobble", safe_velocity)
		
		# ¡Enviamos los datos del andamio al shader!
		_cached_material.set_shader_parameter("scaffold_tilt", scaffold_tilt)
		_cached_material.set_shader_parameter("stretch_ratio", s_ratio)
		
		var hits = []
		var target_floor_y = -0.55 
		var target_ceil_y = 0.55 
		
		if environment_cast.is_colliding():
			for i in range(environment_cast.get_collision_count()):
				var normal = environment_cast.get_collision_normal(i)
				var local_pt = liquid_mass_mesh.to_local(environment_cast.get_collision_point(i))
				
				if normal.y > 0.7: 
					target_floor_y = local_pt.y
				elif normal.y < -0.7: 
					target_ceil_y = local_pt.y
				else: 
					hits.append(local_pt)
					if hits.size() >= 2: break
		
		var target_w1 = 1.0 if hits.size() > 0 else 0.0
		var target_w2 = 1.0 if hits.size() > 1 else 0.0
		
		if target_w1 > 0.0:
			contact_pos_1 = contact_pos_1.lerp(hits[0], delta * 15.0) if squish_weight_1 > 0.1 else hits[0]
		if target_w2 > 0.0:
			contact_pos_2 = contact_pos_2.lerp(hits[1], delta * 15.0) if squish_weight_2 > 0.1 else hits[1]
			
		squish_weight_1 = lerp(squish_weight_1, target_w1, delta * 10.0)
		squish_weight_2 = lerp(squish_weight_2, target_w2, delta * 10.0)
		
		_cached_material.set_shader_parameter("contact_1", contact_pos_1)
		_cached_material.set_shader_parameter("weight_1", squish_weight_1)
		_cached_material.set_shader_parameter("contact_2", contact_pos_2)
		_cached_material.set_shader_parameter("weight_2", squish_weight_2)

		current_floor_y = lerp(current_floor_y, target_floor_y, delta * 15.0)
		current_ceil_y = lerp(current_ceil_y, target_ceil_y, delta * 15.0)
		
		_cached_material.set_shader_parameter("dynamic_floor_y", current_floor_y)
		_cached_material.set_shader_parameter("dynamic_ceil_y", current_ceil_y)
		
	var center_y = 0.0
	liquid_mass_mesh.position.y = center_y
	absorption_area.position.y = center_y
	if shell_mesh.mesh != null:
		shell_mesh.position.y = center_y
		
	# ⚡ EFECTO HÁMSTER Y MIGRACIÓN DE NÚCLEO
	var flat_velocity = Vector3(slime.velocity.x, 0, slime.velocity.z)
	var target_offset = flat_velocity * 0.08
	var core_target_y = center_y
	
	if slime.get("scaffold_module") and slime.scaffold_module.get("is_active"):
		var s_mod = slime.scaffold_module
		if s_mod.scaffold_segments.size() > 0:
			var core_idx = s_mod.core_target_index
			var core_seg = s_mod.scaffold_segments[core_idx]
			
			if is_instance_valid(core_seg):
				# Sacamos la altura local exacta del eslabón elegido
				var local_pos = to_local(core_seg.global_position)
				core_target_y = local_pos.y
	var base_core_pos = Vector3(0, core_target_y, 0)
	core_mesh.position = core_mesh.position.lerp(base_core_pos + target_offset, delta * 12.0)
	var max_displacement = (0.5 * visual_scale) * 0.60
	if target_offset.length() > max_displacement:
		target_offset = target_offset.normalized() * max_displacement
	
	var top_pos = Vector3(0, center_y, 0) # Posición por defecto en la base
	
	var scaffold = slime.get_node_or_null("scaffoldmodule") 
	if scaffold and scaffold.is_active and scaffold.scaffold_segments.size() > 0:
		var target_idx = clamp(scaffold.core_target_index, 0, scaffold.scaffold_segments.size() - 1)
		var target_segment = scaffold.scaffold_segments[target_idx]
		
		if is_instance_valid(target_segment):
			top_pos = to_local(target_segment.global_position)
			
	# Movemos el núcleo suavemente
	core_mesh.position = core_mesh.position.lerp(top_pos + target_offset, delta * 12.0)

# ==========================================
# 💧 ECONOMÍA DE LA MASA LÍQUIDA
# ==========================================
func add_mass(amount: float):
	current_mass_level = clamp(current_mass_level + amount, MIN_MASS_LEVEL, MAX_MASS_LEVEL)
	_update_visuals()

func take_elemental_damage(amount: float):
	current_mass_level -= amount
	if current_mass_level <= MIN_MASS_LEVEL:
		current_mass_level = MIN_MASS_LEVEL
		liquid_mass_depleted.emit()
	_update_visuals()

# Cuánta masa se puede gastar ahora mismo sin cruzar el piso de seguridad.
# margin > 0 deja un colchón extra por encima de MIN_MASS_LEVEL (útil para
# sistemas que quieren cortar antes del límite duro, como la carga de disparo).
func max_spendable(margin: float = 0.0) -> float:
	return max(0.0, current_mass_level - MIN_MASS_LEVEL - margin)

# ==========================================
# 🔄 ACTUALIZACIÓN Y SINCRONIZACIÓN VISUAL
# ==========================================
func _update_visuals():
	if environment_cast:
		environment_cast.scale = Vector3.ONE * current_mass_level
	
	# Rebote de masa
	var tween = get_tree().create_tween()
	tween.tween_property(self, "bounce_scale_multiplier", Vector3(1.2, 0.8, 1.2), 0.1)
	tween.tween_property(self, "bounce_scale_multiplier", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# 🌟 NUEVO: Refrescar y forzar relectura del shader maestro
	refresh_active_material()
		
	mass_scale_changed.emit(current_mass_level)
	
	# Avisamos a la cámara que nos hemos hecho más grandes (o más pequeños)
	if slime.has_node("CameraController"):
		var cam_controller = slime.get_node("CameraController")
		if cam_controller.has_method("update_max_zoom_for_scale"):
			cam_controller.update_max_zoom_for_scale(current_mass_level)

func refresh_active_material() -> void:
	var slime = get_parent()
	if not slime: return
	
	# Obtenemos el elemento y material actual desde MatterController
	var matter_ctrl = slime.get("matter_controller")
	if matter_ctrl == null: return
	
	var current_elem = matter_ctrl.current_element
	var custom_mat = matter_ctrl.current_custom_material
	
	# 1. Nos aseguramos de que el shader maestro de MassManager esté actualizado
	_apply_shader_protection()
	
	# 2. Notificamos al modulo visual para actualizar los parametros del shader
	if slime.has_node("VisualElementModule"):
		slime.get_node("VisualElementModule").transition_to_element(current_elem, custom_mat)
		
	# 3. Si FormController tiene una forma asimilada activa, aplicarle también la fusión
	var form_ctrl = slime.get("form_controller")
	if form_ctrl and form_ctrl.is_assimilated_form:
		_apply_element_to_assimilated_mesh(form_ctrl, custom_mat)

func _apply_element_to_assimilated_mesh(form_ctrl: FormController, custom_mat: Material) -> void:
	# Si la forma asimilada debe teñirse/fusionarse con el elemento activo:
	var mesh_inst = form_ctrl.get("_form_mesh_instance")
	if is_instance_valid(mesh_inst) and custom_mat != null:
		mesh_inst.material_override = custom_mat

# ==========================================
# 🔶 SISTEMA DE FORMAS DEL NÚCLEO
# ==========================================
func change_core_shape(shape_type: String):
	var new_mesh: PrimitiveMesh
	match shape_type.to_upper():
		"CUBE", "BOX":
			new_mesh = BoxMesh.new()
			new_mesh.size = Vector3(0.4, 0.4, 0.4)
		"CYLINDER":
			new_mesh = CylinderMesh.new()
			new_mesh.height = 0.5
			new_mesh.radius = 0.2
		"SPHERE", _:
			new_mesh = SphereMesh.new()
			new_mesh.height = 0.5
			new_mesh.radius = 0.25 
			
	core_mesh.mesh = new_mesh
	core_mesh.material_override = default_core_mat
	core_mesh.scale = Vector3.ONE

func set_element_color(new_color: Color, blend_amount: float = 1.0):
	if liquid_material:
		liquid_material.set_shader_parameter("element_color", new_color)
		var tween = get_tree().create_tween()
		tween.tween_method(
			func(val): liquid_material.set_shader_parameter("element_blend", val), 
			0.0, blend_amount, 0.5
		)

func update_liquid_mass_material(mass_material: Material):
	liquid_mass_mesh.material_override = mass_material
	core_mesh.material_override = default_core_mat

func remove_shell():
	shell_mesh.mesh = null
	shell_mesh.material_override = null

func has_shell() -> bool:
	return shell_mesh.mesh != null

# ==========================================
# ⚠️ DETECCIÓN DEL ÁREA (ABSORCIÓN / DAÑO)
# ==========================================
func _on_absorption_body_entered(body: Node3D):
	if body is PickableItem and not body.is_queued_for_deletion():
		if body.has_method("get_item_data"):
			var data: ItemData = body.get_item_data()
			if data:
				get_parent().matter_controller.process_consumed_item(data)
				body.queue_free()
				
	elif body is ConsumableItem and not body.is_queued_for_deletion():
		get_parent().matter_controller.process_consumed_object(body)
		body.queue_free()
				
	elif body.is_in_group("slime_projectiles") and not body.is_queued_for_deletion():
		if "stored_mass" in body:
			if "is_anchored" in body and not body.is_anchored: return
			add_mass(body.stored_mass)
			
			if "stored_element" in body:
				if body.stored_element != "BASE" and get_parent().matter_controller.current_element == "BASE":
					get_parent().matter_controller.consume_element(body.stored_element, null)
			
			print("¡Materia recuperada: ", body.stored_mass, "!")
			if body.has_method("on_absorbed"):
				body.on_absorbed()
			else:
				body.queue_free()

func _on_absorption_area_entered(area: Area3D):
	if area.is_in_group("elemental_hazard"):
		var damage = area.get_meta("damage_amount", 0.5)
		take_elemental_damage(damage)

func get_master_shader() -> ShaderMaterial:
	return _cached_material
