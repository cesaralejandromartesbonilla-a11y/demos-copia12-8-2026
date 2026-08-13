extends Area3D

@export var velocidad_carga: float = 25.0 
var camioneta_en_zona = null

var timer_mensaje: SceneTreeTimer = null

func _ready():
	set_process(false)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("jugador") or body.has_method("repostar"):
		camioneta_en_zona = body
		set_process(true)

func _on_body_exited(body):
	if body == camioneta_en_zona:
		camioneta_en_zona = null
		set_process(false)

func _process(delta):
	if not is_instance_valid(camioneta_en_zona):
		set_process(false)
		return

	# Lógica de repostaje
	if not camioneta_en_zona.motor_encendido:
		if camioneta_en_zona.combustible_actual < camioneta_en_zona.combustible_max:
			camioneta_en_zona.repostar(velocidad_carga * delta)


func _limpiar_consola_despues(segundos: float):
	if timer_mensaje: return 
	timer_mensaje = get_tree().create_timer(segundos)
	await timer_mensaje.timeout

	timer_mensaje = null
