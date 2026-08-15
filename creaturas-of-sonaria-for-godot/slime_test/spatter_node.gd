extends RigidBody3D
class_name SpatterNode

var mass_value: float = 0.0
var current_element: String = "BASE"
var visual_material: Material

func _ready():
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered)
	
	# Sistema de seguridad: si la gota cae al vacío, se destruye tras 5 segundos
	get_tree().create_timer(5.0).timeout.connect(queue_free)

func _on_body_entered(body: Node):
	# Ignoramos al jugador o a otras gotas flotantes
	if body is CharacterBody3D or body.is_in_group("slime_projectiles"): return
	
	# 💥 ¡IMPACTO! Generamos el charco real aquí mismo
	var puddle = PuddleNode.new()
	puddle.add_to_group("slime_projectiles")
	puddle.stored_mass = mass_value
	puddle.stored_element = current_element
	
	# Le damos la malla y colisión al charco
	var mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.5 * mass_value
	sphere.height = 0.5 * mass_value
	mesh.mesh = sphere
	if visual_material != null: mesh.material_override = visual_material
	
	var col = CollisionShape3D.new()
	col.shape = sphere
	
	puddle.add_child(mesh)
	puddle.add_child(col)
	
	# Lo añadimos al mundo en la posición exacta del choque
	get_tree().current_scene.add_child.call_deferred(puddle)
	puddle.set_deferred("global_position", global_position)
	
	# Destruimos la gota voladora
	queue_free()
