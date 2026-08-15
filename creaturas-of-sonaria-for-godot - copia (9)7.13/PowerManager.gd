extends Node
# ESTE ES EL AUTOLOAD (PowerManager)

var active_grids: Array[PowerGrid] = []

func _physics_process(_delta: float) -> void:
	for grid in active_grids:
		grid.update_logic()

func merge_grids(grid_a: PowerGrid, grid_b: PowerGrid) -> PowerGrid:
	if grid_a == grid_b: return grid_a
	
	grid_a.generators.append_array(grid_b.generators)
	grid_a.receivers.append_array(grid_b.receivers)
	grid_a.connectors.append_array(grid_b.connectors)
	
	for obj in grid_b.connectors:
		obj.my_grid = grid_a
		
	active_grids.erase(grid_b)
	return grid_a

func create_new_grid(creator) -> PowerGrid:
	var new_grid = PowerGrid.new() 
	new_grid.connectors.append(creator)
	
	# NUEVO: Registrar si el creador tiene un motor (receptor) o un generador desde que nace
	if "is_generator" in creator:
		if creator.is_generator and creator.generator_component:
			new_grid.generators.append(creator.generator_component)
		elif not creator.is_generator and creator.receiver_component:
			new_grid.receivers.append(creator.receiver_component)
			
	active_grids.append(new_grid)
	return new_grid

func rebuild_grid(old_grid: PowerGrid) -> void:
	# Si la red ya no está activa, no hacemos nada
	if not active_grids.has(old_grid): return
	
	# Borramos la red original de la existencia
	active_grids.erase(old_grid)
	
	# Filtramos solo los conectores/postes/máquinas que siguen vivos
	var surviving_nodes = []
	for node in old_grid.connectors:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			surviving_nodes.append(node)
			
	# PASO A: Reiniciar a todos los sobrevivientes a redes individuales
	for node in surviving_nodes:
		node.my_grid = create_new_grid(node)
		
		# Si el nodo es un enchufe de máquina, re-registramos sus componentes
		if "is_generator" in node:
			if node.is_generator and node.generator_component:
				node.my_grid.generators.append(node.generator_component)
			elif not node.is_generator and node.receiver_component:
				node.my_grid.receivers.append(node.receiver_component)

	# PASO B: Refusionar basados en los cables físicos que siguen conectados
	for node in surviving_nodes:
		for neighbor in node.connected_nodes:
			if is_instance_valid(neighbor) and not neighbor.is_queued_for_deletion():
				if neighbor.get("my_grid") and neighbor.my_grid != node.my_grid:
					node.my_grid = merge_grids(node.my_grid, neighbor.my_grid)
