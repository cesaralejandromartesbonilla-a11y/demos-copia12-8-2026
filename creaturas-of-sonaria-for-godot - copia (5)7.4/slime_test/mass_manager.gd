extends Node3D
class_name MassManager

signal mass_scale_changed(new_scale: float)
signal liquid_mass_depleted

@export var target_collision_shape: CollisionShape3D

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
	
	# Activamos el guardián por primera vez (esto le pone el material a la malla)
	_apply_shader_protection()
	
	# 3. SETUP DE ÁREAS Y FÍSICAS
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
	# Obtenemos el tamaño real al que está escalado el Slime visualmente
	var visual_scale = current_mass_level
	if slime.get("visuals"):
		visual_scale = slime.visuals.scale.y
		
	# 2. 🔥 EL GUARDIÁN: Revisa en cada frame que nadie haya quitado el shader
	_apply_shader_protection()
	
	# 3. Lógica de deformación y envío de datos al Shader
	if liquid_mass_mesh.material_override == _cached_material:
		var safe_velocity = slime.velocity.limit_length(8.0)
		_cached_material.set_shader_parameter("velocity_wobble", safe_velocity)
		
		var hits = []
		# Variables objetivo para el suelo y techo (0.55 significa que están lejos y el slime es redondo)
		var target_floor_y = -0.55 
		var target_ceil_y = 0.55 
		
		if environment_cast.is_colliding():
			for i in range(environment_cast.get_collision_count()):
				var normal = environment_cast.get_collision_normal(i)
				var local_pt = liquid_mass_mesh.to_local(environment_cast.get_collision_point(i))
				
				# Separamos el tipo de colisión según hacia dónde apunta la normal
				if normal.y > 0.7: 
					# Es el SUELO
					target_floor_y = local_pt.y
				elif normal.y < -0.7: 
					# Es el TECHO
					target_ceil_y = local_pt.y
				else: 
					# Son PAREDES / OBJETOS LATERALES
					hits.append(local_pt)
					if hits.size() >= 2: break
		
		# 1. Procesamos Paredes (como ya lo teníamos)
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

		# 2. Procesamos Piso y Techo suavemente
		current_floor_y = lerp(current_floor_y, target_floor_y, delta * 15.0)
		current_ceil_y = lerp(current_ceil_y, target_ceil_y, delta * 15.0)
		
		_cached_material.set_shader_parameter("dynamic_floor_y", current_floor_y)
		_cached_material.set_shader_parameter("dynamic_ceil_y", current_ceil_y)
		
	var center_y = 0.0
	
	# Mantenemos las áreas internas sincronizadas con el centro
	liquid_mass_mesh.position.y = center_y
	absorption_area.position.y = center_y
	if shell_mesh.mesh != null:
		shell_mesh.position.y = center_y
		
	# ⚡ EFECTO HÁMSTER (Inercia del núcleo)
	var flat_velocity = Vector3(slime.velocity.x, 0, slime.velocity.z)
	var target_offset = flat_velocity * 0.08 
	
	var max_displacement = (0.5 * visual_scale) * 0.60
	if target_offset.length() > max_displacement:
		target_offset = target_offset.normalized() * max_displacement
	
	# El núcleo se mantiene en el centro absoluto + la inercia del movimiento
	var base_core_pos = Vector3(0, center_y, 0)
	core_mesh.position = core_mesh.position.lerp(base_core_pos + target_offset, delta * 12.0)

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

func _update_visuals():
	var new_scale = Vector3.ONE * current_mass_level
	
	if environment_cast:
		environment_cast.scale = new_scale
	
	# 1. Animación de rebote (Estirarse y encogerse) APLICADA SOLO AL LÍQUIDO
	var tween = get_tree().create_tween()
	tween.tween_property(liquid_mass_mesh, "scale", Vector3(current_mass_level * 1.2, current_mass_level * 0.8, current_mass_level * 1.2), 0.1)
	tween.tween_property(liquid_mass_mesh, "scale", new_scale, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# 2. Las colisiones y cáscaras no rebotan, solo crecen fluidamente
	var parallel_tween = get_tree().create_tween().set_parallel(true)
	parallel_tween.tween_property(absorption_col, "scale", new_scale, 0.3)
	
	if shell_mesh.mesh != null:
		parallel_tween.tween_property(shell_mesh, "scale", new_scale * 1.15, 0.3)
		
	mass_scale_changed.emit(current_mass_level)

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

func _on_absorption_area_entered(area: Area3D):
	if area.is_in_group("elemental_hazard"):
		var damage = area.get_meta("damage_amount", 0.5)
		take_elemental_damage(damage)
