extends StaticBody3D

@onready var detector = $DetectorArea

func _ready():
	detector.body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# 1. Si el JUGADOR lo pisa en forma de piedra
	if "current_form" in body and body.current_form == body.Form.STONE:
		break_plank()
		
	# 2. Si un PROYECTIL de piedra impacta
	elif body.is_in_group("expelled_mass") and body.get_meta("element") == "STONE":
		break_plank()
		body.queue_free() # El pedazo de piedra se rompe al destruir la tabla

func break_plank():
	print("¡La tabla se ha roto por el peso o el impacto!")
	queue_free()
