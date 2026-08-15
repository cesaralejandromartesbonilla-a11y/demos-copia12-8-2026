extends Node
class_name TransformationModule

enum ChangeType { SIMPLE, TOTAL }

# ==========================================
# 🎨 MALLAS CONFIGURABLES EN EL INSPECTOR
# ==========================================
@export_group("Meshes de Formas")
@export var slime_mesh: Mesh
@export var stone_mesh: Mesh
@export var fire_mesh: Mesh

var current_elemental_modifier: String = "BASE"

# Diccionario modular ampliado (Ya no usa mesh_path)
var form_configs: Dictionary = {
	0: { # Form.SLIME
		"speed": 5.0, "jump": 4.5, "capacity": 3,
		"is_humanoid": false, "default_element": "BASE",
		"is_modular": false, "has_internal_inventory": true,
		"modular_parts": []
	},
	1: { # Form.STONE
		"speed": 2.0, "jump": 0.0, "capacity": 1,
		"is_humanoid": false, "default_element": "STONE",
		"is_modular": false, "has_internal_inventory": true,
		"modular_parts": []
	},
	2: { # Form.FIRE
		"speed": 5.0, "jump": 4.5, "capacity": 2,
		"is_humanoid": false, "default_element": "FIRE",
		"is_modular": false, "has_internal_inventory": true,
		"modular_parts": []
	}
}

var elemental_materials: Dictionary = {
	"BASE": null, 
	"STONE": preload("res://materiales/piedra.tres"),
	"FIRE": preload("res://materiales/fire.tres")
}

var elemental_modifiers: Dictionary = {
	"BASE": {"speed_mult": 1.0, "jump_mult": 1.0, "weight_bonus": 0.0},
	"STONE": {"speed_mult": 0.6, "jump_mult": 0.5, "weight_bonus": 10.0},
	"FIRE": {"speed_mult": 1.3, "jump_mult": 1.2, "weight_bonus": -2.0}
}

func allows_internal_inventory(form_index: int) -> bool:
	return form_configs.get(form_index, {}).get("has_internal_inventory", true)

func get_change_type(form_index: int) -> ChangeType:
	if form_configs.get(form_index, {}).get("is_humanoid", false):
		return ChangeType.TOTAL
	return ChangeType.SIMPLE

func get_capacity(form_index: int) -> int:
	return form_configs.get(form_index, {}).get("capacity", 3)

# --- AÑADIR PIEZAS EN TIEMPO REAL ---
func add_dynamic_part(form_index: int, bone_name: String, scene_path: String, player: CharacterBody3D):
	if form_configs.has(form_index) and form_configs[form_index].get("is_modular", false):
		var parts = form_configs[form_index]["modular_parts"]
		parts.append({
			"bone": bone_name, 
			"scene_path": scene_path
		})
		
		print("Pieza registrada en el Diccionario: ", bone_name)
		apply_transformation(player, form_index)

# ==========================================
# 🔄 NÚCLEO DE TRANSFORMACIÓN
# ==========================================
func apply_transformation(slime: CharacterBody3D, form_index: int):
	var config = form_configs.get(form_index, form_configs[0])
	
	# 1. Configuración de Colisiones
	if config.get("is_humanoid", false):
		var capsule = CapsuleShape3D.new()
		capsule.radius = 0.4
		capsule.height = 1.8
		slime.collision_shape.shape = capsule
		slime.collision_shape.position.y = 0.9
	else:
		var sphere = SphereShape3D.new()
		sphere.radius = 0.5
		slime.collision_shape.shape = sphere
		slime.collision_shape.position.y = 0.0
	
	# 2. Fusión de Estadísticas
	var current_element = "BASE"
	if "matter_controller" in slime and slime.matter_controller:
		current_element = slime.matter_controller.current_element
		
	var modifiers = elemental_modifiers.get(current_element, elemental_modifiers["BASE"])
	
	if "locomotion" in slime:
		slime.locomotion.speed = config["speed"] * modifiers["speed_mult"]
		slime.locomotion.jump_velocity = config["jump"] * modifiers["jump_mult"]

	# 3. GESTIÓN DE LA MALLA DINÁMICA
	var main_mesh_node = slime.get_node_or_null("MainVisualMesh")
	if not main_mesh_node:
		# Si no existe, lo creamos por código
		main_mesh_node = MeshInstance3D.new()
		main_mesh_node.name = "MainVisualMesh"
		slime.add_child(main_mesh_node)
	
	# Asignamos la malla correcta según la forma
	main_mesh_node.mesh = _get_mesh_for_form(form_index)
	main_mesh_node.visible = true

	# 4. Modularidad (Totalmente libre de IK)
	if config.get("is_modular", false):
		_assemble_modular_creature(slime, main_mesh_node, config.get("modular_parts", []))
	else:
		_clear_modular_attachments(main_mesh_node, slime)
		
	# 5. Aplicar Material
	_apply_material_override(main_mesh_node, current_element, slime)

