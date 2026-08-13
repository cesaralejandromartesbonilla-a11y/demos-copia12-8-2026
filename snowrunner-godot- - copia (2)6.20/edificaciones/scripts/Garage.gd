# Garage.gd
extends Node3D

@onready var spawn_point = $SpawnPoint
var vehiculo_actual: Node3D = null

func _ready():
	# Ocultamos la UI al empezar
	var ui = get_tree().get_first_node_in_group("ui_garaje") # Pon tu UI en este grupo
	if ui: ui.hide()
	
	# Conectamos las señales del Area3D
	$Area3D.body_entered.connect(_al_entrar)
	$Area3D.body_exited.connect(_al_salir)
	# Conectar señales de botones de una UI simple (opcional)
	# O simplemente usar teclas para probar
	pass

func _input(event):
	if event.is_action_pressed("press_g"): # Abrir menú o comprar por defecto
		intentar_cambiar_vehiculo("Camioneta_Base")

	if event.is_action_pressed("ui_accept"): # Al presionar Enter
		spawnear("Grua_Rescate")

func intentar_cambiar_vehiculo(id_vehiculo: String):
	# Verificamos si ya lo tenemos en el catálogo global
	if GestionGaraje.catalogo[id_vehiculo].comprado:
		spawnear(id_vehiculo)
	else:
		if GestionGaraje.comprar_vehiculo(id_vehiculo):
			spawnear(id_vehiculo)

func spawnear(id_vehiculo: String):
	# 1. Buscar y limpiar el vehículo viejo
	var viejo = get_tree().get_first_node_in_group("jugador")
	if viejo:
		viejo.name = "Viejo_Eliminar" # Evitar conflictos de nombre
		viejo.queue_free()
	
	# 2. Instanciar el nuevo vehículo
	var nueva_escena = GestionGaraje.catalogo[id_vehiculo].escena
	var instancia = nueva_escena.instantiate()
	
	# 3. Añadirlo al Mundo (Usamos call_deferred para mayor seguridad)
	get_tree().current_scene.call_deferred("add_child", instancia)
	
	# Esperar a que el nodo esté realmente en el árbol
	await get_tree().process_frame 
	
	# 4. Configuración Crítica de Posición y Escala
	# Forzamos escala 1,1,1 porque si el garaje está escalado, las ruedas NO funcionarán
	instancia.global_scale(Vector3.ONE)
	
	# Aparecemos un poco arriba (0.5m extra) para que las ruedas tengan aire y bajen
	instancia.global_transform = spawn_point.global_transform
	instancia.global_position += Vector3(0, 0.5, 0)
	
	instancia.add_to_group("jugador")
	
	# 5. RE-ACTIVACIÓN FORZADA DE RUEDAS
	if instancia is VehicleBody3D:
		instancia.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_AUTO
		instancia.sleeping = false
		
		# Este ciclo "despierta" cada rueda individualmente
		for child in instancia.get_children():
			if child is VehicleWheel3D:
				child.use_as_traction = child.use_as_traction # Truco para refrescar
				child.use_as_steering = child.use_as_steering
		
		print("Vehículo ", id_vehiculo, " inicializado correctamente.")

func _al_entrar(body):
	if body.is_in_group("jugador") or body is VehicleBody3D:
		var ui = get_tree().get_first_node_in_group("ui_garaje")
		if ui: ui.show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Liberamos el mouse para comprar

func _al_salir(body):
	if body.is_in_group("jugador") or body is VehicleBody3D:
		var ui = get_tree().get_first_node_in_group("ui_garaje")
		if ui: ui.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # Volvemos a conducir
