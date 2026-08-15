extends Node

const RUTA_GUARDADO = "user://partida_guardada.save"
# Variable para saber si el jugador ya tiene una partida en curso
var hay_partida_activa: bool = false
var mapa_actual_guardado: String = ""

# Los 5 cajones físicos del garaje 3D
var slot_activo: int = 0
var garaje_slots: Array = []
# El inventario infinito 2D
var almacen_vehiculos: Array = []

func _ready() -> void:
	_inicializar_garaje()
	# Lo primero que hace el juego al abrirse es intentar cargar
	cargar_partida()

func _inicializar_garaje() -> void:
	for i in range(5):
		garaje_slots.append({
			"ocupado": false, 
			"ruta_escena": "", 
			"ruta_motor": "", 
			"ruta_caja": "",
			"ruta_llantas": "",
			"etiquetas_actuales": [] 
		})
	
	garaje_slots[0]["ocupado"] = true
	garaje_slots[0]["ruta_escena"] = "res://vehicles/vehiculos/camioneta_base_1/camioneta_base.tscn"
	
	# EL ADN DEL VEHÍCULO (Lo que le dice al menú qué mostrar)
	garaje_slots[0]["especificaciones"] = {
		
		# Es un STRING. Debe coincidir exactamente con el "id" de la pieza.
		"motor_estricto": "",        # Solo acepta este ID exacto
		
		# Es un STRING. Debe coincidir exactamente con la "clase" de la pieza.
		"clase_caja": "",        # Acepta cajas de esta clase
		
		# Es un NÚMERO FLOAT.
		"llanta_ideal_pulgadas": 30.0,    # Buscará alrededor de este tamaño
		
		# Es un ARRAY de STRINGS. Coincide con el "paquete" de los añadidos.
		"paquetes_permitidos": ["paquete_basico", "paquete_pesos", ""] # Añadidos
	}
	
	# EL ADN DEL VEHÍCULO (Lo que le dice al menú qué mostrar)
	#garaje_slots[0]["especificaciones"] = {
		#"motor_estricto": "v8_2.4L",        # Solo acepta este ID exacto
		#"clase_caja": "explorador",        # Acepta cajas de esta clase
		#"llanta_ideal_pulgadas": 30.0,    # Buscará alrededor de este tamaño
		#"paquetes_permitidos": ["paquete_basico", "paquete_pesos"] # Añadidos
	#}

func obtener_datos_vehiculo_activo() -> Dictionary:
	return garaje_slots[slot_activo]

func guardar_partida(ruta_mapa: String = "") -> void:
	var archivo = FileAccess.open(RUTA_GUARDADO, FileAccess.WRITE)
	if archivo:
		if ruta_mapa != "":
			mapa_actual_guardado = ruta_mapa
			
		var datos_a_guardar = {
			"garaje": garaje_slots,
			"mapa": mapa_actual_guardado,
			"activa": true
		}
		
		archivo.store_var(datos_a_guardar)
		archivo.close()
		print("Partida guardada con éxito en: ", RUTA_GUARDADO)

func cargar_partida() -> void:
	if FileAccess.file_exists(RUTA_GUARDADO):
		var archivo = FileAccess.open(RUTA_GUARDADO, FileAccess.READ)
		if archivo:
			var datos_cargados = archivo.get_var()
			garaje_slots = datos_cargados["garaje"]
			mapa_actual_guardado = datos_cargados["mapa"]
			hay_partida_activa = datos_cargados["activa"]
			archivo.close()
			print("Partida cargada. Mapa guardado: ", mapa_actual_guardado)
	else:
		print("No hay partida guardada. Es un jugador nuevo.")

func borrar_partida() -> void:
	# Para cuando el jugador le da a "Nueva Partida"
	if FileAccess.file_exists(RUTA_GUARDADO):
		var dir = DirAccess.open("user://")
		dir.remove("partida_guardada.save")
	hay_partida_activa = false
	mapa_actual_guardado = ""
	# Aquí deberías reiniciar garaje_slots a sus valores por defecto
