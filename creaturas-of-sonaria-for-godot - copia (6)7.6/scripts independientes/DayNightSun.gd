extends DirectionalLight3D

func _ready() -> void:
	# Nos conectamos a la señal global del tiempo
	WeatherManager.time_changed.connect(_on_time_changed)

func _on_time_changed(time_of_day: float) -> void:
	# Convertimos la hora (0 a 24) a grados de rotación
	# A las 6:00 AM el sol sale (X = 0 grados)
	# A las 12:00 PM es mediodía (X = -90 grados, apuntando hacia abajo)
	# A las 18:00 PM el sol se oculta (X = -180 grados)
	
	var time_ratio = time_of_day / 24.0
	var angle_radians = (time_ratio * TAU) - (PI / 2.0)
	
	rotation.x = -angle_radians
