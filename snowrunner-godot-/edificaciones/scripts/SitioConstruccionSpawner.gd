extends Node3D

# --- CONFIGURACIÓN ---
# Aquí arrastras tu archivo .tscn desde el sistema de archivos al Inspector
@export var escena_edificio: PackedScene 

# Referencias visuales (conos, vallas, holograma) que se borrarán al construir
@export var marcadores_zona: Node3D 

@onready var area_detector: Area3D = $Area3D
var ya_construido: bool = false

func _ready():
	if not area_detector:
		print("ERROR: Falta el Area3D en el sitio de construcción")
	else:
		area_detector.body_entered.connect(_procesar_entrega)

func _procesar_entrega(body):
	if ya_construido:
		return

	# Verificamos si es la camioneta y si trae carga
	if body.has_method("entregar_carga"):
		var exito = body.entregar_carga()
		
		if exito:
			spawnear_edificio()
		else:
			print("El camión llegó pero está vacío.")

func spawnear_edificio():
	if escena_edificio == null:
		print("ERROR: No has asignado el .tscn en el Inspector")
		return

	print("Construyendo edificio...")
	ya_construido = true
	
	# 1. Crear la instancia (traerla del limbo a la memoria)
	var nuevo_edificio = escena_edificio.instantiate()
	
	# 2. Añadirlo a la escena (hacerlo visible en el juego)
	add_child(nuevo_edificio)
	
	# 3. Ajustar posición (opcional, por defecto sale en (0,0,0) de este nodo)
	nuevo_edificio.position = Vector3.ZERO 
	nuevo_edificio.rotation = Vector3.ZERO
	
	# 4. Eliminar los marcadores de "zona de obras" (conos, vallas)
	if marcadores_zona:
		marcadores_zona.queue_free()
		
	# 5. Efecto extra: Sonido o partículas (Opcional)
	# $SonidoConstruccion.play()
