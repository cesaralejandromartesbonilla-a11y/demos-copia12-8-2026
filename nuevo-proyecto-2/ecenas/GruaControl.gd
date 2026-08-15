#grua de construccion.gd
extends "res://addons/gevp/scenes/vehicle_base.gd"

@onready var torre = $TorreGiratoria
@onready var carrito = $TorreGiratoria/Pluma/Carrito
@onready var gancho = $TorreGiratoria/Pluma/Carrito/Cable/Gancho
@onready var cable_mesh = $TorreGiratoria/Pluma/Carrito/Cable


@export var velocidad_giro := 1.0
@export var velocidad_carrito := 5.0
@export var velocidad_cable := 3.0

var objeto_sujetado: RigidBody3D = null

@export var activo: bool = false
@onready var asiento = $MountPoint_Player




func _input(event):
	# Intentar subir a la grúa
	if event.is_action_pressed("press_e"):
		if not activo:
			_intentar_subir()
		else:
			_bajar_de_grua()

func _intentar_subir():
	var cuerpos = $ZonaAcceso.get_overlapping_bodies()
	for cuerpo in cuerpos:
		if cuerpo.is_in_group("player"):
			cuerpo._enter_vehicle(self)
			activo = true
			
			# ACTIVAR GANCHO AQUÍ 🛠️
			var hook_ctrl = cuerpo.get_node_or_null("HookController")
			if hook_ctrl:
				hook_ctrl.is_enabled = true
				hook_ctrl.hook_source = gancho # El nodo del gancho que ya definiste arriba
			
			print("Operando grúa: Gancho disponible")

func _bajar_de_grua():
	var player = %Player
	if player:
		# DESACTIVAR GANCHO AQUÍ 🛠️
		var hook_ctrl = player.get_node_or_null("HookController")
		if hook_ctrl:
			hook_ctrl.is_enabled = false
			hook_ctrl.hook_source = null
			
		player.on_player_unmounted()
		activo = false




func _physics_process(delta: float):
	# 🔑 Solo este vehículo responde si está montado
	if !activo:
		return

	# 1. Girar la torre (Teclas Q / E)
	var input_giro = Input.get_axis("press_a", "press_d")
	torre.rotate_y(-input_giro * velocidad_giro * delta)

# Dentro de _physics_process:
	var distancia = abs(gancho.position.y)
	cable_mesh.height = distancia + 2
	cable_mesh.position.y = -distancia / 2

	# 2. Mover carrito en la pluma (Teclas W / S)
	var input_carrito = Input.get_axis("press_s", "press_w")
	carrito.position.z = clamp(carrito.position.z + (input_carrito * velocidad_carrito * delta), 0.0, 0.65)

	# 3. Subir/Bajar gancho (Teclas F / R)
	var input_cable = Input.get_axis("press_f", "press_r")
	gancho.position.y = clamp(gancho.position.y + (input_cable * velocidad_cable * delta), -50.0, -1.0)

	# 4. Soltar objeto
	if Input.is_action_just_pressed("press_g"):
		if objeto_sujetado != null:
			soltar_objeto()
		else:
			# SEGURIDAD: Si la variable se volvió null pero el objeto sigue pegado
			for hijo in gancho.get_children():
				if hijo.has_method("desacoplar_de_vehiculo"):
					hijo.desacoplar_de_vehiculo()

func _ready():
	gancho.body_entered.connect(_on_gancho_body_entered)

# Asegúrate de que el Area3D del gancho use esta función
func _on_gancho_body_entered(body: Node3D):
	# Si ya llevamos algo, no agarramos más
	if objeto_sujetado != null:
		return
		
	if body.has_method("acoplar_a_vehiculo") and body.puede_acoplarse:
		# IMPORTANTE: Asignar la variable ANTES de llamar a la función
		objeto_sujetado = body 
		objeto_sujetado.acoplar_a_vehiculo(gancho, marcador_gancho)
		print("Grúa: Objeto capturado")

func soltar_objeto():
	if is_instance_valid(objeto_sujetado):
		objeto_sujetado.desacoplar_de_vehiculo()
		objeto_sujetado = null # Limpiar referencia
		print("Grúa: Objeto liberado")
	else:
		# Si por algún motivo la variable es null pero hay algo pegado, 
		# forzamos la liberación de cualquier hijo del gancho
		for hijo in gancho.get_children():
			if hijo.has_method("desacoplar_de_vehiculo"):
				hijo.desacoplar_de_vehiculo()
		objeto_sujetado = null

# En GruaControl.gd
@onready var marcador_gancho = $TorreGiratoria/Pluma/Carrito/Cable/Gancho/Marker3D # Asegúrate de que esta ruta sea correcta

func sujetar_objeto(obj: RigidBody3D):
	if marcador_gancho == null:
		print("ERROR: El marcador del gancho no fue encontrado. Revisa la ruta en el script.")
		return
		
	objeto_sujetado = obj
	# Pasamos el NODO del marcador
	objeto_sujetado.acoplar_a_vehiculo(gancho, marcador_gancho)

func _on_area_3d_body_entered(body: Node3D) -> void:
	# Verificamos si el cuerpo que entró es el jugador usando su clase
	if body is Player: 
		# Buscamos el nodo HookController dentro de la instancia del jugador
		var hook_ctrl = body.get_node("HookController")
		
		if hook_ctrl:
			hook_ctrl.is_enabled = true
			# Cambiamos el origen del cable a la punta del gancho de la grúa
			hook_ctrl.hook_source = $TorreGiratoria/Pluma/Carrito/Cable/Gancho/PuntoAcopleCamion
			print("Sistemas de cabrestante de grúa: ACTIVADOS")

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body is Player:
		var hook_ctrl = body.get_node("HookController")
		
		if hook_ctrl:
			# Si el gancho estaba disparado, lo obligamos a retraerse al salir
			hook_ctrl.is_enabled = false 
			# Devolvemos el origen del cable al jugador (opcional)
			hook_ctrl.hook_source = null 
			print("Sistemas de cabrestante de grúa: DESACTIVADOS")
