extends Node
class_name MatterController

@onready var slime: CharacterBody3D = get_parent()

# 📊 ESTADO ELEMENTAL
var current_element: String = "BASE"
var unlocked_elements: Array[String] = ["BASE"]
var current_custom_material: Material = null
var cached_base_liquid_mat: StandardMaterial3D

func _ready():
	# Pre-compilar material base PARA EL LÍQUIDO (Azul semitransparente)
	cached_base_liquid_mat = StandardMaterial3D.new()
	cached_base_liquid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cached_base_liquid_mat.albedo_color = Color(0, 0.5, 1, 0.8)
	cached_base_liquid_mat.emission_enabled = true
	cached_base_liquid_mat.emission = Color(0, 0.2, 0.8)
	cached_base_liquid_mat.emission_energy_multiplier = 1.0

# ==========================================
# 🧪 SISTEMA ELEMENTAL 
# ==========================================
func consume_element(new_element: String, custom_mat: Material = null):
	if new_element == "" or new_element == "NONE": return
		
	if not unlocked_elements.has(new_element): 
		unlocked_elements.append(new_element)
		
	if current_element != new_element or custom_mat != null:
		current_element = new_element
		current_custom_material = null if new_element == "BASE" else custom_mat
		
		# Generamos el material para la Masa Líquida, no para el núcleo
		var liquid_mat = current_custom_material
		if liquid_mat == null:
			liquid_mat = StandardMaterial3D.new()
			liquid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			liquid_mat.emission_enabled = true
			liquid_mat.emission_energy_multiplier = 1.5
			match current_element:
				"FIRE": 
					liquid_mat.albedo_color = Color(1, 0.3, 0, 0.8)
					liquid_mat.emission = Color(1, 0.3, 0)
				"STONE": 
					liquid_mat.albedo_color = Color(0.3, 0.3, 0.3, 0.9)
					liquid_mat.emission = Color(0.1, 0.1, 0.1)
				_: 
					liquid_mat = cached_base_liquid_mat
					
		# 🔥 FIX: Aplicamos el nuevo material SOLO al líquido. El Core ya no se toca.
		if slime.mass_manager: 
			slime.mass_manager.update_liquid_mass(slime.base_visual_scale.x, liquid_mat)
			
		if slime.transformation_module: 
			slime.transformation_module.apply_element_only(slime, current_element)
			
		if slime.form_label and slime.form_controller:
			slime.form_label.text = "Forma: " + slime.form_controller.get_form_name(slime.form_controller.get_current_form()) + " de " + current_element

func lose_elemental_shell():
	current_element = "BASE"
	current_custom_material = null
	
	if slime.mass_manager:
		# 🔥 FIX: Devolvemos el líquido al material azul base y eliminamos la cáscara.
		slime.mass_manager.update_liquid_mass(slime.base_visual_scale.x, cached_base_liquid_mat)
		slime.mass_manager.remove_shell()
	
	if "element_core" in slime and slime.element_core:
		slime.element_core.material_override = cached_base_liquid_mat
		
	if slime.transformation_module:
		slime.transformation_module.apply_element_only(slime, "BASE")
		
	if slime.form_controller:
		slime.form_controller.current_form_index = 0
		slime._on_form_changed(0) 
		
		if slime.form_label:
			slime.form_label.text = "Forma: " + slime.form_controller.get_form_name(0) + " de BASE"

