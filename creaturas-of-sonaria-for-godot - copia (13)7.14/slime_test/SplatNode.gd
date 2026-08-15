extends Area3D
class_name SplatNode

var surface_normal: Vector3 = Vector3.UP
var stored_mass: float = 0.2
var stored_element: String = "BASE"

func _ready():
	# 1. Fundamental: Añadimos el charco a un grupo para que el slime lo encuentre
	add_to_group("splats")
	
	# 2. Configuramos la detección para que puedan combinarse
	monitorable = true
	monitoring = true
	area_entered.connect(_on_area_entered)

func setup(impact_position: Vector3, impact_normal: Vector3, splat_color: Color):
	global_position = impact_position
	surface_normal = impact_normal
	
	# Alineación perfecta con la pared/techo
	if surface_normal != Vector3.UP and surface_normal != Vector3.DOWN:
		look_at(global_position + surface_normal, Vector3.UP)
		rotate_x(PI / 2.0)
	elif surface_normal == Vector3.DOWN:
		rotate_x(PI)

	# --- APARTADO VISUAL ---
	var decal = Decal.new()
	decal.extents = Vector3(1.0, 0.5, 1.0) 
	decal.modulate = splat_color
	add_child(decal)
	
	# Malla temporal coloreada (borrar cuando tengas textura de Decal)
	var mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.05 
	mesh.mesh = cyl
	var mat = StandardMaterial3D.new()
	mat.albedo_color = splat_color
	mesh.material_override = mat
	add_child(mesh)

	# --- ÁREA DE DETECCIÓN ---
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1.8, 0.4, 1.8) 
	col.shape = box
	add_child(col)

# ==========================================
# 🧬 FUSIÓN DE CHARCOS
# ==========================================
func _on_area_entered(area: Area3D):
	if area is SplatNode and area != self:
		# Regla de seguridad: El charco que nació ANTES absorbe al NUEVO (evita bucles infinitos)
		if self.get_instance_id() < area.get_instance_id():
			_absorb(area)

func _absorb(other_splat: SplatNode):
	stored_mass += other_splat.stored_mass
	
	# Aumentamos el tamaño visual y de detección, pero lo limitamos para que no cubra todo el mapa
	var growth_factor = 1.0 + (other_splat.stored_mass * 0.3)
	scale = (scale * growth_factor).clamp(Vector3.ONE, Vector3.ONE * 3.5)
	
	# Destruimos el charco nuevo
	other_splat.queue_free()
