class_name TransformationModule extends Node

enum ChangeType { SIMPLE, TOTAL }

var current_elemental_modifier: String = "BASE"

# Diccionario modular ampliado
# --- DENTRO DE TransformationModule.gd ---

var form_configs: Dictionary = {
	0: { # Form.SLIME
		"mesh_path": "Visuals/SlimeMesh",
		"speed": 5.0, "jump": 4.5, "capacity": 3,
		"is_humanoid": false, "default_element": "BASE",
		"is_modular": false,
		"has_internal_inventory": true
	},
	1: { # Form.STONE
		"mesh_path": "Visuals/StoneMesh",
		"speed": 2.0, "jump": 0.0, "capacity": 1,
		"is_humanoid": false, "default_element": "STONE",
		"is_modular": false,
		"has_internal_inventory": true
	},
	2: { # Form.FIRE
		"mesh_path": "Visuals/fireMesh",
		"speed": 5.0, "jump": 4.5, "capacity": 2,
		"is_humanoid": false, "default_element": "FIRE",
		"is_modular": false,
		"has_internal_inventory": true
	}
}

func allows_internal_inventory(form_index: int) -> bool:
	return form_configs.get(form_index, {}).get("has_internal_inventory", true)

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

# --- NUEVA FUNCIÓN PARA AÑADIR PIEZAS EN TIEMPO REAL ---
func add_dynamic_part(form_index: int, bone_name: String, scene_path: String, player: CharacterBody3D):
	# Verificamos que la forma actual exista y sea modular
	if form_configs.has(form_index) and form_configs[form_index].get("is_modular", false):
		
		# 1. Guardamos la pieza en el diccionario para que no se borre al cambiar de forma
		var parts = form_configs[form_index]["modular_parts"]
		parts.append({
			"bone": bone_name, 
			"scene_path": scene_path
		})
		
		print("Pieza registrada en el Diccionario: ", bone_name)
		
		# 2. Refrescamos la transformación. 
		# Esto hará que tu función _assemble_modular_creature vuelva a leer el array 
		# y pegue la nueva pieza automáticamente de forma limpia.
		apply_transformation(player, form_index)

func get_change_type(form_index: int) -> ChangeType:
	if form_configs.get(form_index, {}).get("is_humanoid", false):
		return ChangeType.TOTAL
	return ChangeType.SIMPLE

func get_capacity(form_index: int) -> int:
	return form_configs.get(form_index, {}).get("capacity", 3)

func apply_transformation(slime: CharacterBody3D, form_index: int):
	_hide_all_meshes(slime)
	var config = form_configs.get(form_index, form_configs[0])
	
	# Colisiones...
	if config["is_humanoid"]:
		var capsule = CapsuleShape3D.new()
		capsule.radius = 0.4; capsule.height = 1.8
		slime.collision_shape.shape = capsule
		slime.collision_shape.position.y = 0.9
	else:
		var sphere = SphereShape3D.new()
		sphere.radius = 0.5
		slime.collision_shape.shape = sphere
		slime.collision_shape.position.y = 0.0
	
	# --- NUEVO: FUSIÓN DE ESTADÍSTICAS (Forma + Elemento Actual) ---
	var current_element = slime.matter_controller.current_element
	var modifiers = elemental_modifiers.get(current_element, elemental_modifiers["BASE"])
	
	slime.locomotion.speed = config["speed"] * modifiers["speed_mult"]
	slime.locomotion.jump_velocity = config["jump"] * modifiers["jump_mult"]
	# (Aquí podrías sumar el weight_bonus a una variable de defensa/daño de impacto en el slime)
	# --------------------------------------------------------------

	# Activar malla y ensamblaje...
	var mesh_node = slime.get_node_or_null(config["mesh_path"])
	if mesh_node:
		mesh_node.visible = true
		if config.get("is_modular", false):
			_assemble_modular_creature(slime, mesh_node, config["modular_parts"])
		else:
			_clear_modular_attachments(mesh_node, slime)
		
		if config["is_humanoid"] and mesh_node.has_node("Armature/Skeleton3D"):
			for child in mesh_node.get_node("Armature/Skeleton3D").get_children():
				if child is SkeletonIK3D:
					child.start()
		
		# Aplicar el material del elemento actual
		_apply_material_override(mesh_node, current_element)

func apply_element_only(slime: CharacterBody3D, element: String):
	current_elemental_modifier = element
	apply_transformation(slime, slime.form_controller.get_current_form())

func _assemble_modular_creature(player: CharacterBody3D, base_mesh: Node3D, parts: Array):
	_clear_modular_attachments(base_mesh)
	
	var all_sockets = []
	for child in base_mesh.find_children("*"):
		if child is InteractiveSocket:
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
				target_socket.is_occupied = true
				
				if limb_instance.limb_type == limb_instance.LimbType.ARM or limb_instance.limb_type == limb_instance.LimbType.WEAPON:
					if limb_instance.target_marker and player.hold_position:
						player.hold_position.reparent(limb_instance.target_marker, false)
						player.hold_position.position = Vector3.ZERO
						player.hold_position.rotation = Vector3.ZERO
							
				print("✅ ¡Pieza real acoplada en el socket: ", target_bone, "!")

func _clear_modular_attachments(base_mesh: Node3D, player: CharacterBody3D = null):
	# Si pasamos el jugador, devolvemos el HoldPosition a la cabeza del slime por defecto
	if player and player.hold_position and player.default_hold_parent:
		player.hold_position.reparent(player.default_hold_parent, false)
		player.hold_position.transform = player.default_hold_transform

	for child in base_mesh.find_children("*"):
		if child is InteractiveSocket:
			for subchild in child.get_children():
				if subchild.name.begins_with("DynamicAttachment_"):
					subchild.queue_free()
			child.is_occupied = false

# --- FUNCIONES RESTANTES INTACTAS ---

func _apply_material_override(mesh_node: Node3D, element: String):
	var mat = null
	var player = get_parent()
	
	# 🔥 NUEVO: Prioridad 1 -> Usar el material del objeto consumido
	if player.matter_controller and player.matter_controller.current_custom_material != null:
		mat = player.matter_controller.current_custom_material
	# Prioridad 2 -> Usar el diccionario base
	else:
		mat = elemental_materials.get(element, null)
		
	if "material_override" in mesh_node:
		mesh_node.material_override = mat
	elif mesh_node is MeshInstance3D:
		mesh_node.set_surface_override_material(0, mat)

func _hide_all_meshes(slime: CharacterBody3D):
	for config in form_configs.values():
		var node = slime.get_node_or_null(config["mesh_path"])
		if node:
			node.visible = false
			var ik_nodes = node.find_children("*", "SkeletonIK3D")
			for ik in ik_nodes:
				ik.stop()

func force_elemental_combination(element: String):
	if elemental_materials.has(element):
		current_elemental_modifier = element
