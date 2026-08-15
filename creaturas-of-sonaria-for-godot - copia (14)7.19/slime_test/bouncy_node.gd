extends RigidBody3D
class_name BouncyNode

var stored_mass: float = 0.2
var stored_element: String = "BASE"
var bounces: int = 0

func _ready():
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered)

func inherit_slime_visuals(slime_mat: Material): 
	if has_node("MeshInstance3D"):
		$MeshInstance3D.material_override = slime_mat.duplicate()

func _on_body_entered(body: Node):
	bounces += 1
	
	# Opcional: Si rebota muchas veces, aumentamos la fricción para que se detenga
	if bounces > 4 and physics_material_override:
		physics_material_override.bounce = 0.2
		physics_material_override.friction = 0.8
