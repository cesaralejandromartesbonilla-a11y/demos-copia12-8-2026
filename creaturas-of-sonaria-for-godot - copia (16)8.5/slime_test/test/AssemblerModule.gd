extends Node
class_name AssemblerModule

enum ChangeType { SIMPLE, TOTAL }

@export var active_dna: CreatureDNA

## Paso 1a.2 — a dónde saltar cuando se finaliza una criatura en el Taller.
## Ajustá esto a la ruta real de tu escena de Mundo.
@export var world_scene_path: String = "res://escenas/Mundo.tscn"

var current_instanced_chassis: Node3D = null
var current_elemental_modifier: String = "BASE"

func _ready():
	if not active_dna:
		active_dna = CreatureDNA.new()
		active_dna.species_name = "Quimera de Prueba"
		print("⚠️ CUIDADO: No se recibió ADN. Generando un ADN temporal para pruebas.")

func allows_internal_inventory() -> bool:
	if not active_dna: return false
	return active_dna.has_internal_inventory

var elemental_materials: Dictionary = {
	"BASE": null, 
	"STONE": preload("res://materiales/piedra.tres"),
	"FIRE": preload("res://materiales/fire.tres")
}

# --- FUNCIÓN PARA AÑADIR PIEZAS EN TIEMPO REAL ---
# Recibe el InteractiveSocket real (no un String) — el bone_name puede
# repetirse entre clones (dos brazos, segmentos de cola), el nodo no.
func add_dynamic_part(socket: InteractiveSocket, part_data: CreaturePartData, player: CharacterBody3D) -> void:
	if not current_instanced_chassis:
		push_error("AssemblerModule: no hay chasis instanciado todavía. Elegí un Chasis antes de acoplar piezas.")
		return
	if not current_instanced_chassis.is_ancestor_of(socket):
		push_error("AssemblerModule: el socket recibido no pertenece al chasis activo.")
		return

	# La dirección real en el árbol — única incluso entre clones idénticos.
	var socket_path := String(current_instanced_chassis.get_path_to(socket))

	active_dna.attached_parts.append({
		"socket_path": socket_path,
		"bone": socket.bone_name,  # etiqueta/depuración, ya no se usa para buscar
		"part_data": part_data
	})

	print("Mutación en ", socket_path, " | Pieza: ", part_data.display_name)
	active_dna.recalculate_stats()

	_assemble_modular_creature(player, current_instanced_chassis, active_dna.attached_parts)

func get_change_type() -> ChangeType:
	if active_dna and active_dna.is_humanoid:
		return ChangeType.TOTAL
	return ChangeType.SIMPLE

func get_capacity() -> int:
	if not active_dna: return 3
	return active_dna.base_capacity


func _validate_dna() -> bool:
	if not active_dna:
		push_error("Error Assembler: No hay un Recurso CreatureDNA asignado.")
		return false
	if not active_dna.chassis_scene:
		push_error("Error Assembler: El CreatureDNA actual no tiene ninguna escena .tscn asignada en 'chassis_scene'.")
		return false
	return true


## Orquestador — lo usa el Taller (HUD), donde siempre querés ver ambas
## mitades juntas en tiempo real. Nunca cambia de comportamiento ahí.
func apply_dna_transformation(player: CharacterBody3D) -> void:
	if not _validate_dna():
		return
	assemble_visuals(player)
	apply_stat_contract(player)


## Etapa 1a — solo lo visual: chasis + piezas. Cero stats, cero colisión física.
## Sin guion bajo a propósito: es API pública, WorldCreatureSpawner la llama
## desde otra escena.
func assemble_visuals(player: CharacterBody3D) -> void:
	if not _validate_dna():
		return

	# 1. Destrucción total del cuerpo anterior
	_destroy_current_chassis()

	# 2. Nacimiento del Nuevo Chasis
	current_instanced_chassis = active_dna.chassis_scene.instantiate()
	current_instanced_chassis.name = "ActiveChassis"

	# 3. Inyección en el nodo visual
	var core_node = player.get_node_or_null("Visuals")
	if core_node:
		core_node.add_child(current_instanced_chassis)
		print("✅ Chasis base cargado con éxito en el árbol de nodos.")

		_assemble_modular_creature(player, current_instanced_chassis, active_dna.attached_parts)
		_apply_material_override(current_instanced_chassis, current_elemental_modifier)
	else:
		push_error("Error Fatal: El PlayerDummy no contiene un nodo hijo llamado 'Visuals'. El modelo 3D existe pero está flotando en la nada.")


