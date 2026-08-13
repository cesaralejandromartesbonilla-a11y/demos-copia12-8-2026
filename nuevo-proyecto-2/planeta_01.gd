extends VoxelLodTerrain

@export var radius := 250.0

func _ready():
	# Crear el generador basado en grafos por código (más rápido que GDScript puro)
	var generator = VoxelGeneratorGraph.new()
	
	# --- 1. NODOS DE ENTRADA (Coordenadas X, Y, Z) ---
	var x = generator.create_node("InputX")
	var y = generator.create_node("InputY")
	var z = generator.create_node("InputZ")
	
	# --- 2. LA ESFERA BASE (SDF) ---
	# Nodo SdfSphere: Inputs(x, y, z, radio)
	var sphere = generator.create_node("SdfSphere")
	generator.connect_node(x, 0, sphere, 0) # Conectar X
	generator.connect_node(y, 0, sphere, 1) # Conectar Y
	generator.connect_node(z, 0, sphere, 2) # Conectar Z
	var radius_const = generator.create_node("Constant")
	generator.set_node_param(radius_const, 0, radius) # Radio 250
	generator.connect_node(radius_const, 0, sphere, 3)

	# --- 3. RUIDO DE MONTAÑAS (Perturbación) ---
	var noise_node = generator.create_node("FastNoise3D")
	var noise = FastNoiseLite.new()
	noise.frequency = 0.005 # Frecuencia baja = montañas grandes
	noise.fractal_octaves = 4
	noise.seed = randi()
	generator.set_node_param(noise_node, 0, noise)
	generator.connect_node(x, 0, noise_node, 0)
	generator.connect_node(y, 0, noise_node, 1)
	generator.connect_node(z, 0, noise_node, 2)
	
	# Escalar el ruido (Altura de montañas)
	var terrain_height = generator.create_node("Multiply")
	var height_val = generator.create_node("Constant")
	generator.set_node_param(height_val, 0, 40.0) # 40 metros de altura máx
	generator.connect_node(noise_node, 0, terrain_height, 0)
	generator.connect_node(height_val, 0, terrain_height, 1)

	# --- 4. RUIDO DE CUEVAS (Cheese Noise) ---
	var cave_noise_node = generator.create_node("FastNoise3D")
	var cave_noise = FastNoiseLite.new()
	cave_noise.frequency = 0.02 # Más alta que montañas
	cave_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED # Bueno para túneles
	generator.set_node_param(cave_noise_node, 0, cave_noise)
	generator.connect_node(x, 0, cave_noise_node, 0)
	generator.connect_node(y, 0, cave_noise_node, 1)
	generator.connect_node(z, 0, cave_noise_node, 2)
	
	# Hacemos las cuevas más agresivas multiplicando
	var cave_mult = generator.create_node("Multiply")
	var cave_intensity = generator.create_node("Constant")
	generator.set_node_param(cave_intensity, 0, 15.0) 
	generator.connect_node(cave_noise_node, 0, cave_mult, 0)
	generator.connect_node(cave_intensity, 0, cave_mult, 1)

	# --- 5. COMBINAR TODO (Suma SDF) ---
	# Esfera + Montañas + Cuevas
	# Nota: En SDF, "positivo" es aire, "negativo" es tierra (o viceversa según config)
	# VoxelTools suele usar: Negativo = Materia, Positivo = Aire.
	
	var add_terrain = generator.create_node("Add")
	generator.connect_node(sphere, 0, add_terrain, 0)
	generator.connect_node(terrain_height, 0, add_terrain, 1)
	
	# Sumamos las cuevas (al sumar ruido, creamos huecos en el SDF)
	var final_combine = generator.create_node("Add")
	generator.connect_node(add_terrain, 0, final_combine, 0)
	generator.connect_node(cave_mult, 0, final_combine, 1)

	# --- 6. SALIDA ---
	var output = generator.create_node("OutputSDF")
	generator.connect_node(final_combine, 0, output, 0)
	
	# Compilar y asignar
	generator.compile()
	self.generator = generator
