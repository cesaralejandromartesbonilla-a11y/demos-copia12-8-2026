extends PowerSource
class_name Motor

@export var radiador: Radiador
@export var tanque_gasolina: TanqueCombustible

@export_group("Especificaciones")
@export var fuerza_base_motor: float = 3000.0
@export var temp_ambiente: float = 25.0
@export var temp_maxima_motor: float = 115.0

@export_group("Curva de Potencia")
@export var velocidad_max_volante: float = 80.0 
@export var curva_potencia: Curve 
@export var vel_ralenti_volante: float = 10.0

@export_group("Termodinámica")
@export var tasa_calentamiento: float = 12.0
@export var conductividad_termica: float = 2.5 

var temp_actual_motor: float = 25.0
var motor_recalentado: bool = false
var motor_encendido: bool = false
var flujo_aire: float = 0.0

func _ready() -> void:
	temp_actual_motor = temp_ambiente

func alternar_encendido() -> void:
	if motor_encendido:
		motor_encendido = false
		print("Motor apagado.")
	else:
		var tiene_gasolina = true
		if is_instance_valid(tanque_gasolina):
			tiene_gasolina = tanque_gasolina.cantidad_actual > 0.0
			
		if not motor_recalentado and tiene_gasolina:
			motor_encendido = true
			print("Motor encendido.")
		else:
			print("Click... El motor no arranca.")

# Antes era procesar_motor(input_acelerador, vel_volante, delta), llamada a mano
# desde el controlador. Ahora vel_volante ya no llega de afuera: es
# self.velocidad_angular, heredado de PowerSource, y PowerSource.procesar()
# se encarga de integrarla (torque neto / inercia) — acá solo se calcula
# cuánto torque PUEDE entregar el motor en su velocidad_angular actual.
func _torque_generado(input_jugador: float, delta: float) -> float:
	if motor_recalentado:
		return 0.0 
		
	var hay_combustible = true
	if is_instance_valid(tanque_gasolina):
		var rpm_factor = clamp(velocidad_angular / velocidad_max_volante, 0.0, 1.0)
		if motor_encendido:
			hay_combustible = tanque_gasolina.consumir(input_jugador, rpm_factor, delta)
		else:
			hay_combustible = tanque_gasolina.cantidad_actual > 0.0
			
	if not hay_combustible and motor_encendido:
		motor_encendido = false
		print("¡El motor se apagó por falta de combustible!")
		
	if not motor_encendido:
		if temp_actual_motor > temp_ambiente:
			var enfriamiento_viento = 1.5 + (flujo_aire * 0.2)
			temp_actual_motor = max(temp_ambiente, temp_actual_motor - (enfriamiento_viento * delta))
		return 0.0
		
	var acelerador_efectivo = input_jugador
	if velocidad_angular < vel_ralenti_volante:
		acelerador_efectivo = max(input_jugador, 0.15)

	if acelerador_efectivo > 0.0:
		temp_actual_motor += acelerador_efectivo * tasa_calentamiento * delta
		
	if is_instance_valid(radiador):
		temp_actual_motor = radiador.intercambiar_calor(temp_actual_motor, conductividad_termica, delta)
	else:
		if temp_actual_motor > temp_ambiente:
			var exceso_calor = temp_actual_motor - temp_ambiente
			temp_actual_motor -= (exceso_calor * 0.15) * delta

	if temp_actual_motor >= temp_maxima_motor:
		temp_actual_motor = temp_maxima_motor
		motor_recalentado = true
		print("¡MOTOR FUNDIDO / RECALENTADO!")
		
	var eficiencia = 1.0
	if temp_actual_motor > 100.0:
		eficiencia = 1.0 - ((temp_actual_motor - 100.0) / (temp_maxima_motor - 100.0) * 0.5)
		
	var multiplicador_curva: float = 1.0
	var rpm_normalizada = clamp(velocidad_angular / velocidad_max_volante, 0.0, 1.0)
	
	if is_instance_valid(curva_potencia):
		multiplicador_curva = curva_potencia.sample(rpm_normalizada)
	else:
		multiplicador_curva = max(0.2, sin(rpm_normalizada * PI))
		
	return fuerza_base_motor * acelerador_efectivo * eficiencia * multiplicador_curva
