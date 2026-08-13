extends Node
class_name MatterController

@onready var slime: CharacterBody3D = get_parent()

@export var current_element: String = "BASE":
	set(value):
		current_element = value
		if is_node_ready() and slime and slime.has_node("VisualElementModule"):
			slime.get_node("VisualElementModule").transition_to_element(current_element, current_custom_material)
var unlocked_elements: Array[String] = ["BASE"]
var current_custom_material: Material = null
var cached_base_liquid_mat: StandardMaterial3D

func _ready():
	cached_base_liquid_mat = StandardMaterial3D.new()
	cached_base_liquid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cached_base_liquid_mat.albedo_color = Color(0, 0.5, 1, 0.8)
	cached_base_liquid_mat.emission_enabled = true
	cached_base_liquid_mat.emission = Color(0, 0.2, 0.8)
	cached_base_liquid_mat.emission_energy_multiplier = 1.0

# ==========================================
# 🧪 SISTEMA ELEMENTAL 
# ==========================================
func process_consumed_item(item_data: ItemData):
	# 1. Absorber Masa (Usando nutrición y peso)
	var mass_value = (item_data.nutrition_value * 0.05) + (item_data.weight_kg * 0.02)
	
	if slime.mass_manager:
		slime.mass_manager.add_mass(mass_value)
		
	# 2. Reacción Elemental
	# Aquí es donde el Núcleo (Vacuola) guarda el elemento.
	var element = "BASE"
	if item_data.item_groups.has("fire"): element = "FIRE"
	elif item_data.item_groups.has("stone"): element = "STONE"
	
	if element != "BASE":
		consume_element(element, null)
		
	# Efecto visual de comer
	var tween = get_tree().create_tween()
	tween.tween_property(slime.visuals, "scale", slime.visuals.scale * 1.1, 0.1)
	tween.tween_property(slime.visuals, "scale", Vector3.ONE * slime.current_liquid_scale, 0.3).set_trans(Tween.TRANS_ELASTIC)

# ==========================================
# 📚 CONSUMO DE OBJETOS (ConsumableItem) — ASIMILACIÓN
# ==========================================
func process_consumed_object(item: ConsumableItem):
	var mass_value = item.item_weight * 0.02
	
	# 1. Elemento primero
	if item.element_to_grant != "BASE":
		consume_element(item.element_to_grant, null)
		
	# 2. Asimilación de forma
	if slime.form_library:
		var data = item.build_form_data()
		if data != null:
			slime.form_library.assimilate(data)

	# 3. Forzar actualización visual completa y refresco del shader
	if slime.mass_manager:
		slime.mass_manager.add_mass(mass_value) # add_mass ya llama internamente a _update_visuals()
		
	# Efecto visual de comer (idéntico al de process_consumed_item)
	var tween = get_tree().create_tween()
	tween.tween_property(slime.visuals, "scale", slime.visuals.scale * 1.1, 0.1)
	tween.tween_property(slime.visuals, "scale", Vector3.ONE * slime.current_liquid_scale, 0.3).set_trans(Tween.TRANS_ELASTIC)

func consume_element(new_element: String, custom_mat: Material = null):
	if new_element == "" or new_element == "NONE": return
		
	if not unlocked_elements.has(new_element): 
		unlocked_elements.append(new_element)
		
	if current_element != new_element or custom_mat != null:
		current_element = new_element
		current_custom_material = null if new_element == "BASE" else custom_mat
		
		# ❌ ELIMINAMOS la creación de StandardMaterial3D y el llamado a update_liquid_mass_material.
		# ✅ Solo notificamos a los módulos de transformación lógica:
		if slime.transformation_module: 
			slime.transformation_module.apply_element_only(slime, current_element)
			
	# Disparamos la transición visual pasándole los datos puros
	if slime.has_node("VisualElementModule"):
		slime.get_node("VisualElementModule").transition_to_element(current_element, current_custom_material)

