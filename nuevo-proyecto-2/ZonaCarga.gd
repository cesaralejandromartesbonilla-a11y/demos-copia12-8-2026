extends Area3D

@export var tierra_escena : PackedScene # Arrastra TierraFisica.tscn aquí en el Inspector
var carga_actual : float = 0.0
@export var capacidad_max : float = 100.0
@onready var visual_tierra = $"../visual" # Revisa que el nodo visual se llame EXACTAMENTE "visual"
@onready var punto_descarga = $"../PuntoDescarga" # Revisa que el nodo se llame EXACTAMENTE "PuntoDescarga"

func _ready():
	# Conecta la señal body_entered desde el editor o aquí.
	body_entered.connect(_on_piedra_recibida)

func _on_piedra_recibida(body):
	# Usa grupos para asegurarte de que solo recoges la "tierra_suelta"
	if body.is_in_group("tierra_suelta"):
		if carga_actual < capacidad_max:
			carga_actual += 1.0
			actualizar_visual()
			body.queue_free() # Elimina la piedra física y la suma a la carga

func actualizar_visual():
	# Mueve la malla de tierra hacia arriba según la carga. 
	# La escala debe ser 1.0 como máximo.
	var porcentaje = carga_actual / capacidad_max
	# Usamos un rango de altura realista para la posición Y del visual_tierra
	visual_tierra.position.y = lerp(-0.5, 0.5, porcentaje) 
	# Opcional: escalar visual_tierra.scale.y para que "crezca"
	# visual_tierra.scale.y = lerp(0.1, 1.0, porcentaje)

# Esta función la llamará _input
func descargar():
	if carga_actual > 0:
		# Instanciar la piedra física en la posición del nodo PuntoDescarga
		var piedra = tierra_escena.instantiate()
		get_tree().root.add_child(piedra)
		piedra.global_position = punto_descarga.global_position
		
		# Opcional: Aplicar un impulso para que caiga del camión
		if piedra is RigidBody3D:
			piedra.apply_central_impulse(Vector3(0, 1, -2))
			
		carga_actual -= 1.0
		actualizar_visual()

# El _input debe ir en el script del camión (VehicleBody3D), no en el Area3D de la carga.
# Si lo dejas aquí, funcionará pero el input del jugador principal puede interferir.
func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("press_g"):
		descargar()
		print("descargando")
