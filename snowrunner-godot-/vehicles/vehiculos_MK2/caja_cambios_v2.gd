extends PowerConsumer
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

# Las escribe el controlador principal cada frame, igual que antes hacía con
# flujo_aire — ya no llegan como parámetros de una función que el controlador llama
var input_acelerador: float = 0.0
var vel_ruedas: float = 0.0
var flujo_aire: float = 0.0

var temp_aceite_caja: float = 25.0
var caja_recalentada: bool = false
var marcha_actual: int = 0 
var en_parking: bool = true
var temperatura_embrague: float = 0.0
var embrague_quemado: bool = false

# Resultado del último procesar() — el controlador principal lee esto
# en vez de recibir un Dictionary de retorno
var velocidad_salida: float = 0.0
var fuerza_salida: float = 0.0
var freno_parking: bool = false

func _ready() -> void:
	temp_aceite_caja = temp_ambiente

func _process(delta: float) -> void:
	if modo_dano != ModoDanoEmbrague.DESACTIVADO:
		if temperatura_embrague > 0.0:
			var enfriamiento_emb_real = tasa_enfriamiento + (flujo_aire * 0.5)
			temperatura_embrague = max(0.0, temperatura_embrague - (enfriamiento_emb_real * delta))
			if temperatura_embrague == 0.0 and embrague_quemado:
				if modo_dano == ModoDanoEmbrague.TEMPORAL:
					embrague_quemado = false
					print("Embrague enfriado. Tracción recuperada.")

	# Intercambio de calor del aceite de la caja — una sola vez (la v2 original
	# lo llamaba dos veces por error, ver auditoría de la Etapa 0.1)
	if is_instance_valid(radiador):
		temp_aceite_caja = radiador.intercambiar_calor(temp_aceite_caja, conductividad_termica_caja, delta)
	elif temp_aceite_caja > temp_ambiente:
		var exceso_calor = temp_aceite_caja - temp_ambiente
		temp_aceite_caja -= (exceso_calor * 0.05) * delta

	if temp_aceite_caja > temp_ambiente:
		var enfriamiento_viento_caja = (flujo_aire * 0.1) * delta
		temp_aceite_caja = max(temp_ambiente, temp_aceite_caja - enfriamiento_viento_caja)

	if caja_recalentada and temp_aceite_caja < (temp_maxima_aceite - 20.0):
		caja_recalentada = false
		print("Transmisión enfriada. Engranajes desbloqueados.")

# --- LÓGICA DE PALANCA PRND --- (sin cambios respecto al original)
func subir_marcha() -> void:
	if es_automatica:
		if en_parking:
			en_parking = false
			marcha_actual = -1
			print("Palanca: R")
		elif marcha_actual < 0:
			marcha_actual = 0
			print("Palanca: N")
		elif marcha_actual == 0:
			marcha_actual = 1
			print("Palanca: D")
	else:
		if marcha_actual < vel_adelante.size():
			marcha_actual += 1
			print("Marcha: ", get_nombre_marcha())

func bajar_marcha() -> void:
	if es_automatica:
		if marcha_actual > 0:
			marcha_actual = 0
			print("Palanca: N")
		elif marcha_actual == 0 and not en_parking:
			marcha_actual = -1
			print("Palanca: R")
		elif marcha_actual < 0:
			marcha_actual = 0
			en_parking = true
			print("Palanca: P")
	else:
		if marcha_actual > -vel_reversa.size():
			marcha_actual -= 1
			print("Marcha: ", get_nombre_marcha())

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

func get_velocidad_objetivo() -> float:
	if marcha_actual > 0:
		return vel_adelante[marcha_actual - 1]
	elif marcha_actual < 0:
		return -vel_reversa[abs(marcha_actual) - 1]
	return 0.0

