extends Node
#class_name CajaCambios

enum ModoDanoEmbrague { DESACTIVADO, TEMPORAL, PERMANENTE }

@export_group("Modo de Transmisión")
@export var es_automatica: bool = false
@export var umbral_subir_marcha: float = 0.5 
@export var umbral_bajar_marcha: float = 0.4

@export_group("Marchas Hacia Adelante")
@export var vel_adelante: Array[float] = [15.0, 30.0, 50.0, 80.0]
@export var fuerza_adelante: Array[float] = [2500.0, 1800.0, 1200.0, 800.0]

@export_group("Marchas Hacia Atrás (Reversa)")
@export var vel_reversa: Array[float] = [10.0, 20.0, 35.0] 
@export var fuerza_reversa: Array[float] = [2800.0, 2000.0, 1500.0]

@export_group("Embrague y Desgaste")
@export var modo_dano: ModoDanoEmbrague = ModoDanoEmbrague.TEMPORAL
@export var temperatura_maxima: float = 100.0
@export var tasa_enfriamiento: float = 20.0
@export var multiplicador_calentamiento: float = 2.5

var marcha_actual: int = 0 
var en_parking: bool = true
var temperatura_embrague: float = 0.0
var embrague_quemado: bool = false

func _process(delta: float) -> void:
	if modo_dano == ModoDanoEmbrague.DESACTIVADO:
		temperatura_embrague = 0.0
		embrague_quemado = false
		return

	# El embrague se enfría constantemente con el tiempo
	if temperatura_embrague > 0.0:
		temperatura_embrague = max(0.0, temperatura_embrague - (tasa_enfriamiento * delta))
		
		# Solo recupera la tracción si el modo es TEMPORAL
		if temperatura_embrague == 0.0 and embrague_quemado:
			if modo_dano == ModoDanoEmbrague.TEMPORAL:
				embrague_quemado = false
				print("Embrague enfriado. Tracción recuperada.")
			# Si es PERMANENTE, se queda quemado hasta llamar a reparar_embrague()

# --- LÓGICA DE PALANCA PRND (P -> R -> N -> D) ---
func subir_marcha() -> void:
	if es_automatica:
		if en_parking:
			en_parking = false
			marcha_actual = -1 # Pasa de Parking a Reversa (R1)
			print("Palanca: R")
		elif marcha_actual < 0:
			marcha_actual = 0  # Pasa de Reversa a Neutral
			print("Palanca: N")
		elif marcha_actual == 0:
			marcha_actual = 1  # Pasa de Neutral a Drive (D1)
			print("Palanca: D")
	else:
		if marcha_actual < vel_adelante.size():
			marcha_actual += 1
			print("Marcha: ", get_nombre_marcha())

func bajar_marcha() -> void:
	if es_automatica:
		if marcha_actual > 0:
			marcha_actual = 0  # Pasa de cualquier Drive a Neutral
			print("Palanca: N")
		elif marcha_actual == 0 and not en_parking:
			marcha_actual = -1 # Pasa de Neutral a Reversa
			print("Palanca: R")
		elif marcha_actual < 0:
			marcha_actual = 0  # Reseteamos el índice interno
			en_parking = true  # Pasa de Reversa a Parking
			print("Palanca: P")
	else:
		if marcha_actual > -vel_reversa.size():
			marcha_actual -= 1
			print("Marcha: ", get_nombre_marcha())

# Función pública para talleres, mecánicos o ítems de reparación
func reparar_embrague() -> void:
	embrague_quemado = false
	temperatura_embrague = 0.0
	print("¡Embrague reemplazado/reparado con éxito!")

func get_nombre_marcha() -> String:
	if es_automatica and en_parking:
		return "P"
	if marcha_actual == 0:
		return "N"
	elif marcha_actual < 0:
		return "R" + str(abs(marcha_actual))
	else:
		return ("D" + str(marcha_actual)) if es_automatica else str(marcha_actual)

