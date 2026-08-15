extends RayCast3D
class_name StreamEmitter

var fuel: float = 1.0 # Actúa como el tanque de masa
var current_element: String = "BASE"
var visual_mesh: MeshInstance3D
var is_shutting_down: bool = false
var stream_material: Material 

func _ready():
	enabled = true
	target_position = Vector3(0, 0, -10.0) 
	
	visual_mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	
	var thickness = clamp(fuel * 0.25, 0.1, 1.0)
	cyl.top_radius = thickness * 0.8
	cyl.bottom_radius = thickness
	cyl.height = 1.0 
	
	visual_mesh.mesh = cyl
	visual_mesh.rotation_degrees.x = 90 
	
	if stream_material != null:
		visual_mesh.material_override = stream_material
		
	add_child(visual_mesh)

func _physics_process(delta):
	if is_shutting_down: return
	
	# 1. CONTROL DE CANCELACIÓN (Asegúrate de usar la acción correcta de tu input)
	# Si suelta el botón O se queda sin masa, se apaga.
	if not Input.is_action_pressed("press_c") or fuel <= 0.0:
		_stop_stream()
		return
		
	# 2. CONSUMO DE COMBUSTIBLE
	fuel -= 1.0 * delta # Consume 1.0 de masa por segundo real
	
	# 3. FÍSICAS (Empuje) Y ESCALADO VISUAL
	var cast_distance = 10.0
	
	if is_colliding():
		cast_distance = global_position.distance_to(get_collision_point())
		var collider = get_collider()
		
		# ¡Aplicamos fuerza física bruta! Más masa = más fuerza de empuje.
		if collider is RigidBody3D:
			var push_dir = -global_transform.basis.z.normalized()
			collider.apply_central_force(push_dir * (500.0 * (1.0 + fuel)) * delta)
			
	# Estiramos el cilindro visual exactamente hasta donde choca
	visual_mesh.scale.y = cast_distance
	visual_mesh.position.z = -cast_distance / 2.0

func _stop_stream():
	is_shutting_down = true
	
	# Si el jugador soltó el botón y aún quedaba combustible (masa), lo dejamos caer
	if fuel > 0.2:
		var puddle = PuddleNode.new()
		puddle.add_to_group("slime_projectiles")
		puddle.stored_mass = fuel
		puddle.stored_element = current_element
		
		# Configuramos el charco
		var mesh = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.5 * fuel
		sphere.height = 0.5 * fuel
		mesh.mesh = sphere
		if visual_mesh.material_override: mesh.material_override = visual_mesh.material_override
		
		var col = CollisionShape3D.new()
		col.shape = sphere
		
		puddle.add_child(mesh)
		puddle.add_child(col)
		
		get_tree().current_scene.add_child.call_deferred(puddle)
		puddle.set_deferred("global_position", global_position - Vector3(0, 0.5, 0))
	
	queue_free()
