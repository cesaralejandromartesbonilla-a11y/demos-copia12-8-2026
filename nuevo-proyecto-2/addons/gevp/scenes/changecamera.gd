extends Node

# Lista de rutas a las cámaras (asignadas en el inspector)
@export var camera_paths: Array[NodePath] = []

var cameras: Array[Camera3D] = []
var current_index: int = 0

func _ready():
	# Cargar las cámaras desde las rutas
	cameras.clear()
	for path in camera_paths:
		if not has_node(path):
			push_error("No se puede encontrar el nodo en la ruta: " + str(path))
			continue
		
		var node = get_node(path)
		if node is Camera3D:
			cameras.append(node)
		else:
			push_error("El nodo en la ruta '" + str(path) + "' no es una Camera3D.")

	if cameras.size() == 0:
		push_warning("No hay cámaras válidas asignadas.")
		return

	# Activar la primera cámara
	switch_to_camera(0)


func _input(event):
	if event.is_action_pressed("ui_right"):
		next_camera()
	elif event.is_action_pressed("ui_left"):
		prev_camera()


func next_camera():
	if cameras.size() <= 1:
		return
	current_index = wrapi(current_index + 1, 0, cameras.size())
	switch_to_camera(current_index)


func prev_camera():
	if cameras.size() <= 1:
		return
	current_index = wrapi(current_index - 1, 0, cameras.size())
	switch_to_camera(current_index)


func switch_to_camera(index: int):
	# Desactivar todas las cámaras (solo una debe ser 'current')
	for cam in cameras:
		cam.current = false

	# Activar la seleccionada
	cameras[index].current = true
	current_index = index
	print("Cámara activa: ", cameras[index].get_path())
