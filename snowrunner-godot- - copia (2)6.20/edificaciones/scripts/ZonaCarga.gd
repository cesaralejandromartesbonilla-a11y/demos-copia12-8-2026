extends Area3D

func _ready():
	# Conectamos la señal de que algo entró en el área
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Verificamos si es la camioneta (puedes verificar por nombre o grupo)
	if body.name == "Camioneta" or body is VehicleBody3D:
		if body.has_method("recibir_carga"):
			if not body.tiene_carga:
				body.recibir_carga()
				# Opcional: Reproducir sonido de carga o desaparecer un pallet visual
				print("Zona A: Materiales cargados en el vehículo.")
