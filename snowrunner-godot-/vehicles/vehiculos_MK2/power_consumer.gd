# Contrato base para cualquier consumidor de potencia (CajaCambios, Generador,
# Bomba hidráulica, Hélice...). Un mismo PowerSource puede tener uno o varios
# PowerConsumer conectados — cada consumidor pide su propio torque_resistencia
# y hace lo que le corresponda con la salida (mandarla a una rueda, cargar una
# batería, mover un cabezal de corte...).
extends Node
class_name PowerConsumer

@export var fuente: PowerSource  # a qué PowerSource está conectado

# Los consumidores concretos (CajaCambios, Generador...) implementan esto:
# leen fuente.velocidad_angular, deciden cuánto torque_resistencia le piden
# (normalmente llamando a fuente.procesar() con ese valor) y hacen lo que
# corresponda con el torque que reciben de vuelta.
func procesar(delta: float) -> void:
	push_error("PowerConsumer.procesar() no implementado — sobreescribir en la subclase")
