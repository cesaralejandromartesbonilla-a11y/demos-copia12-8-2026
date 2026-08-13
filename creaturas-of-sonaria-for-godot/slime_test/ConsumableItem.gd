extends RigidBody3D
class_name ConsumableItem 

# Creamos las opciones para el Inspector
enum FormaFisica { CAJA, ESFERA }

@export_group("Propiedades Físicas")
@export var forma_colision: FormaFisica = FormaFisica.CAJA # <-- ¡Nuevo! Podrás elegirlo desde el editor
@export var hands_required: int = 1 
@export var item_weight: float = 5.0

@export_group("Datos del Objeto")
@export var item_name: String = "Objeto Desconocido"
@export var grab_point: Marker3D
@export var item_mesh: Mesh
@export var item_material: Material    # opcional — si el mesh no trae material propio incrustado, se usa este
@export var form_to_grant: String = "NONE" # OBSOLETO — usa form_id / form_override en su lugar
@export var element_to_grant: String = "BASE" # BASE, STONE, FIRE, ICE, etc.

@export_group("Biblioteca de Formas")
@export var form_id: String = ""       # vacío = se genera automáticamente desde item_name
@export var form_override: FormData    # opcional: usa esto si quieres otorgar una forma distinta a su propia apariencia

var mesh_instance: MeshInstance3D

func _ready():
	
	for child in get_children():
		if child is MeshInstance3D:
			child.queue_free()
	if item_mesh != null:
		# 1. Generar la Malla Visual
		mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = item_mesh
		add_child(mesh_instance)
		
		# 2. Buscar si ya tiene colisión hecha a mano
		var has_valid_shape = false
		var shapes = find_children("*", "CollisionShape3D")
		for col in shapes:
			if col.shape != null:
				has_valid_shape = true
				break
				
		# 3. GENERACIÓN INTELIGENTE DE COLISIONES
		if not has_valid_shape:
			var col_shape = CollisionShape3D.new()
			var bounding_box = item_mesh.get_aabb()
			
			match forma_colision:
				FormaFisica.ESFERA:
					var sphere = SphereShape3D.new()
					# Calculamos el lado más grande de la malla para el radio de la esfera
					var max_size = max(bounding_box.size.x, max(bounding_box.size.y, bounding_box.size.z))
					sphere.radius = max_size / 2.0
					col_shape.shape = sphere
				
				FormaFisica.CAJA:
					var box = BoxShape3D.new()
					box.size = bounding_box.size
					col_shape.shape = box
					
			# Centramos la colisión al centro real del objeto 3D
			col_shape.position = bounding_box.get_center() 
			add_child(col_shape)

func set_picked_up(state: bool):
	freeze = state
	if state:
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC 
	else:
		# Nota: FREEZE_MODE_STATIC no es ideal para soltar. Cuando 'freeze' sea falso, volverá a caer normal.
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC 
		
	var shapes = find_children("*", "CollisionShape3D")
	for child in shapes:
		child.disabled = state

func reapply_collision_shape():
	# Primero, eliminamos cualquier colisión vieja para evitar duplicados
	var children = get_children()
	for child in children:
		if child is CollisionShape3D:
			child.queue_free()
	
	# Luego volvemos a generar la colisión basada en la variable actual
	var col_shape = CollisionShape3D.new()
	var bounding_box = item_mesh.get_aabb()
	
	match forma_colision:
		FormaFisica.ESFERA:
			var sphere = SphereShape3D.new()
			var max_size = max(bounding_box.size.x, max(bounding_box.size.y, bounding_box.size.z))
			sphere.radius = max_size / 2.0
			col_shape.shape = sphere
		FormaFisica.CAJA:
			var box = BoxShape3D.new()
			box.size = bounding_box.size
			col_shape.shape = box
			
	col_shape.position = bounding_box.get_center()
	add_child(col_shape)

# ==========================================
# 📚 BIBLIOTECA DE FORMAS — ASIMILACIÓN
# ==========================================
func build_form_data() -> FormData:
	if form_override != null:
		return form_override
	if item_mesh == null:
		return null

	var data := FormData.new()
	data.id = form_id if form_id != "" else item_name.to_lower().replace(" ", "_")
	data.display_name = item_name
	data.mesh = item_mesh
	data.material = item_material
	if data.material == null and item_mesh.get_surface_count() > 0:
		data.material = item_mesh.surface_get_material(0) # fallback: material incrustado en el mesh, si existe
	
	var shapes = find_children("*", "CollisionShape3D")
	if shapes.size() > 0 and shapes[0].shape != null:
		data.collision_shape = shapes[0].shape
		data.collision_position = shapes[0].position
	
	return data
