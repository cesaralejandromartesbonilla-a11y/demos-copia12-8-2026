@tool
extends VoxelLodTerrain

func _ready() -> void:
	# Cargamos las imágenes
	var paths = ["res://assets/Stone.png", "res://assets/Grass.png", "res://assets/Wood.png"]
	var images = []
	
	for path in paths:
		var img = load(path).get_image()
		
		# ¡PASO CLAVE! Si la imagen viene comprimida por el importador, hay que descomprimirla
		if img.is_compressed():
			img.decompress()
			
		# Ahora sí podemos asegurar que todas sean RGBA8 y del mismo tamaño
		img.convert(Image.FORMAT_RGBA8)
		
		# Opcional: Descomenta esta línea si tus PNGs tienen tamaños distintos
		# img.resize(512, 512, Image.INTERPOLATE_LANCZOS)
		
		images.append(img)
	
	var texture_2d_array := Texture2DArray.new()
	var error = texture_2d_array.create_from_images(images)
	
	if error == OK:
		# Asegúrate de que el nombre del parámetro sea exacto al de tu shader de terreno
		#si no tiene shader sale Error al crear el array:
		material.set("shader_parameter/u_texture_array", texture_2d_array)
		print("Texture2DArray creado con éxito!")
	else:
		print("Error al crear el array: ", error)