## Etapa 1b — solo stats: colisión física, speed, jump_velocity. Cero mallas, cero sockets.
func apply_stat_contract(player: CharacterBody3D) -> void:
	if not _validate_dna():
		return
	if not ("collision_shape" in player) or player.collision_shape == null:
		push_error("Error Assembler: player no tiene 'collision_shape' asignado — ¿corriste el RequirementsBootstrapper?")
		return

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


## Paso 1a.2 — cierra la edición en el Taller y dispara el cruce de escena.
## Conectalo al botón "Crear" del HUD (Paso 1a.5).
func finalize_creature() -> void:
	if not _validate_dna():
		return
	PendingSpawnData.stage_creature(active_dna)
	get_tree().change_scene_to_file(world_scene_path)


func _assemble_modular_creature(player: CharacterBody3D, base_mesh: CreatureChassis, parts: Array):
	if "active_limbs" in player:
		player.active_limbs.clear()
		
	_clear_modular_attachments(base_mesh, player)
	
	for part_info in parts:
		var part_data = part_info["part_data"]
		var target_socket: InteractiveSocket = null

		if part_info.has("socket_path"):
			var found := base_mesh.get_node_or_null(NodePath(part_info["socket_path"]))
			if found is InteractiveSocket:
				target_socket = found

		# Compatibilidad con datos guardados antes del cambio a socket_path.
		if not target_socket and part_info.has("bone"):
			target_socket = base_mesh.get_socket(part_info["bone"])

		if target_socket and part_data and part_data.part_scene:
			var limb_instance = part_data.part_scene.instantiate()
			limb_instance.name = "DynamicAttachment_" + target_socket.bone_name

			target_socket.add_child(limb_instance)

			# La pieza nace exactamente en el origen del socket, sin arrastrar
			# ningún offset guardado por accidente en su propio .tscn.
			if limb_instance is Node3D:
				limb_instance.transform = Transform3D.IDENTITY

			target_socket.is_occupied = true

			if limb_instance.has_method("update_limb") and player.has_method("register_limb"):
				player.register_limb(limb_instance)

				if limb_instance.limb_type == limb_instance.LimbType.ARM or limb_instance.limb_type == limb_instance.LimbType.WEAPON:
					if limb_instance.target_marker:
						player.move_hold_position_to(limb_instance.target_marker)

				print("✅ ¡Pieza real acoplada en el socket: ", target_socket.bone_name, "!")
		else:
			push_warning("AssemblerModule: no se pudo acoplar la pieza — socket=%s, part_scene=%s" % [target_socket, part_data.part_scene if part_data else "null"])


func _clear_modular_attachments(base_mesh: Node3D, player: CharacterBody3D = null):
	# Si pasamos el jugador, devolvemos el HoldPosition a la posición default.
	if player and player.has_method("move_hold_position_to"):
		player.move_hold_position_to(player.default_hold_parent)

	for child in base_mesh.find_children("*"):
		# El padre de este nodo puede haberse liberado ya en una vuelta
		# anterior de este mismo bucle — sin este chequeo, tocar un nodo
		# ya destruido tira error.
		if not is_instance_valid(child):
			continue

		if child is InteractiveSocket:
			for subchild in child.get_children():
				if subchild.name.begins_with("DynamicAttachment_"):
					# free() en vez de queue_free(): tiene que desaparecer YA.
					# Si no, el nodo viejo sigue vivo mientras nace el nuevo, y
					# un socket_path guardado que apunte adentro suyo (piezas
					# encadenadas) resuelve contra el que está por morir.
					subchild.free()
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
