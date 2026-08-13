@tool
extends MultiMeshInstance3D

@export var extents := Vector2.ONE
@export var spawn_outside_circle := false
@export var radius := 12.0
@export var character_path := NodePath()

# Cambiamos a Node3D y lo dejamos opcional
var _character: Node3D 

func _enter_tree() -> void:
	if not visibility_changed.is_connected(_on_WindGrass_visibility_changed):
		visibility_changed.connect(_on_WindGrass_visibility_changed)

func _ready() -> void:
	# Buscamos al personaje de forma segura
	if has_node(character_path):
		_character = get_node(character_path)
		
	if multimesh == null: return

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var theta := 0.0
	var increase := 1.0
	# SOLUCIÓN: Usamos nuestra propia posición global
	var center: Vector3 = global_transform.origin

	for instance_index in multimesh.instance_count:
		var trans := Transform3D().rotated(Vector3.UP, rng.randf_range(-PI, PI))
		var x: float
		var z: float
		
		if spawn_outside_circle:
			x = (radius + rng.randf_range(0, extents.x)) * cos(theta)
			z = (radius + rng.randf_range(0, extents.y)) * sin(theta)
			theta += increase
		else:
			x = rng.randf_range(-extents.x, extents.x)
			z = rng.randf_range(-extents.y, extents.y)
			
		trans.origin = Vector3(x, 0, z)
		multimesh.set_instance_transform(instance_index, trans)

func _process(_delta: float) -> void:
	# Solo intentamos pasar la posición si el personaje existe
	if _character and material_override:
		material_override.set_shader_parameter(
			"character_position", _character.global_transform.origin
		)

func _on_WindGrass_visibility_changed() -> void:
	if visible:
		_ready()
