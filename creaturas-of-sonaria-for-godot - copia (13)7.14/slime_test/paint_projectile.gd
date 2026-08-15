extends RigidBody3D
class_name PaintProjectile

var mass_cost: float = 0.2
var element: String = "BASE"
var visual_mat: Material

func _ready():
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_impact)
	
	# Autodestrucción de seguridad por si disparas al cielo
	get_tree().create_timer(3.0).timeout.connect(queue_free)

func _on_impact(body: Node):
	# Evitamos chocar con el jugador mismo o proyectiles flotando
	if body is CharacterBody3D or body.is_in_group("slime_projectiles"): return
	
	_create_splat()
	queue_free() # Destruimos la bala

func _create_splat():
	var puddle = PuddleNode.new()
	puddle.add_to_group("slime_projectiles")
	puddle.stored_mass = mass_cost
	puddle.stored_element = element
	
	# Creamos la malla visual del charco (ya aplastado)
	var mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.8 # Un área generosa para poder pararse encima
	sphere.height = 0.2 # Aplastado como una mancha
	mesh.mesh = sphere
	if visual_mat != null: mesh.material_override = visual_mat
	
	var col = CollisionShape3D.new()
	col.shape = sphere
	
	puddle.add_child(mesh)
	puddle.add_child(col)
	
	# Añadimos el charco al mundo en el lugar exacto del impacto
	get_tree().current_scene.add_child.call_deferred(puddle)
	puddle.set_deferred("global_position", global_position)
