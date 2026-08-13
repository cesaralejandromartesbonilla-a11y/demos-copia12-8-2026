# En TierraFisica.gd (Asignado a tu RigidBody3D de la piedra)
extends RigidBody3D

@onready var timer = $Timer
@onready var voxel_lod_terrain: VoxelLodTerrain = get_tree().root.find_child("VoxelLodTerrain", true, false)

func _ready():
	voxel_lod_terrain = get_tree().root.find_child("VoxelLodTerrain", true, false)
	# El timer debe ser de unos 2 segundos para dar tiempo a caer
	timer.timeout.connect(_on_solidificar)
	timer.start()

func _on_solidificar():
	# Solo solidifica si la piedra ya no se está moviendo rápido (está en el suelo)
	if linear_velocity.length() < 0.2:
		solidificar_en_terreno()
	else:
		# Si sigue rodando o cayendo, reintenta en 1 segundo
		timer.start(1.0)

func solidificar_en_terreno():
	# 1. Obtenemos la herramienta de voxel (asegúrate de tener la referencia)
	var vt = voxel_lod_terrain.get_voxel_tool()
	var pos = global_position
	
	# 2. Definimos el área que queremos editar (una caja pequeña alrededor de la posición)
	var box = AABB(pos - Vector3(1,1,1), Vector3(2,2,2))
	
	# 3. CRÍTICO: Solo ejecutamos si el área es editable
	if vt.is_area_editable(box):
		vt.mode = VoxelTool.MODE_ADD
		vt.value = 1.0
		vt.do_sphere(pos, 1.5) 
		queue_free() # Borramos la tierra física después de solidificar
	else:
		# Si no es editable, esperamos un poco y volvemos a intentar 
		# o simplemente no hacemos nada para evitar el crash.
		print("Esperando a que el terreno sea editable para solidificar...")


var tipo_material : int = 0 # 0: Tierra, 1: Oro, 2: Roca
@onready var mesh = $MeshInstance3D

func configurar_material(id: int):
	tipo_material = id
	var mat = StandardMaterial3D.new()
	match id:
		0: mat.albedo_color = Color("4b3621") # Marrón Tierra
		1: mat.albedo_color = Color("ffcc00") # Dorado Oro
		2: mat.albedo_color = Color("707070") # Gris Roca
	mesh.set_surface_override_material(0, mat)
