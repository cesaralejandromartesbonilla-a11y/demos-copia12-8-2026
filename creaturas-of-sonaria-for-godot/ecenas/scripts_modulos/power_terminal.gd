extends Node
class_name PowerTerminal

@export var my_connector: MachineConnector # Arrastra aquí el enchufe de la máquina
@export var screen_text: Label3D # Arrastra aquí el Label3D que hará de pantalla

func _process(_delta: float) -> void:
	if my_connector == null or screen_text == null:
		return
		
	var grid = my_connector.my_grid
	if grid == null:
		screen_text.text = "ESTADO: DESCONECTADO"
		return
		
	var total_production = 0.0
	var total_demand = 0.0
	var active_generators = 0
	var active_receivers = 0
	
	# 1. Calcular Producción REAL (solo lo que se está generando ahora mismo)
	for gen in grid.generators:
		var current_gen = gen.get_current_generation()
		total_production += current_gen
		if current_gen > 0:
			active_generators += 1
			
	# 2. Calcular Demanda REAL (solo las máquinas que están operando)
	for rec in grid.receivers:
		if rec.is_machine_running:
			total_demand += rec.required_kw
			active_receivers += 1
			
	# 3. Contar Equipos Totales y Postes
	var generators_count = grid.generators.size()
	var receivers_count = grid.receivers.size()
	var total_equipment = generators_count + receivers_count
	
	var pole_count = 0
	for node in grid.connectors:
		if node is PowerPole:
			pole_count += 1
			
	# 4. Generar el Texto para la Pantalla
	var text = "=== CENTRAL DE MONITOREO ===\n"
	text += "ID Red Local: #" + str(grid.get_instance_id()) + "\n"
	# Usamos snapped para redondear el porcentaje a 1 decimal
	text += "Estado de Energía: " + str(snapped(grid.satisfaction * 100, 0.1)) + "%\n"
	text += "--------------------------\n"
	text += "Producción Actual: " + str(total_production) + " kW\n"
	text += "Demanda Actual: " + str(total_demand) + " kW\n"
	text += "--------------------------\n"
	text += "Equipos Totales: " + str(total_equipment) + "\n"
	text += "[+] Productores: " + str(active_generators) + "/" + str(generators_count) + " Activos\n"
	text += "[-] Consumidores: " + str(active_receivers) + "/" + str(receivers_count) + " Activos\n"
	text += "[|] Postes Activos: " + str(pole_count)
	
	screen_text.text = text
