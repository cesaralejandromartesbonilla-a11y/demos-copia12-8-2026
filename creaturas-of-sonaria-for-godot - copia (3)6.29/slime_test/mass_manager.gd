extends Node3D
class_name MassManager

# 🔥 NUEVO: Señales para la economía de la masa
signal mass_scale_changed(new_scale: float)
signal liquid_mass_depleted

@export var target_collision_shape: CollisionShape3D

@onready var core_mesh: MeshInstance3D = $CoreMesh
@onready var liquid_mass_mesh: MeshInstance3D = $LiquidMassMesh
@onready var shell_mesh: MeshInstance3D = $ShellMesh

# 🔥 NUEVO: Área que detecta todo lo que toca la masa líquida
var absorption_area: Area3D
var absorption_col: CollisionShape3D

var current_mass_level: float = 1.0
const MAX_MASS_LEVEL: float = 5.0 # Límite de crecimiento
const MIN_MASS_LEVEL: float = 1.0

var default_core_mat: StandardMaterial3D 

func _ready():
	# 1. CREAR EL MATERIAL DEL NÚCLEO
	default_core_mat = StandardMaterial3D.new()
	default_core_mat.emission_enabled = true
	default_core_mat.albedo_color = Color(1, 1, 1)
	default_core_mat.emission = Color(1, 1, 1)
	default_core_mat.emission_energy_multiplier = 4.0
	
	change_core_shape("SPHERE")
	
	# 2. LÍQUIDO BASE
	var mass_sphere = SphereMesh.new()
	liquid_mass_mesh.mesh = mass_sphere
	liquid_mass_mesh.scale = Vector3.ONE
	
	# 🔥 NUEVO: Crear el Área de Absorción por código ("Física de Pulpo")
	_setup_absorption_area()

func _setup_absorption_area():
	absorption_area = Area3D.new()
	absorption_area.name = "AbsorptionArea"
	# Capa de colisión exclusiva para que detecte items y ataques
	absorption_area.collision_layer = 0 
	absorption_area.collision_mask = 2 | 4 | 8 # Ajusta según las capas de tus Items/Enemigos
	
	absorption_col = CollisionShape3D.new()
	absorption_col.shape = SphereShape3D.new()
	absorption_col.shape.radius = 0.5 # Radio base igual al líquido
	
	absorption_area.add_child(absorption_col)
	add_child(absorption_area)
	
	# Conectamos para procesar el daño o absorción
	absorption_area.body_entered.connect(_on_absorption_body_entered)
	absorption_area.area_entered.connect(_on_absorption_area_entered)

# ==========================================
# 💧 ECONOMÍA DE LA MASA LÍQUIDA (🔥 NUEVO)
# ==========================================
func add_mass(amount: float):
	current_mass_level = clamp(current_mass_level + amount, MIN_MASS_LEVEL, MAX_MASS_LEVEL)
	_update_visuals()

func take_elemental_damage(amount: float):
	current_mass_level -= amount
	if current_mass_level <= MIN_MASS_LEVEL:
		current_mass_level = MIN_MASS_LEVEL
		liquid_mass_depleted.emit()
	_update_visuals()

func _update_visuals():
	# Solo escalamos la malla visual y el área de absorción
	var new_scale = Vector3.ONE * current_mass_level
	
	var tween = get_tree().create_tween().set_parallel(true)
	tween.tween_property(liquid_mass_mesh, "scale", new_scale, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(absorption_col, "scale", new_scale, 0.3)
	
	if shell_mesh.mesh != null:
		tween.tween_property(shell_mesh, "scale", new_scale * 1.15, 0.3)
		
	mass_scale_changed.emit(current_mass_level)

# ==========================================
# 🔶 SISTEMA DE FORMAS DEL NÚCLEO
# ==========================================
func change_core_shape(shape_type: String):
	# ... (Mismo código que ya tenías)
	var new_mesh: PrimitiveMesh
	match shape_type.to_upper():
		"CUBE", "BOX":
			new_mesh = BoxMesh.new()
			new_mesh.size = Vector3(0.4, 0.4, 0.4)
		"CYLINDER":
			new_mesh = CylinderMesh.new()
			new_mesh.height = 0.5
			new_mesh.radius = 0.2
		"SPHERE", _:
			new_mesh = SphereMesh.new()
			new_mesh.height = 0.5
			new_mesh.radius = 0.25 
			
	core_mesh.mesh = new_mesh
	core_mesh.material_override = default_core_mat
	core_mesh.scale = Vector3.ONE

func update_liquid_mass_material(mass_material: Material):
	liquid_mass_mesh.material_override = mass_material

# ==========================================
# ⚠️ DETECCIÓN DEL ÁREA (ABSORCIÓN / DAÑO)
# ==========================================
func _on_absorption_body_entered(body: Node3D):
	# Aquí verificamos si es un item físico para consumirlo
	if body is PickableItem and not body.is_queued_for_deletion():
		if body.has_method("get_item_data"):
			var data: ItemData = body.get_item_data()
			if data:
				# Pasamos el ItemData al MatterController para procesarlo
				get_parent().matter_controller.process_consumed_item(data)
				body.queue_free() # Lo destruimos al absorberlo

func _on_absorption_area_entered(area: Area3D):
	# Aquí detectaremos si entra una flecha de fuego o magia enemiga
	if area.is_in_group("elemental_hazard"):
		var damage = area.get_meta("damage_amount", 0.5)
		take_elemental_damage(damage)
