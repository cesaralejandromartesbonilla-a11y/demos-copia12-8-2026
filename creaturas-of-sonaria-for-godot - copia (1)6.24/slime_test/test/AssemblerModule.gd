extends Node
class_name AssemblerModule

enum ChangeType { SIMPLE, TOTAL }

@export var active_dna: CreatureDNA

var current_instanced_chassis: Node3D = null
var current_elemental_modifier: String = "BASE"

func allows_internal_inventory() -> bool:
	if not active_dna: return false
	return active_dna.has_internal_inventory

var elemental_materials: Dictionary = {
	"BASE": null, 
	"STONE": preload("res://materiales/piedra.tres"),
	"FIRE": preload("res://materiales/fire.tres")
}

# ---FUNCIÓN PARA AÑADIR PIEZAS EN TIEMPO REAL ---
func add_dynamic_part(target_bone: String, part_data: CreaturePartData, player: CharacterBody3D):
	
	# 1. Guardamos la pieza directamente en el ADN maestro
	active_dna.attached_parts.append({
		"bone": target_bone, 
		"part_data": part_data
	})
	
	print("Mutación en ", target_bone, " | Pieza: ", part_data.display_name)
	
	# Opcional: Recalcular las estadísticas de la quimera (peso, velocidad)
	active_dna.recalculate_stats()
	
	# 2. Refrescamos el ensamblaje visual
	# Asumimos que tienes una referencia a la malla principal del jugador
	if player.has_node("Visuals/ChasisBase"):
		var base_mesh = player.get_node("Visuals/ChasisBase")
		_assemble_modular_creature(player, base_mesh, active_dna.attached_parts)

func get_change_type() -> ChangeType:
	if active_dna and active_dna.is_humanoid:
		return ChangeType.TOTAL
	return ChangeType.SIMPLE

func get_capacity() -> int:
	if not active_dna: return 3
	return active_dna.base_capacity

func apply_dna_transformation(player: CharacterBody3D):
	if not active_dna or not active_dna.chassis_scene: return
	
	# 1. Destrucción total del cuerpo anterior (si existe)
	_destroy_current_chassis()
	
	# 2. Configuración del Núcleo (Colisiones y Estadísticas)
	if active_dna.is_humanoid:
		var capsule = CapsuleShape3D.new()
		capsule.radius = 0.4
		capsule.height = 1.8
		player.collision_shape.shape = capsule
		player.collision_shape.position.y = 0.9
	else:
		var sphere = SphereShape3D.new()
		sphere.radius = 0.5
		player.collision_shape.shape = sphere
		player.collision_shape.position.y = 0.0
	
	player.speed = active_dna.total_speed
	player.jump_velocity = active_dna.base_jump_velocity
	
	# 3. Nacimiento del Nuevo Chasis
	current_instanced_chassis = active_dna.chassis_scene.instantiate()
	current_instanced_chassis.name = "ActiveChassis"
	
	var core_node = player.get_node_or_null("Visuals")
	if core_node:
		core_node.add_child(current_instanced_chassis)
		
		# 4. Ensamblaje Modular sobre el nuevo cuerpo recién nacido
		_assemble_modular_creature(player, current_instanced_chassis, active_dna.attached_parts)
		
		_apply_material_override(current_instanced_chassis, current_elemental_modifier)

func _assemble_modular_creature(player: CharacterBody3D, base_mesh: CreatureChassis, parts: Array):
	if "active_limbs" in player:
		player.active_limbs.clear()
		
	_clear_modular_attachments(base_mesh, player)
	
	for part_info in parts:
		var target_bone = part_info["bone"]
		var part_data = part_info["part_data"] 
		
		# ¡Búsqueda instantánea gracias al script del chasis!
		var target_socket = base_mesh.get_socket(target_bone)
				
		if target_socket and part_data and part_data.part_scene:
			var limb_instance = part_data.part_scene.instantiate()
			limb_instance.name = "DynamicAttachment_" + target_bone 
			
			target_socket.add_child(limb_instance)
			target_socket.is_occupied = true
				
			if limb_instance.has_method("update_limb") and player.has_method("register_limb"):
				player.register_limb(limb_instance)
				
				if limb_instance.limb_type == limb_instance.LimbType.ARM or limb_instance.limb_type == limb_instance.LimbType.WEAPON:
					if limb_instance.target_marker:
						player.move_hold_position_to(limb_instance.target_marker)
			
				print("✅ ¡Pieza real acoplada en el socket: ", target_bone, "!")

func _clear_modular_attachments(base_mesh: Node3D, player: CharacterBody3D = null):
	# Si pasamos el jugador, devolvemos el HoldPosition a la cabeza del slime por defecto
	if player and player.has_method("move_hold_position_to"):
		player.move_hold_position_to(player.default_hold_parent)

	for child in base_mesh.find_children("*"):
		if child is InteractiveSocket:
			for subchild in child.get_children():
				if subchild.name.begins_with("DynamicAttachment_"):
					subchild.queue_free()
			child.is_occupied = false

# --- FUNCIONES RESTANTES INTACTAS ---

func _destroy_current_chassis():
	if current_instanced_chassis:
		current_instanced_chassis.queue_free()
		current_instanced_chassis = null

func _hide_all_meshes(player: CharacterBody3D):
	var visuals_node = player.get_node_or_null("Visuals")
	if visuals_node:
		for child in visuals_node.get_children():
			if child is Node3D:
				child.visible = false

func force_elemental_combination(element: String):
	if elemental_materials.has(element):
		current_elemental_modifier = element

func _apply_material_override(mesh_node: Node3D, element: String):
	var mat = elemental_materials.get(element, null)
	if "material_override" in mesh_node:
		mesh_node.material_override = mat
	elif mesh_node is MeshInstance3D:
		mesh_node.set_surface_override_material(0, mat)
