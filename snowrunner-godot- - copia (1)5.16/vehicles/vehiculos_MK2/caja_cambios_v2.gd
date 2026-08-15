extends Node
class_name CajaCambios

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

@export_group("Termodinámica y Radiador")
@export var radiador: Radiador
@export var temp_ambiente: float = 25.0
@export var temp_maxima_aceite: float = 130.0
@export var conductividad_termica_caja: float = 1.5

var temp_aceite_caja: float = 25.0
var caja_recalentada: bool = false

var marcha_actual: int = 0 
var en_parking: bool = true
var temperatura_embrague: float = 0.0
var embrague_quemado: bool = false

func _ready() -> void:
	temp_aceite_caja = temp_ambiente

func _process(delta: float) -> void:
	# 1. Enfriamiento y recuperación del embrague
	if modo_dano != ModoDanoEmbrague.DESACTIVADO:
		if temperatura_embrague > 0.0:
			temperatura_embrague = max(0.0, temperatura_embrague - (tasa_enfriamiento * delta))
			
			if temperatura_embrague == 0.0 and embrague_quemado:
				if modo_dano == ModoDanoEmbrague.TEMPORAL:
					embrague_quemado = false
					print("Embrague enfriado. Tracción recuperada.")

	# 2. Intercambio de calor del aceite de la caja (SIEMPRE ACTIVO)
	if is_instance_valid(radiador):
		temp_aceite_caja = radiador.intercambiar_calor(temp_aceite_caja, conductividad_termica_caja, delta)
	elif temp_aceite_caja > temp_ambiente:
		# Disipación dinámica si no hay radiador (se enfría más rápido si está muy caliente)
		var exceso_calor = temp_aceite_caja - temp_ambiente
		temp_aceite_caja -= (exceso_calor * 0.05) * delta

	# 3. Recuperación automática si la caja se había bloqueado por calor extremo
	if caja_recalentada and temp_aceite_caja < (temp_maxima_aceite - 20.0):
		caja_recalentada = false
		print("Transmisión enfriada. Engranajes desbloqueados.")

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

# Función auxiliar para que el camión sepa a qué velocidad debe girar el "volante de inercia"
func get_velocidad_objetivo() -> float:
	if marcha_actual > 0:
		return vel_adelante[marcha_actual - 1]
	elif marcha_actual < 0:
		return -vel_reversa[abs(marcha_actual) - 1]
	return 0.0

# --- NUEVA VERSIÓN CON LOS 4 ESCENARIOS ---
func procesar_transmision(fuerza_entrada_motor: float, vel_volante: float, vel_ruedas: float, input_acelerador: float, delta: float) -> Dictionary:
	if es_automatica and en_parking:
		return {"velocidad": 0.0, "fuerza": 0.0, "freno_parking": true}
		
	if marcha_actual == 0 or fuerza_entrada_motor <= 0.0 or embrague_quemado or caja_recalentada:
		return {"velocidad": 0.0, "fuerza": 0.0, "freno_parking": false}
		
	if es_automatica:
		_procesar_cambio_automatico(vel_ruedas)

	var vel_objetivo: float = get_velocidad_objetivo()
	var multiplicador_marcha: float = 1.0 
	
	if marcha_actual > 0:
		multiplicador_marcha = fuerza_adelante[marcha_actual - 1] / 1000.0 
	else:
		var indice_rev = abs(marcha_actual) - 1
		multiplicador_marcha = fuerza_reversa[indice_rev] / 1000.0

	var eficiencia_embrague = 1.0 if modo_dano == ModoDanoEmbrague.DESACTIVADO else 1.0 - (temperatura_embrague / temperatura_maxima)
	var fuerza_salida = fuerza_entrada_motor * multiplicador_marcha * eficiencia_embrague
	var velocidad_salida = vel_objetivo * input_acelerador

# --- EVALUACIÓN DE LOS 4 ESCENARIOS ---
	if modo_dano != ModoDanoEmbrague.DESACTIVADO and input_acelerador > 0.05:
		var diferencia = vel_ruedas - vel_volante
		var margen_sincronia = 3.0 # Rango para considerar que giran iguales
		
		# ESCENARIO 1: Ruedas giran mucho más rápido que el "volante" (Resistencia / Freno de motor)
		if diferencia > margen_sincronia:
			velocidad_salida = vel_volante 
			fuerza_salida = max(fuerza_salida, 1500.0) 
			
		# REGLA 2: Solo evaluamos daño si el volante gira más rápido que las ruedas (vel_volante > vel_ruedas)
		elif vel_volante > (vel_ruedas + margen_sincronia):
			var resbalamiento = vel_volante - vel_ruedas
			
			# REGLA 1: Solo bajo cargas extremas (acelerador a más de la mitad) y un giro dispar alto (> 20.0)
			if resbalamiento > 20.0 and input_acelerador > 0.5:
				# Suavizamos el impacto: solo tomamos el "exceso" de resbalamiento y lo dividimos para no quemarlo en 1 segundo
				var factor_carga = (resbalamiento - 20.0) * 0.05 
				temperatura_embrague += factor_carga * multiplicador_calentamiento * input_acelerador * delta
				
				# Avisos visuales/consola
				if temperatura_embrague > temperatura_maxima * 0.8:
					print("¡Advertencia! Olor a embrague quemado (Sobreesfuerzo)...")
					
				if temperatura_embrague >= temperatura_maxima:
					temperatura_embrague = temperatura_maxima
					embrague_quemado = true
					print("¡EMBRAGUE QUEMADO POR SOBRECARGA EXTREMA!")
					return {"velocidad": 0.0, "fuerza": 0.0, "freno_parking": false}

		# ESCENARIO 4: Sincronía ideal (Buff de potencia)
		elif abs(diferencia) <= margen_sincronia:
			fuerza_salida *= 1.15 # 15% más de fuerza como recompensa por el acople perfecto
			# Disipamos un poco el calor por buen uso
			temperatura_embrague = max(0.0, temperatura_embrague - (tasa_enfriamiento * 2.0 * delta))

		# ESCENARIO 3: Desfase brusco / Detención en marcha alta (Calentón de caja)
		if abs(marcha_actual) >= 3 and vel_ruedas < 5.0 and vel_volante > 30.0:
			temp_aceite_caja += 45.0 * delta 

	# --- LÓGICA TÉRMICA DEL ACEITE DE CAJA ---
	# El calentamiento solo ocurre aquí porque depende de los engranajes moviéndose
	temp_aceite_caja += (vel_volante * 0.05 * input_acelerador) * delta
	
	if temp_aceite_caja >= temp_maxima_aceite:
		temp_aceite_caja = temp_maxima_aceite
		caja_recalentada = true
		print("¡TRANSMISIÓN SOBRECALENTADA! Engranajes bloqueados.")
		return {"velocidad": 0.0, "fuerza": 0.0, "freno_parking": false}

	return {
		"velocidad": velocidad_salida,
		"fuerza": fuerza_salida,
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
