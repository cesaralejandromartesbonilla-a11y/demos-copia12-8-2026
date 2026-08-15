extends Node

@onready var punto_aparicion = $PuntoAparicion

func _ready() -> void:
	# 1. Volvemos a atrapar el mouse para que puedas conducir
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# 2. Le preguntamos al GlobalData qué camión elegiste
	var datos_vehiculo = GlobalData.obtener_datos_vehiculo_activo()
	
	# 3. Lo instanciamos si existe
	if datos_vehiculo["ruta_escena"] != "":
		var escena = load(datos_vehiculo["ruta_escena"]) as PackedScene
		if escena:
			var vehiculo = escena.instantiate()
			
			# --- 1. VESTIR AL VEHÍCULO (Inyectar las piezas del Garaje) ---
			if datos_vehiculo.has("ruta_motor") and datos_vehiculo["ruta_motor"] != "":
				vehiculo.motor_equipado = load(datos_vehiculo["ruta_motor"])
				
			if datos_vehiculo.has("ruta_llantas") and datos_vehiculo["ruta_llantas"] != "":
				vehiculo.llantas_equipadas = load(datos_vehiculo["ruta_llantas"])
				
			if datos_vehiculo.has("ruta_caja") and datos_vehiculo["ruta_caja"] != "":
				vehiculo.caja_equipada = load(datos_vehiculo["ruta_caja"])
			
			# --- 2. POSICIONAR ---
			vehiculo.global_transform = punto_aparicion.global_transform
			
			# --- 3. TRAER AL MUNDO ---
			add_child(vehiculo)
			
			# --- 4. DESPERTAR ---
			vehiculo.process_mode = Node.PROCESS_MODE_INHERIT
