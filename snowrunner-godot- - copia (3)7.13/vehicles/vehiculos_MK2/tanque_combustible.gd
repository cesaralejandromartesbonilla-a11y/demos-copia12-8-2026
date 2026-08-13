extends Node
class_name TanqueCombustible

@export_group("Capacidad")
@export var capacidad_maxima: float = 400.0 
@export var cantidad_actual: float = 400.0

@export_group("Consumo")
@export var consumo_ralenti: float = 0.02
@export var multiplicador_esfuerzo: float = 0.2

# Devuelve true si hay gasolina, false si se secó
func consumir(input_acelerador: float, rpm_factor: float, delta: float) -> bool:
	if cantidad_actual <= 0.0:
		cantidad_actual = 0.0
		return false
		
	# El gasto aumenta si pisas a fondo y las RPM están altas
	var gasto = (consumo_ralenti + (input_acelerador * rpm_factor * multiplicador_esfuerzo)) * delta
	cantidad_actual -= gasto
	
	if cantidad_actual <= 0.0:
		cantidad_actual = 0.0
		print("¡Sin combustible!")
		return false
		
	return true