# Antes: procesar_transmision(fuerza_entrada_motor, vel_volante, vel_ruedas,
# input_acelerador, delta) -> Dictionary, llamada a mano por el controlador,
# que ya traía fuerza_entrada_motor calculada de afuera.
#
# Ahora implementa el contrato de PowerConsumer: en vez de RECIBIR el torque
# del motor ya calculado, esta caja decide cuánto torque_resistencia le pide
# y lo llama ella misma vía fuente.procesar(). Esa decisión (torque_resistencia
# más abajo) es la única pieza que no es solo una adaptación mecánica — es
# una aproximación real, avisame si se siente mal y la ajustamos.
func procesar(delta: float) -> void:
	if not fuente:
		velocidad_salida = 0.0
		fuerza_salida = 0.0
		freno_parking = false
		return

	if es_automatica and en_parking:
		fuente.procesar(input_acelerador, 0.0, delta)  # motor sigue girando en vacío, sin resistencia
		velocidad_salida = 0.0
		fuerza_salida = 0.0
		freno_parking = true
		return

	if marcha_actual == 0 or embrague_quemado or caja_recalentada:
		fuente.procesar(input_acelerador, 0.0, delta)  # neutral: el motor acelera libre
		velocidad_salida = 0.0
		fuerza_salida = 0.0
		freno_parking = false
		return

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

	# Resistencia que esta caja le pide al motor: proporcional a la relación
	# de marcha actual y a qué tan bien agarra el embrague en este momento.
	var torque_resistencia = multiplicador_marcha * 1000.0 * eficiencia_embrague
	var fuerza_entrada_motor = fuente.procesar(input_acelerador, torque_resistencia, delta)
	var vel_volante = fuente.velocidad_angular

	fuerza_salida = fuerza_entrada_motor * multiplicador_marcha * eficiencia_embrague
	velocidad_salida = vel_objetivo * input_acelerador
	freno_parking = false

	# --- EVALUACIÓN DE LOS 4 ESCENARIOS --- (misma lógica de siempre)
	if modo_dano != ModoDanoEmbrague.DESACTIVADO and input_acelerador > 0.05:
		var diferencia = vel_ruedas - vel_volante
		var margen_sincronia = 3.0

		if diferencia > margen_sincronia:
			velocidad_salida = vel_volante
			fuerza_salida = max(fuerza_salida, 1500.0)

		elif vel_volante > (vel_ruedas + margen_sincronia):
			var resbalamiento = vel_volante - vel_ruedas

			if resbalamiento > 20.0 and input_acelerador > 0.5:
				var factor_carga = (resbalamiento - 20.0) * 0.05
				temperatura_embrague += factor_carga * multiplicador_calentamiento * input_acelerador * delta

				if temperatura_embrague > temperatura_maxima * 0.8:
					print("¡Advertencia! Olor a embrague quemado (Sobreesfuerzo)...")

				if temperatura_embrague >= temperatura_maxima:
					temperatura_embrague = temperatura_maxima
					embrague_quemado = true
					print("¡EMBRAGUE QUEMADO POR SOBRECARGA EXTREMA!")
					velocidad_salida = 0.0
					fuerza_salida = 0.0
					return

		elif abs(diferencia) <= margen_sincronia:
			fuerza_salida *= 1.15
			temperatura_embrague = max(0.0, temperatura_embrague - (tasa_enfriamiento * 2.0 * delta))

		if abs(marcha_actual) >= 3 and vel_ruedas < 5.0 and vel_volante > 30.0:
			temp_aceite_caja += 45.0 * delta

	temp_aceite_caja += (vel_volante * 0.05 * input_acelerador) * delta

	if temp_aceite_caja >= temp_maxima_aceite:
		temp_aceite_caja = temp_maxima_aceite
		caja_recalentada = true
		print("¡TRANSMISIÓN SOBRECALENTADA! Engranajes bloqueados.")
		velocidad_salida = 0.0
		fuerza_salida = 0.0

func _procesar_cambio_automatico(vel_real: float) -> void:
	if marcha_actual > 0:
		var vel_max_actual = vel_adelante[marcha_actual - 1]
		if vel_real > (vel_max_actual * umbral_subir_marcha) and marcha_actual < vel_adelante.size():
			marcha_actual += 1
			print("Auto-Shift: ", get_nombre_marcha())
		elif marcha_actual > 1:
			var vel_max_anterior = vel_adelante[marcha_actual - 2]
			if vel_real < (vel_max_anterior * umbral_bajar_marcha):
				marcha_actual -= 1
				print("Auto-Shift: ", get_nombre_marcha())
	elif marcha_actual < 0:
		var indice_rev = abs(marcha_actual) - 1
		var vel_max_actual = vel_reversa[indice_rev]
		if vel_real > (vel_max_actual * umbral_subir_marcha) and abs(marcha_actual) < vel_reversa.size():
			marcha_actual -= 1
			print("Auto-Shift Reversa: ", get_nombre_marcha())
		elif abs(marcha_actual) > 1:
			var vel_max_anterior = vel_reversa[indice_rev - 1]
			if vel_real < (vel_max_anterior * umbral_bajar_marcha):
				marcha_actual += 1
				print("Auto-Shift Reversa: ", get_nombre_marcha())
