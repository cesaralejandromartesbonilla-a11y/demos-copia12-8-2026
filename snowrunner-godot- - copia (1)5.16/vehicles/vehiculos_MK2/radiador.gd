extends Node
class_name Radiador

@export_group("Configuración Térmica")
@export var temp_ambiente: float = 25.0
# Temperatura actual del líquido refrigerante
@export var temp_refrigerante: float = 25.0 
@export var temp_maxima_refrigerante: float = 120.0
@export var tasa_disipacion_base: float = 3.0

@export_group("Ventilador Automático")
@export var umbral_encendido_ventilador: float = 85.0
@export var poder_ventilador: float = 10.0

var ventilador_encendido: bool = false
var radiador_roto: bool = false

func _process(delta: float) -> void:
	if radiador_roto:
		return
		
	# 1. Lógica del termostato / ventilador
	if temp_refrigerante >= umbral_encendido_ventilador:
		ventilador_encendido = true
	elif temp_refrigerante < (umbral_encendido_ventilador - 5.0):
		ventilador_encendido = false
		
	# 2. Disipación pasiva (ambiente) y activa (ventilador)
	var disipacion_total = tasa_disipacion_base
	if ventilador_encendido:
		disipacion_total += poder_ventilador
		
	if temp_refrigerante > temp_ambiente:
		temp_refrigerante -= disipacion_total * delta
		temp_refrigerante = max(temp_ambiente, temp_refrigerante)

# Modula el flujo de aire extra que entra al radiador al avanzar rápido
func procesar_flujo_aire(velocidad_real: float, delta: float) -> void:
	if radiador_roto or temp_refrigerante <= temp_ambiente: return
	# A mayor velocidad, más calor disipa el viento
	var enfriamiento_viento = velocidad_real * 0.5 
	temp_refrigerante -= enfriamiento_viento * delta
	temp_refrigerante = max(temp_ambiente, temp_refrigerante)

# Función vital: Los componentes (Motor/Caja) llaman a esto para transferirle su calor
func intercambiar_calor(temp_componente: float, tasa_transferencia: float, delta: float) -> float:
	if radiador_roto:
		return temp_componente
		
	# Si el componente está más caliente que el refrigerante, el calor viaja al radiador
	if temp_componente > temp_refrigerante:
		var diferencia = temp_componente - temp_refrigerante
		var calor_transferido = diferencia * tasa_transferencia * delta
		
		temp_componente -= calor_transferido
		# El refrigerante absorbe el calor (Sube su temperatura, pero a menor ritmo por su masa líquida)
		temp_refrigerante += calor_transferido * 0.25 
		
		if temp_refrigerante > temp_maxima_refrigerante:
			temp_refrigerante = temp_maxima_refrigerante
			
	return temp_componente
