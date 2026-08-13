# Excavador.gd (Poner en el Jugador o Cámara)
extends Camera3D

@export var terreno_path : NodePath
@onready var tierra_escena = $"../../../VoxelLodTerrain" # Aquí arrastras tu TierraFisica.tscn en el inspector
@onready var raycast = $RayCast3D # Asegúrate de tener un RayCast3D mirando al frente

func _input(event):
	if event.is_action_pressed("place"):
		if raycast.is_colliding():
			var pos_colision = raycast.get_collision_point()
			excavar(pos_colision)

func excavar(pos: Vector3):
	var terreno = get_node(terreno_path)
	# 1. Obtener la herramienta de edición de Zylann
	var vt = terreno.get_voxel_tool()
	
	# 2. Borrar un círculo de tierra (0 es el ID del aire)
	vt.do_sphere(pos, 1.5, 0) 
	
	# 3. APARECER LA TIERRA VISUAL (Igual que Gold Mining Simulator)
	var nueva_tierra = tierra_escena.instantiate()
	get_tree().root.add_child(nueva_tierra)
	nueva_tierra.global_position = pos
