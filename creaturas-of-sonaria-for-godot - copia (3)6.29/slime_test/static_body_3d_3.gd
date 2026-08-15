extends StaticBody3D

@onready var detector = $DetectorArea
@onready var tree_mesh = $MeshInstance3D
var is_burning = false

func _ready():
	detector.body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# 1. Si el JUGADOR lo toca teniendo el elemento FUEGO
	if "current_element" in body and body.current_element == "FIRE":
		start_fire()
		
	# 2. Si un PROYECTIL de fuego le dispara
	elif body.is_in_group("expelled_mass") and "element_to_grant" in body and body.element_to_grant == "FIRE":
		start_fire()
		body.queue_free()

func start_fire():
	if is_burning: return
	is_burning = true
	print("¡El árbol está en llamas!")
	var burn_material = StandardMaterial3D.new()
	burn_material.albedo_color = Color(1, 0.2, 0)
	tree_mesh.material_override = burn_material
	await get_tree().create_timer(1.5).timeout
	queue_free()