func procesar_transmision(input_acelerador: float, vel_real_vehiculo: float, delta: float) -> Dictionary:
	# 1. PRIORIDAD ABSOLUTA: Si está en Parking, ordenamos anclar las ruedas
	if es_automatica and en_parking:
		return {"velocidad": 0.0, "fuerza": 0.0, "freno_parking": true}
		
	# 2. Si está en Neutral, no acelera, o el embrague se quemó, rueda libre
	if marcha_actual == 0 or input_acelerador <= 0.05 or embrague_quemado:
		return {"velocidad": 0.0, "fuerza": 0.0, "freno_parking": false}
		
	# --- GESTIÓN DE CAMBIOS AUTOMÁTICOS ---
	if es_automatica:
		_procesar_cambio_automatico(vel_real_vehiculo)

	var vel_objetivo: float = 0.0
	var fuerza_disponible: float = 0.0
	
	if marcha_actual > 0:
		vel_objetivo = vel_adelante[marcha_actual - 1]
		fuerza_disponible = fuerza_adelante[marcha_actual - 1]
	else:
		var indice_rev = abs(marcha_actual) - 1
		vel_objetivo = -vel_reversa[indice_rev] 
		fuerza_disponible = fuerza_reversa[indice_rev]

	# --- LÓGICA DE CALENTAMIENTO DEL EMBRAGUE ---
	var desfase_velocidad = abs(abs(vel_objetivo) - vel_real_vehiculo)
	
	if modo_dano != ModoDanoEmbrague.DESACTIVADO and desfase_velocidad > 22.0: 
		var exceso = desfase_velocidad - 22.0
		temperatura_embrague += exceso * multiplicador_calentamiento * input_acelerador * delta
		
		if temperatura_embrague >= temperatura_maxima:
			temperatura_embrague = temperatura_maxima
			embrague_quemado = true
			print("¡EMBRAGUE QUEMADO! Transmisión desconectada.")
			return {"velocidad": 0.0, "fuerza": 0.0, "freno_parking": false}

	var eficiencia = 1.0
	if modo_dano != ModoDanoEmbrague.DESACTIVADO:
		eficiencia = 1.0 - (temperatura_embrague / temperatura_maxima)
	
	return {
		"velocidad": vel_objetivo * input_acelerador,
		"fuerza": fuerza_disponible * eficiencia * input_acelerador,
		"freno_parking": false
	}

# Lógica interna para decidir cuándo subir o bajar marcha de forma autónoma
func _procesar_cambio_automatico(vel_real: float) -> void:
	if marcha_actual > 0: # Hacia adelante (Drive)
		var vel_max_actual = vel_adelante[marcha_actual - 1]
		
		# Verificar si debe subir marcha
		if vel_real > (vel_max_actual * umbral_subir_marcha) and marcha_actual < vel_adelante.size():
			marcha_actual += 1
			print("Auto-Shift: ", get_nombre_marcha())
			
		# Verificar si debe bajar marcha (usamos la velocidad de la marcha anterior como referencia)
		elif marcha_actual > 1:
			var vel_max_anterior = vel_adelante[marcha_actual - 2]
			if vel_real < (vel_max_anterior * umbral_bajar_marcha):
				marcha_actual -= 1
				print("Auto-Shift: ", get_nombre_marcha())
				
	elif marcha_actual < 0: # Hacia atrás (Reversa Automática)
		var indice_rev = abs(marcha_actual) - 1
		var vel_max_actual = vel_reversa[indice_rev]
		
		if vel_real > (vel_max_actual * umbral_subir_marcha) and abs(marcha_actual) < vel_reversa.size():
			marcha_actual -= 1 # Pasa de -1 (R1) a -2 (R2)
			print("Auto-Shift Reversa: ", get_nombre_marcha())
			
		elif abs(marcha_actual) > 1:
			var vel_max_anterior = vel_reversa[indice_rev - 1]
			if vel_real < (vel_max_anterior * umbral_bajar_marcha):
				marcha_actual += 1 # Pasa de -2 (R2) a -1 (R1)
				print("Auto-Shift Reversa: ", get_nombre_marcha())
