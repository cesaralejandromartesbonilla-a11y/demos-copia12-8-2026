extends VoxelGeneratorScript

# Radio del planeta (en voxeles)
const PLANET_RADIUS = 100.0
# Altura de las montañas
const NOISE_HEIGHT = 20.0

var _noise = FastNoiseLite.new()

func _init():
	_noise.frequency = 0.02
	_noise.seed = 1234
	_noise.noise_type = FastNoiseLite.TYPE_OPENSIMPLEX2

# Esta función se ejecuta para cada vóxel.
# Debemos devolver la distancia a la superficie (SDF).
# Negativo = Aire, Positivo = Tierra.
func _get_value(origin: Vector3, buffer: VoxelBuffer) -> void:
	# Iteramos por cada coordenada del bloque que Godot nos pide generar
	for z in range(buffer.get_size().z):
		for x in range(buffer.get_size().x):
			for y in range(buffer.get_size().y):
				# Posición absoluta en el mundo
				var pos = origin + Vector3(x, y, z)
				
				# 1. Forma base: Esfera
				# La distancia desde el centro (0,0,0) menos el radio
				var dist_to_center = pos.length()
				var sphere_shape = dist_to_center - PLANET_RADIUS
				
				# 2. Ruido 3D para montañas y valles
				# Usamos la posición 3D para que el ruido envuelva la esfera sin costuras
				var noise_val = _noise.get_noise_3d(pos.x, pos.y, pos.z) * NOISE_HEIGHT
				
				# 3. Resultado final (SDF)
				# Si el resultado es positivo, es tierra sólida.
				var sdf = sphere_shape + noise_val
				
				# Escribimos en el canal SDF
				buffer.set_voxel_f(sdf, x, y, z, VoxelBuffer.CHANNEL_SDF)
				
				# --- PINTURA AUTOMÁTICA ---
				# Si es tierra (sdf < 0 en Voxel Tools suele ser materia, pero depende de tu configuración)
				# En VoxelLodTerrain Transvoxel: Valores POSITIVOS suelen ser AIRE, NEGATIVOS son TIERRA.
				# Ajuste: Invertimos la lógica para Transvoxel Mesher
				
				# Corrección para Transvoxel: 
				# SDF > 0 = Aire (fuera del planeta)
				# SDF < 0 = Tierra (dentro del planeta)
				
				# Asignamos color basado en la altura/profundidad
				if sdf < 0.0: # Si es sólido
					if sdf > -2.0: # Capa superficial
						buffer.set_voxel(0xFF00FF00, x, y, z, VoxelBuffer.CHANNEL_COLOR) # Verde (Pasto)
					else:
						buffer.set_voxel(0xFF0000FF, x, y, z, VoxelBuffer.CHANNEL_COLOR) # Rojo/Marrón (Tierra)
