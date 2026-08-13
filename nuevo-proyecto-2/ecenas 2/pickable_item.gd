extends RigidBody3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D # Ajusta si tu mesh tiene otro nombre

func set_physics_state(active: bool):
	if active:
		freeze = false
		collision_layer = 1
	else:
		freeze = true
		collision_layer = 0

# --- NUEVA FUNCIÓN PARA EL RESALTADO ---
func set_highlight(active: bool):
	if active:
		# Hacemos el objeto un 15% más grande para que notes que lo estás apuntando
		mesh_instance.scale = Vector3(1.15, 1.15, 1.15) 
	else:
		# Vuelve a su tamaño normal
		mesh_instance.scale = Vector3(1.0, 1.0, 1.0)
