extends Area3D

@export var profundidad_barro: float = 0.5  # Qué tanto se puede hundir
@export var viscosidad: float = 15.0        # Resistencia al avance
@export var friccion_lodo: float = 0.8      # Qué tanto patinan las ruedas (bajo = más patinar)

func _ready():
	# Conectamos señales
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.has_method("entrar_en_barro"):
		body.entrar_en_barro(viscosidad, friccion_lodo, profundidad_barro)

func _on_body_exited(body):
	if body.has_method("salir_del_barro"):
		body.salir_del_barro()
