extends Node3D
class_name MassManager

@export var target_collision_shape: CollisionShape3D

@onready var core_mesh: MeshInstance3D = $CoreMesh
@onready var liquid_mass_mesh: MeshInstance3D = $LiquidMassMesh
@onready var shell_mesh: MeshInstance3D = $ShellMesh

var current_mass_level: float = 1.0

func _ready():
	# Generamos geometrías base por defecto
	var sphere = SphereMesh.new()
	core_mesh.mesh = sphere
	core_mesh.scale = Vector3(0.5, 0.5, 0.5) # El núcleo siempre es pequeño y central
	
	var mass_sphere = SphereMesh.new()
	liquid_mass_mesh.mesh = mass_sphere

# --- CONTROL DEL NÚCLEO ---

# 🔥 NUEVO: Para que TransformationModule cambie la forma del núcleo en vez de todo el Slime
func update_core_shape(new_mesh: Mesh):
	if new_mesh:
		core_mesh.mesh = new_mesh

func update_core(core_material: Material):
	core_mesh.material_override = core_material

# --- CONTROL DE LA MASA LÍQUIDA ---

func update_liquid_mass(mass_amount: float, mass_material: Material = null):
	current_mass_level = max(mass_amount, 1.0) # Aseguramos que nunca sea más pequeño que 1.0
	
	# Escala dinámica de la capa intermedia (siempre será más grande que el núcleo de 0.5)
	liquid_mass_mesh.scale = Vector3.ONE * current_mass_level
	
	if mass_material != null:
		liquid_mass_mesh.material_override = mass_material
		
	# Si NO tenemos cáscara, la colisión se adapta a la masa líquida
	if shell_mesh.mesh == null:
		calculate_dynamic_collision(liquid_mass_mesh)
	else:
		# Si hay cáscara, debemos actualizar su tamaño para que siga envolviendo al líquido nuevo
		shell_mesh.scale = liquid_mass_mesh.scale * 1.15 

# --- CONTROL DE LA CÁSCARA (ARMADURA) ---

func apply_shell(new_mesh: Mesh, shell_material: Material):
	shell_mesh.mesh = new_mesh
	
	if shell_material != null:
		shell_mesh.material_override = shell_material
		
	# 🔥 FIX VISUAL: La cáscara siempre es un 15% más grande que el líquido para evitar superposición (Z-fighting)
	shell_mesh.scale = liquid_mass_mesh.scale * 1.15 
	
	calculate_dynamic_collision(shell_mesh)

func remove_shell():
	shell_mesh.mesh = null
	shell_mesh.material_override = null
	
	# Volvemos a la colisión del líquido desnudo
	calculate_dynamic_collision(liquid_mass_mesh)

func has_shell() -> bool:
	return shell_mesh.mesh != null

# --- MAGIA DE COLISIÓN DINÁMICA ---

func calculate_dynamic_collision(target_instance: MeshInstance3D):
	if target_collision_shape == null or target_instance.mesh == null:
		return
		
	var aabb: AABB = target_instance.mesh.get_aabb()
	var real_size = aabb.size * target_instance.scale
	var max_dimension = max(real_size.x, max(real_size.y, real_size.z))
	
	if target_collision_shape.shape is SphereShape3D:
		target_collision_shape.shape.radius = max_dimension / 2.0
	elif target_collision_shape.shape is BoxShape3D:
		target_collision_shape.shape.size = Vector3.ONE * max_dimension
