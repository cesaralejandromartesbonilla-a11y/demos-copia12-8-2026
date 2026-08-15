class_name MassManager extends Node3D

@export var target_collision_shape: CollisionShape3D

@onready var core_mesh: MeshInstance3D = $CoreMesh
@onready var liquid_mass_mesh: MeshInstance3D = $LiquidMassMesh
@onready var shell_mesh: MeshInstance3D = $ShellMesh

var current_mass_level: float = 1.0

func _ready():
	# Generamos geometrías base por defecto para el núcleo y la masa
	var sphere = SphereMesh.new()
	core_mesh.mesh = sphere
	core_mesh.scale = Vector3(0.5, 0.5, 0.5) # Núcleo siempre pequeño
	
	var mass_sphere = SphereMesh.new()
	liquid_mass_mesh.mesh = mass_sphere

# --- CONTROL DEL NÚCLEO Y LA MASA ---

func update_core(core_material: Material):
	core_mesh.material_override = core_material

func update_liquid_mass(mass_amount: float, mass_material: Material):
	current_mass_level = mass_amount
	
	# Escala dinámica de la capa intermedia
	liquid_mass_mesh.scale = Vector3.ONE * mass_amount
	
	if mass_material != null:
		liquid_mass_mesh.material_override = mass_material
		
	# Si NO tenemos cáscara, la colisión se adapta al tamaño de la masa líquida
	if shell_mesh.mesh == null:
		calculate_dynamic_collision(liquid_mass_mesh)

# --- CONTROL DE LA CÁSCARA ---

func apply_shell(new_mesh: Mesh, shell_material: Material):
	shell_mesh.mesh = new_mesh
	
	if shell_material != null:
		shell_mesh.material_override = shell_material
		
	# La cáscara debe envolver la masa actual
	shell_mesh.scale = liquid_mass_mesh.scale * 1.1 
	
	# La colisión ahora se adapta a la cáscara externa
	calculate_dynamic_collision(shell_mesh)

func remove_shell():
	shell_mesh.mesh = null
	shell_mesh.material_override = null
	# Al quitar la cáscara, la colisión vuelve a depender de la masa líquida
	calculate_dynamic_collision(liquid_mass_mesh)

# --- MAGIA DE COLISIÓN DINÁMICA ---

func calculate_dynamic_collision(target_instance: MeshInstance3D):
	if target_collision_shape == null or target_instance.mesh == null:
		return
		
	# Obtenemos la caja delimitadora (AABB) de la malla
	var aabb: AABB = target_instance.mesh.get_aabb()
	
	# Multiplicamos el tamaño de la malla por la escala actual del nodo
	var real_size = aabb.size * target_instance.scale
	
	# Encontramos la dimensión más grande (X, Y o Z)
	var max_dimension = max(real_size.x, max(real_size.y, real_size.z))
	
	# Adaptamos la forma de colisión de nuestro CharacterBody3D
	if target_collision_shape.shape is SphereShape3D:
		target_collision_shape.shape.radius = max_dimension / 2.0
	elif target_collision_shape.shape is BoxShape3D:
		target_collision_shape.shape.size = Vector3.ONE * max_dimension
