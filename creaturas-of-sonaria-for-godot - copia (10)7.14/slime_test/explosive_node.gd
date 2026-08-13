extends RigidBody3D
class_name ExplosiveNode

var stored_mass: float = 0.2
var stored_element: String = "BASE"
var has_exploded: bool = false

func _ready():
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered)

func inherit_slime_visuals(slime_mat: Material): 
	if has_node("MeshInstance3D"):
		$MeshInstance3D.material_override = slime_mat.duplicate()

func _on_body_entered(_body: Node):
	if has_exploded: return
	has_exploded = true
	
	# 1. Radio de la explosión (escala con la masa que le cargaste)
	var explosion_radius = 2.0 + (stored_mass * 1.5)
	var explosion_force = 15.0 + (stored_mass * 10.0)
	
	print("¡Bomba estalló! Radio: ", explosion_radius)
	
	# 2. Detectar objetos en el radio
	var space_state = get_world_3d().direct_space_state
	var shape = SphereShape3D.new()
	shape.radius = explosion_radius
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = global_transform
	
	var results = space_state.intersect_shape(query)
	for result in results:
		var collider = result.collider
		# Empujar a otros RigidBodies o Enemigos
		if collider is RigidBody3D and collider != self:
			var dir = (collider.global_position - global_position).normalized()
			collider.apply_central_impulse(dir * explosion_force)
		elif collider is CharacterBody3D and collider.is_in_group("enemies"):
			# Si tus enemigos tienen función de recibir daño/empuje:
			if collider.has_method("take_damage"): collider.take_damage(stored_mass * 10.0)
			
	# 3. Dejar masa residual (El 50% de lo que costó la bomba se queda en el suelo)
	_spawn_leftover_puddle()
	
	# 4. Efecto visual (Idealmente instanciarías un nodo de partículas aquí)
	# ...
	
	# Destruir la bomba original
	queue_free()

func _spawn_leftover_puddle():
	# 1. Guardamos la posición ANTES de que la bomba sea destruida
	var spawn_pos = global_position 
	
	# 2. Dividimos la masa residual en 3 fragmentos
	var fragment_count = 3
	var mass_per_fragment = (stored_mass * 0.5) / float(fragment_count)
	
	for i in range(fragment_count):
		var scrap = StickyNode.new()
		scrap.add_to_group("slime_projectiles")
		scrap.stored_mass = mass_per_fragment
		scrap.stored_element = stored_element
		scrap.mass = mass_per_fragment * 1.5
		
		var mesh = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.5 * mass_per_fragment
		sphere.height = 0.5 * mass_per_fragment # Ligeramente aplastado
		mesh.mesh = sphere
		
		if has_node("MeshInstance3D"):
			mesh.material_override = $MeshInstance3D.material_override
			
		var col = CollisionShape3D.new()
		col.shape = sphere
		
		scrap.add_child(mesh)
		scrap.add_child(col)
		get_tree().current_scene.add_child.call_deferred(scrap)
		
		var random_offset = Vector3(randf_range(-1.0, 1.0), 0.5, randf_range(-1.0, 1.0))
		scrap.set_deferred("global_position", spawn_pos + random_offset)