# ==========================================
# 🦠 MITOSIS Y MASA
# ==========================================
func grow_slime(weight: float):
	var growth_factor = weight * 0.05
	slime.base_visual_scale += Vector3(growth_factor, growth_factor, growth_factor)
	
	if slime.mass_manager: slime.mass_manager.update_liquid_mass(slime.base_visual_scale.x, current_custom_material)
	if slime.consumer: slime.consumer.update_area_size(slime.default_col_radius * slime.base_visual_scale.x, slime.default_col_height * slime.base_visual_scale.x)
	
	var tween = get_tree().create_tween()
	tween.tween_property(slime.visuals, "scale", Vector3(slime.base_visual_scale.x * 1.2, slime.base_visual_scale.y * 0.8, slime.base_visual_scale.z * 1.2), 0.1)
	tween.tween_property(slime.visuals, "scale", slime.base_visual_scale, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	if slime.camera_controller: slime.camera_controller.adjust_zoom_for_size(growth_factor * 2.0)

func expel_mass():
	if slime.base_visual_scale.x <= 1.01: return
	
	var mass_to_lose = 0.2
	if slime.base_visual_scale.x - mass_to_lose <= 1.01:
		mass_to_lose = slime.base_visual_scale.x - 1.0
		slime.base_visual_scale = Vector3.ONE
		shed_shell_and_hold()
	else:
		slime.base_visual_scale -= Vector3(mass_to_lose, mass_to_lose, mass_to_lose)
		spawn_matter_projectile()
		
	var tween = get_tree().create_tween()
	tween.tween_property(slime.visuals, "scale", slime.base_visual_scale * 0.8, 0.05)
	tween.tween_property(slime.visuals, "scale", slime.base_visual_scale, 0.2).set_trans(Tween.TRANS_BOUNCE)
	slime.collision_shape.scale = slime.base_visual_scale
	
	if slime.camera_controller: slime.camera_controller.adjust_zoom_for_size(-(mass_to_lose * 5.0))

# ==========================================
# 🐚 EXPULSIÓN DE CÁSCARA Y PROYECTILES
# ==========================================
func shed_shell_as_item():
	if slime.mass_manager and not slime.mass_manager.has_shell():
		print("No hay cáscara/armadura para expulsar!")
		return
	var has_form = slime.form_controller and slime.form_controller.get_current_form() != FormController.Form.SLIME
	var has_element = current_element != "BASE"
	
	if not has_form and not has_element: return
		
	var shell_item = _create_base_shell_item()
	shell_item.scale = slime.base_visual_scale
	
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
	var has_form = slime.form_controller and slime.form_controller.get_current_form() != FormController.Form.SLIME
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

func spawn_matter_projectile():
	var blob = ConsumableItem.new()
	blob.add_to_group("expelled_mass")
	blob.set_meta("mass_value", 0.2)
	blob.item_weight = 0.2
	blob.form_to_grant = "SLIME"
	blob.set("element_to_grant", current_element)
	
	var mesh_inst = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	mesh_inst.mesh = sphere
	
	if current_custom_material != null: mesh_inst.material_override = current_custom_material
	elif slime.transformation_module and slime.transformation_module.elemental_materials.has(current_element): 
		mesh_inst.material_override = slime.transformation_module.elemental_materials[current_element]
	else: 
		# 🔥 FIX: Usamos el liquid material para los proyectiles base
		mesh_inst.material_override = cached_base_liquid_mat
		
	var col = CollisionShape3D.new()
	col.shape = SphereShape3D.new()
	col.shape.radius = 0.3
	
	blob.add_child(mesh_inst)
	blob.add_child(col)
	blob.set("item_mesh", sphere)
	
	get_tree().current_scene.add_child(blob)
	
	if slime.camera_controller:
		var aim_dir = slime.camera_controller.get_aim_direction()
		blob.global_position = slime.hold_position.global_position + (aim_dir * 1.5)
		blob.apply_central_impulse((aim_dir + Vector3(0, 0.2, 0)).normalized() * 15.0)

# ==========================================
# 🛠️ FUNCIONES AUXILIARES INTERNAS
# ==========================================
func _create_base_shell_item() -> ConsumableItem:
	var shell_item = ConsumableItem.new()
	
	if slime.form_controller:
		shell_item.form_to_grant = slime.form_controller.get_form_name(slime.form_controller.get_current_form())
	else:
		shell_item.form_to_grant = "SLIME"
		
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
