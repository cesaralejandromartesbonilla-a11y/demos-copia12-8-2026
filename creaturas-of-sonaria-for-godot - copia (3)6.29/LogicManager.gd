extends Node
# ESTE ES EL AUTOLOAD (LogicManager)

var active_grids: Array[LogicGrid] = []

func merge_grids(grid_a: LogicGrid, grid_b: LogicGrid) -> LogicGrid:
	if grid_a == grid_b: return grid_a
	
	grid_a.transmitters.append_array(grid_b.transmitters)
	grid_a.receivers.append_array(grid_b.receivers)
	grid_a.connectors.append_array(grid_b.connectors)
	
	for obj in grid_b.connectors:
		obj.my_logic_grid = grid_a
		
	active_grids.erase(grid_b)
	return grid_a

func create_new_grid(creator) -> LogicGrid:
	var new_grid = LogicGrid.new() 
	new_grid.connectors.append(creator)
	
	# Registrar si el creador es una Central (Transmisor) o una Máquina (Receptor)
	if "is_logic_transmitter" in creator:
		if creator.is_logic_transmitter and creator.logic_transmitter_component:
			new_grid.transmitters.append(creator.logic_transmitter_component)
		elif not creator.is_logic_transmitter and creator.logic_receiver_component:
			new_grid.receivers.append(creator.logic_receiver_component)
			
	active_grids.append(new_grid)
	return new_grid

func rebuild_grid(old_grid: LogicGrid) -> void:
	# Si la red ya no está activa, la ignoramos
	if not active_grids.has(old_grid): return
	
	# Borramos la red original para recalcular todo
	active_grids.erase(old_grid)
	
	# Filtramos solo los cables/postes lógicos que siguen vivos
	var surviving_nodes = []
	for node in old_grid.connectors:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			surviving_nodes.append(node)
			
	# PASO A: Reiniciar a todos los sobrevivientes a redes individuales
	for node in surviving_nodes:
		node.my_logic_grid = create_new_grid(node)
		
		# Re-registramos las Centrales y Máquinas en sus nuevas redes aisladas
		if "is_logic_transmitter" in node:
			if node.is_logic_transmitter and node.logic_transmitter_component:
				node.my_logic_grid.transmitters.append(node.logic_transmitter_component)
			elif not node.is_logic_transmitter and node.logic_receiver_component:
				node.my_logic_grid.receivers.append(node.logic_receiver_component)

	# PASO B: Refusionar basados en los cables lógicos que siguen conectados
	for node in surviving_nodes:
		# IMPORTANTE: Usamos 'connected_logic_nodes' para no mezclar con los cables eléctricos
		if "connected_logic_nodes" in node:
			for neighbor in node.connected_logic_nodes:
				if is_instance_valid(neighbor) and not neighbor.is_queued_for_deletion():
					if neighbor.get("my_logic_grid") and neighbor.my_logic_grid != node.my_logic_grid:
						node.my_logic_grid = merge_grids(node.my_logic_grid, neighbor.my_logic_grid)
