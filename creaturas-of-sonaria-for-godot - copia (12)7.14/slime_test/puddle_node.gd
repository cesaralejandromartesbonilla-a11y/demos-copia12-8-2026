extends RigidBody3D
class_name PuddleNode

var stored_mass: float = 0.0
var stored_element: String = "BASE"
var is_anchored: bool = false
var surface_normal: Vector3 = Vector3.UP
var collision_shape: CollisionShape3D
var mesh_instance: MeshInstance3D
var absorption_area: Area3D

func _ready():
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered)
	
	absorption_area = Area3D.new()
	var area_col = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 1.5 
	area_col.shape = sphere_shape
	absorption_area.add_child(area_col)
	add_child(absorption_area)
	
	absorption_area.body_entered.connect(_on_area_body_entered)

func inherit_slime_visuals(slime_mat: Material):
	if has_node("MeshInstance3D"):
		$MeshInstance3D.material_override = slime_mat.duplicate()

func _on_body_entered(body: Node):
	if is_anchored: return
	
	# 🛡️ SOLUCIÓN AL ERROR: Ignoramos al jugador y a otros proyectiles para no congelarnos en el aire
	if body is CharacterBody3D or body.is_in_group("slime_projectiles"): return
	
	# 📐 Detectar la normal de la superficie (pared, techo, etc)
	# Si nos dejaron caer (sin velocidad), chequeamos hacia abajo. Si nos dispararon, chequeamos hacia adelante.
	var query_dir = linear_velocity.normalized() if linear_velocity.length() > 0.1 else Vector3.DOWN
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, global_position + (query_dir * 2.0))
	var result = space_state.intersect_ray(query)
	
	if result:
		surface_normal = result.normal
		
		# Acomodar visualmente el charco a la pared/techo
		if has_node("MeshInstance3D"):
			var mesh = $MeshInstance3D
			# Rotamos la malla para que coincida con la pared
			if surface_normal != Vector3.UP and surface_normal != Vector3.DOWN:
				mesh.look_at(global_position + surface_normal, Vector3.UP)
				mesh.rotate_x(PI / 2.0)
			elif surface_normal == Vector3.DOWN:
				mesh.rotate_x(PI)
	
	freeze = true
	is_anchored = true
	
	# Efecto de aplastarse
	if has_node("MeshInstance3D"):
		var tween = get_tree().create_tween()
		tween.tween_property($MeshInstance3D, "scale", Vector3(1.5, 0.2, 1.5), 0.1)

# ==========================================
# 🧲 MECÁNICA 2: ABSORBER RESTOS
# ==========================================
func _on_area_body_entered(body: Node):
	if not is_anchored: return
	
	# Si otro proyectil/masa entra en el charco, el charco se lo come
	if body.is_in_group("slime_projectiles") and body != self:
		if "stored_mass" in body:
			stored_mass += body.stored_mass
			body.queue_free() # Destruye el resto
			
			# Hacemos que el charco crezca visualmente
			var growth = 1.0 + (stored_mass * 0.2)
			if has_node("MeshInstance3D"):
				var tween = get_tree().create_tween()
				tween.tween_property($MeshInstance3D, "scale", Vector3(1.5 * growth, 0.2, 1.5 * growth), 0.2)

# ==========================================
# 💉 TRANSFERENCIA AL SLIME
# ==========================================
func _process(delta):
	if not is_anchored or stored_mass <= 0: return
	
	# Verificamos si el Slime está parado sobre el charco
	var bodies = absorption_area.get_overlapping_bodies()
	for body in bodies:
		if body is CharacterBody3D and body.has_method("mass_manager"): # Detecta al Slime
			
			var current_level = body.mass_manager.current_mass_level
			# Solo le pasamos masa si tiene menos de 2.0
			if current_level < 2.0:
				var transfer_rate = 2.0 * delta # Pasa 2 de masa por segundo
				var amount_to_give = min(transfer_rate, stored_mass)
				
				# No darle más de lo que necesita para llegar a 2.0
				var space_left = 2.0 - current_level
				amount_to_give = min(amount_to_give, space_left)
				
				if amount_to_give > 0:
					# **NOTA**: Asegúrate de tener un método para AÑADIR masa en tu mass_manager
					body.mass_manager.current_mass_level += amount_to_give 
					stored_mass -= amount_to_give
					
					# Si el charco se queda sin masa, se seca y desaparece
					if stored_mass <= 0.05:
						queue_free()