# --- FUNCIÓN AUXILIAR PARA OBTENER LA MALLA ---
func _get_mesh_for_form(form_index: int) -> Mesh:
	var target_mesh: Mesh
	match form_index:
		0: target_mesh = slime_mesh if slime_mesh != null else SphereMesh.new()
		1: target_mesh = stone_mesh if stone_mesh != null else BoxMesh.new()
		2: target_mesh = fire_mesh if fire_mesh != null else CylinderMesh.new()
		_: target_mesh = slime_mesh if slime_mesh != null else SphereMesh.new()
	return target_mesh

func apply_element_only(slime: CharacterBody3D, element: String):
	current_elemental_modifier = element
#	if "form_controller" in slime:
#		apply_transformation(slime, slime.form_controller.get_current_form())

# ==========================================
# 🧩 SISTEMA MODULAR LIMPIO
# ==========================================
func _assemble_modular_creature(player: CharacterBody3D, base_mesh: Node3D, parts: Array):
	_clear_modular_attachments(base_mesh)
	
	var all_sockets = []
	for child in base_mesh.find_children("*"):
		if child is InteractiveSocket: # Asume que esta es tu clase personalizada
			all_sockets.append(child)
	
	for part_info in parts:
		var target_bone = part_info["bone"]
		var scene_path = part_info["scene_path"]
		
		var target_socket = null
		for socket in all_sockets:
			if socket.get("bone_name") == target_bone:
				target_socket = socket
				break
				
		if target_socket:
			var part_scene = load(scene_path)
			if part_scene:
				var limb_instance = part_scene.instantiate()
				limb_instance.name = "DynamicAttachment_" + target_bone 
				target_socket.add_child(limb_instance)
				target_socket.set("is_occupied", true)
				
				if "limb_type" in limb_instance and (limb_instance.limb_type == limb_instance.LimbType.ARM or limb_instance.limb_type == limb_instance.LimbType.WEAPON):
					if limb_instance.get("target_marker") and player.get("hold_position"):
						player.hold_position.reparent(limb_instance.target_marker, false)
						player.hold_position.position = Vector3.ZERO
						player.hold_position.rotation = Vector3.ZERO
							
				print("✅ ¡Pieza real acoplada en el socket: ", target_bone, "!")

func _clear_modular_attachments(base_mesh: Node3D, player: CharacterBody3D = null):
	if player and player.get("hold_position") and player.get("default_hold_parent"):
		player.hold_position.reparent(player.default_hold_parent, false)
		player.hold_position.transform = player.default_hold_transform

	for child in base_mesh.find_children("*"):
		if child is InteractiveSocket:
			for subchild in child.get_children():
				if subchild.name.begins_with("DynamicAttachment_"):
					subchild.queue_free()
			child.set("is_occupied", false)

func _apply_material_override(mesh_node: MeshInstance3D, element: String, player: CharacterBody3D):
	var mat = null
	
	# Prioridad 1 -> Usar el material del objeto consumido
	if player.get("matter_controller") and player.matter_controller.current_custom_material != null:
		mat = player.matter_controller.current_custom_material
	# Prioridad 2 -> Usar el diccionario base
	else:
		mat = elemental_materials.get(element, null)
		
	mesh_node.material_override = mat

func force_elemental_combination(element: String):
	if elemental_materials.has(element):
		current_elemental_modifier = element
