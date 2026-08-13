# Contrato base para cualquier fuente de potencia (Motor de combustión, Turbina,
# Motor eléctrico, Cohete...). La velocidad_angular es real e integrada —
# torque neto dividido por inercia rotacional, igual que ya hicimos con la
# suspensión — no una velocidad impuesta desde afuera. Esto es lo que permite
# que un motor pueda "acelerar en vacío" con el embrague suelto, calar si se
# le exige de más, etc., sin necesitar código especial para cada caso: emerge
# de la física real en vez de simularse a mano.
extends Node
class_name PowerSource

@export var inercia_rotacional: float = 0.15  # kg·m² — qué tan rápido cambia de velocidad ante un torque neto

var velocidad_angular: float = 0.0  # rad/s — el "rpm" real del eje de salida

# Las fuentes concretas (Motor, Turbina...) implementan esto: dado el input
# del jugador, cuánto torque PUEDEN generar a la velocidad_angular actual
# (curva de potencia, admisión, combustible, térmica — lo que corresponda).
# No tocar velocidad_angular acá adentro; eso lo hace procesar().
func _torque_generado(input_jugador: float, delta: float) -> float:
	push_error("PowerSource._torque_generado() no implementado — sobreescribir en la subclase")
	return 0.0

# Se llama una vez por frame desde el consumidor conectado (ver PowerConsumer).
# torque_resistencia es cuánto torque está tirando hacia atrás lo que esté
# conectado (embrague, carga de un generador, lo que sea) — puede ser 0 si
# no hay nada conectado, y el eje debería acelerar libremente en ese caso.
func procesar(input_jugador: float, torque_resistencia: float, delta: float) -> float:
	var torque_generado = _torque_generado(input_jugador, delta)
	var torque_neto = torque_generado - torque_resistencia

	velocidad_angular += (torque_neto / inercia_rotacional) * delta
	velocidad_angular = max(0.0, velocidad_angular)  # no gira "para atrás" solo por resistencia

	return torque_generado
