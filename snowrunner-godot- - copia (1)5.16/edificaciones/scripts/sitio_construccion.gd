extends Node3D

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var area_detector: Area3D = $Area3D

var construccion_finalizada: bool = false

func _ready():
	# Truco: Ocultar o aplastar el edificio al iniciar el juego
	var edificio = $Edificio # Asegúrate que la ruta sea correcta
	if edificio:
		edificio.scale = Vector3(0.1, 0.1, 0.1) # Lo hacemos pequeñito al empezar
	# Verificación inicial: ¿Existe el AnimationPlayer?
	if not anim_player:
		print("ERROR GRAVE: No encuentro el nodo 'AnimationPlayer'. Revisa el nombre o la jerarquía.")
	else:
		print("SitioConstruccion: AnimationPlayer conectado correctamente.")
		# Listar animaciones disponibles para ver si escribimos bien el nombre
		var lista = anim_player.get_animation_list()
		print("Animaciones disponibles: ", lista)

	if area_detector:
		area_detector.body_entered.connect(_procesar_entrega)
	else:
		print("ERROR: Falta el nodo Area3D.")

func _procesar_entrega(body):
	if construccion_finalizada:
		return

	# Solo interactuamos si tiene el método de entrega
	if body.has_method("entregar_carga"):
		print("Vehículo detectado en Zona B. Intentando descargar...")
		
		var exito = body.entregar_carga()
		print("Resultado de entregar_carga(): ", exito)
		
		if exito:
			construir_edificio()
		else:
			print("El vehículo vino, pero NO traía carga (tiene_carga era false).")

func construir_edificio():
	print("--- INICIANDO CONSTRUCCIÓN ---")
	construccion_finalizada = true
	
	if not anim_player:
		print("ERROR: No puedo animar, el AnimationPlayer es nulo.")
		return

	# Nombre EXACTO de la animación (Cuidado con mayúsculas/minúsculas)
	var nombre_animacion = "construir" 
	
	if anim_player.has_animation(nombre_animacion):
		anim_player.play(nombre_animacion)
		print("¡Reproduciendo animación: ", nombre_animacion, "!")
	else:
		print("ERROR: El AnimationPlayer NO tiene una animación llamada '", nombre_animacion, "'.")
		print("Nombres disponibles: ", anim_player.get_animation_list())
