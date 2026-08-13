extends Node
class_name PowerReceiverComponent

@export var required_kw: float = 15.0
@export var señales: bool = false
var is_machine_running: bool = false
var my_connector = null 

func try_consume_power(_delta: float) -> float:
	is_machine_running = true # Avisamos que necesitamos luz
	
	# 1. Verificamos si estamos conectados a nuestro propio enchufe
	if my_connector == null:
		var parent_name = get_parent().name if get_parent() else "Desconocido"
		if señales:
			print("⚠️ [" + parent_name + "] Error: my_connector es NULL. El enchufe no se ha vinculado a mí.")
		return 0.0
		
	# 2. Verificamos si nuestro enchufe pertenece a una red activa
	if not my_connector.get("my_grid") or my_connector.my_grid == null:
		var parent_name = get_parent().name if get_parent() else "Desconocido"
		if señales:
			print("⚠️ [" + parent_name + "] Error: Tengo enchufe, pero mi enchufe no tiene red (my_grid es NULL).")
		return 0.0
		
	# 3. Verificamos cuánta energía nos da la red
	var energia_recibida = my_connector.my_grid.satisfaction
	
	# Si la red no nos da el 100% de la energía, la máquina no arrancará
	if energia_recibida < 1.0:
		var parent_name = get_parent().name if get_parent() else "Desconocido"
		if señales:
			print("⚡ [" + parent_name + "] Alerta: La red solo me da " + str(energia_recibida * 100) + "% de la energía. Necesito 100%.")
		
	return energia_recibida

func turn_machine_on() -> void:
	is_machine_running = true

func turn_machine_off() -> void:
	is_machine_running = false