func lose_elemental_shell():
	current_element = "BASE"
	current_custom_material = null
	
	if "element_core" in slime and slime.element_core:
		slime.element_core.material_override = cached_base_liquid_mat
		
	if slime.transformation_module:
		slime.transformation_module.apply_element_only(slime, "BASE")
		
	if slime.form_controller:
		slime.form_controller.set_current_form("slime")
		var new_form = slime.form_controller.get_current_form()
		slime._on_form_changed(new_form)
		
		if slime.form_label and new_form:
			slime.form_label.text = "Forma: " + new_form.display_name + " de BASE"

# ==========================================
# 🦠 MITOSIS Y MASA
# ==========================================
func grow_slime(weight: float):
	var growth_factor = weight * 0.05
	
	if slime.mass_manager: 
		slime.mass_manager.add_mass(growth_factor)
		slime.current_liquid_scale = slime.mass_manager.current_mass_level
		slime.base_visual_scale = Vector3.ONE * slime.current_liquid_scale
		
	if slime.consumer: 
		slime.consumer.update_area_size(slime.default_col_radius * slime.current_liquid_scale, slime.default_col_height * slime.current_liquid_scale)

# ==========================================
# 🐚 EXPULSIÓN DE CÁSCARA
# ==========================================
func shed_shell_as_item():
	if slime.mass_manager and slime.mass_manager.has_method("has_shell") and not slime.mass_manager.has_shell():
		print("No hay cáscara/armadura para expulsar!")
		return
		
	var has_form = slime.form_controller and slime.form_controller.get_current_form_id() != "slime"
	var has_element = current_element != "BASE"
	
	if not has_form and not has_element: return
		
	var shell_item = _create_base_shell_item()
	
	# Usamos current_liquid_scale en lugar de base_visual_scale
	shell_item.scale = Vector3.ONE * slime.current_liquid_scale
	
	get_tree().current_scene.add_child(shell_item)
	shell_item.add_collision_exception_with(slime)
	
	if slime.camera_controller:
		var aim_dir = slime.camera_controller.get_aim_direction()
		shell_item.global_position = slime.hold_position.global_position + (aim_dir * 2.0)
		shell_item.apply_central_impulse((aim_dir + Vector3(0, 0.4, 0)).normalized() * 12.0)
	
	lose_elemental_shell()

func shed_shell_and_hold():
	if slime.mass_manager and not slime.mass_manager.has_shell():
		print("No hay cáscara/armadura para expulsar!")
		return
	var has_form = slime.form_controller and slime.form_controller.get_current_form_id() != "slime"
	var has_element = current_element != "BASE"
	
	if not has_form and not has_element: return
		
	var shell_item = _create_base_shell_item()
	shell_item.scale = Vector3(0.8, 0.8, 0.8)
	
	get_tree().current_scene.add_child(shell_item)
	lose_elemental_shell()
	
	if slime.consumer:
		if slime.consumer.held_item != null:
			slime.consumer.put_back_item()
			if slime.consumer.held_item != null: slime.consumer.drop_item()
		slime.consumer.place_on_head(shell_item)
		if slime.aim_ik_coordinator: slime.aim_ik_coordinator.set_grab_target(shell_item)

# ==========================================
# 🛠️ FUNCIONES AUXILIARES INTERNAS
# ==========================================
func _create_base_shell_item() -> ConsumableItem:
	var shell_item = ConsumableItem.new()
	
	if slime.form_controller:
		shell_item.form_override = slime.form_controller.get_current_form()
		
	shell_item.set("element_to_grant", current_element)
	shell_item.item_weight = 0.5
	
	var source_mesh = slime.get_current_active_mesh()
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.mesh = source_mesh.mesh
	
	if source_mesh.material_override != null: mesh_inst.material_override = source_mesh.material_override
	elif current_custom_material != null: mesh_inst.material_override = current_custom_material
	elif slime.transformation_module and slime.transformation_module.elemental_materials.has(current_element): 
		mesh_inst.material_override = slime.transformation_module.elemental_materials[current_element]
		
	shell_item.set("item_mesh", source_mesh.mesh)
	
	var col = CollisionShape3D.new()
	col.shape = SphereShape3D.new()
	col.shape.radius = 0.5
	
	shell_item.add_child(mesh_inst)
	shell_item.add_child(col)
	return shell_item
