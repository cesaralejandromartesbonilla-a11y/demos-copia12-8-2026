extends StaticBody3D

@onready var detector = $DetectorArea

func _ready():
	detector.body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# 1. Si el JUGADOR lo pisa siendo de PIEDRA
	if "current_element" in body and body.current_element == "STONE":
		break_plank()
		
	# 2. Si un PROYECTIL de piedra impacta
	elif body.is_in_group("expelled_mass") and "element_to_grant" in body and body.element_to_grant == "STONE":
		break_plank()
		body.queue_free() # El pedazo de piedra se rompe al destruir la tabla

func break_plank():
	print("¡La tabla se ha roto por el peso o el impacto!")
	queue_free()
