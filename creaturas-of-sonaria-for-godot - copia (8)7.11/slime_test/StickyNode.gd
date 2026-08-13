extends RigidBody3D
class_name StickyNode

var stored_mass: float = 0.2
var stored_element: String = "BASE"
var is_anchored: bool = false
var original_damp: float = 0.0
var is_depleted: bool = false
var tether_mesh: MeshInstance3D
var tether_material: ShaderMaterial
var surface_normal: Vector3 = Vector3.UP

@onready var tether_shader: Shader = preload("res://slime_test/tether_liquid.gdshader")

func _ready():
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered)
	
	# Creamos el tentáculo visual
	tether_mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.15
	cyl.radial_segments = 12 
	cyl.rings = 8 # Más subdivisiones para que el shader se curve bonito
	tether_mesh.mesh = cyl
	tether_mesh.visible = false
	
	# Inicializamos el material del brazo
	tether_material = ShaderMaterial.new()
	tether_material.shader = tether_shader
	tether_mesh.material_override = tether_material
	
	add_child(tether_mesh)

func inherit_slime_visuals(slime_mat: Material): 
	if has_node("MeshInstance3D"):
		var node_mesh = $MeshInstance3D
		node_mesh.material_override = slime_mat.duplicate() 
		
	if tether_material and slime_mat:
		# Si es nuestro shader líquido:
		if slime_mat is ShaderMaterial:
			tether_material.set_shader_parameter("base_color", slime_mat.get_shader_parameter("base_color"))
			tether_material.set_shader_parameter("element_color", slime_mat.get_shader_parameter("element_color"))
			tether_material.set_shader_parameter("element_blend", slime_mat.get_shader_parameter("element_blend"))
		# Si es un material básico (ej. cached_base_liquid_mat):
		elif slime_mat is StandardMaterial3D:
			tether_material.set_shader_parameter("base_color", slime_mat.albedo_color)

func update_tether(player_pos: Vector3, is_connected: bool):
	if not is_connected:
		tether_mesh.visible = false
		# Lógica Salvavidas: Si nos soltamos de la red y ya nos comimos su masa, se destruye.
		if is_depleted: 
			queue_free()
		return
		
	# Replicamos el material del nodo al tentáculo si no lo tiene
	if tether_mesh.material_override == null and has_node("MeshInstance3D"):
		tether_mesh.material_override = $MeshInstance3D.material_override
		
	tether_mesh.visible = true
	
	# Posicionamos el tubo a la mitad de la distancia y lo estiramos
	var mid_point = (global_position + player_pos) / 2.0
	tether_mesh.global_position = mid_point
	
	var up_vec = Vector3.UP if abs((player_pos - global_position).normalized().y) < 0.99 else Vector3.RIGHT
	tether_mesh.look_at_from_position(mid_point, player_pos, up_vec)
	tether_mesh.rotate_x(PI / 2.0) # Acostamos el cilindro para que apunte bien
	
	var dist = global_position.distance_to(player_pos)
	tether_mesh.scale.y = dist / 2.0 # El tamaño base del cilindro es 2, lo ajustamos a la distancia real

func _on_body_entered(body: Node):
	if is_anchored: return
	if body is CharacterBody3D and body.has_method("mass_manager"): return
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, global_position + linear_velocity.normalized() * 1.5)
	var result = space_state.intersect_ray(query)
	
	if result:
		surface_normal = result.normal # Guardamos si es pared, techo, o suelo
	
	freeze = true
	is_anchored = true
	
	if body is RigidBody3D and body.is_in_group("enemies"):
		original_damp = body.linear_damp
		body.linear_damp = 15.0 
		var remote_transform = RemoteTransform3D.new()
		add_child(remote_transform)
		remote_transform.remote_path = remote_transform.get_path_to(body)
