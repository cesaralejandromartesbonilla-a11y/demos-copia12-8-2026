extends Area3D
class_name Gasolinera

@export_group("Surtidor Físico")
@export var capacidad_maxima_surtidor: float = 5000.0
@export var reservas_actuales: float = 5000.0
@export var velocidad_surtido: float = 15.0

@export_group("Reabastecimiento de la red")
@export var tasa_relleno_automatico: float = 2.0

var tanque_en_zona: TanqueCombustible = null

func _ready() -> void:
	# Conectamos las señales del Area3D por código para detectar el camión
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	# 1. Relleno automático de la gasolinera (se recupera lentamente)
	if reservas_actuales < capacidad_maxima_surtidor:
		reservas_actuales = min(capacidad_maxima_surtidor, reservas_actuales + (tasa_relleno_automatico * delta))

	# 2. Transferir gasolina al camión si está estacionado y pulsamos "ui_accept" (Enter/Espacio)
	if is_instance_valid(tanque_en_zona) and Input.is_action_pressed("ui_accept"):
		if reservas_actuales > 0.0 and tanque_en_zona.cantidad_actual < tanque_en_zona.capacidad_maxima:
			var litros_a_pasar = min(velocidad_surtido * delta, reservas_actuales)
			var espacio_disponible = tanque_en_zona.capacidad_maxima - tanque_en_zona.cantidad_actual
			
			litros_a_pasar = min(litros_a_pasar, espacio_disponible)
			reservas_actuales -= litros_a_pasar
			tanque_en_zona.cantidad_actual += litros_a_pasar

func _on_body_entered(body: Node3D) -> void:
	# Buscamos si el cuerpo que entró tiene un nodo "TanqueCombustible" adentro
	for hijo in body.get_children():
		if hijo is TanqueCombustible:
			tanque_en_zona = hijo
			print("Camión en zona de repostaje. Mantén presionado 'Aceptar' para llenar.")
			break

func _on_body_exited(body: Node3D) -> void:
	# Al salir limpiamos la referencia
	for hijo in body.get_children():
		if hijo == tanque_en_zona:
			tanque_en_zona = null
			break
