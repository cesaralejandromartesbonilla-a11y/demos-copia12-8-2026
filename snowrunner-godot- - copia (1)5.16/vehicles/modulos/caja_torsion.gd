extends Node3D

@export_group("Conexiones")
@export var chasis: VehicleBody3D
@export var rueda_trasera_izq: VehicleWheel3D
@export var rueda_trasera_der: VehicleWheel3D

@export_group("Ajustes de Chasis")
@export var multiplicador_torsion: float = 1.0 # 1.0 = normal. > 1.0 = efecto exagerado
@export var suavizado: float = 6.0             # Velocidad a la que el metal cede y vuelve
@export var limite_torsion_grados: float = 20.0 # Cuánto puede doblarse antes de romperse

var rotacion_base_z: float

func _ready() -> void:
	# Guardamos la rotación original (Roll) por si la caja ya viene con una pequeña inclinación
	rotacion_base_z = rotation.z

func _physics_process(delta: float) -> void:
	# Sistema de alerta para que no falle en silencio
	if not chasis or not rueda_trasera_izq or not rueda_trasera_der:
		print("¡ALERTA TORSION!: Faltan asignar nodos en el inspector de la Caja.")
		return

	var angulo_objetivo_z = rotacion_base_z

	# Solo aplicamos torsión si ambas ruedas traseras están tocando terreno
	# Si el camión está saltando en el aire, el chasis debe volver a su forma recta
	if rueda_trasera_izq.is_in_contact() and rueda_trasera_der.is_in_contact():
		
		# 1. Obtener la coordenada global (mundo real) donde la goma toca el piso
		var contacto_izq = rueda_trasera_izq.get_contact_point()
		var contacto_der = rueda_trasera_der.get_contact_point()
		
		# 2. Convertir esas coordenadas al espacio "local" del camión.
		# Esto elimina la inclinación de la colina y nos dice puramente 
		# qué tan adentro del guardabarros está empujada la rueda.
		var local_izq = chasis.to_local(contacto_izq)
		var local_der = chasis.to_local(contacto_der)
		
		# 3. Calcular la diferencia de altura y el ancho del eje
		var diferencia_altura = local_izq.y - local_der.y
		var distancia_ancho = abs(rueda_trasera_izq.position.x - rueda_trasera_der.position.x)
		
		if distancia_ancho > 0.01: # Evita errores si las ruedas están en la misma posición X
			# 4. Magia Trigonométrica (atan2) para sacar el ángulo exacto del eje en radianes
			# Si el camión gira hacia el lado incorrecto, invierte el signo de diferencia_altura (-diferencia_altura)
			var angulo_eje = atan2(diferencia_altura, distancia_ancho)
			
			angulo_objetivo_z = rotacion_base_z + (angulo_eje * multiplicador_torsion)
			
			# Limitamos la torsión para que el metal no atraviese la cabina
			var limite_rad = deg_to_rad(limite_torsion_grados)
			angulo_objetivo_z = clamp(angulo_objetivo_z, rotacion_base_z - limite_rad, rotacion_base_z + limite_rad)

	# 5. Aplicar la rotación con suavizado (simula el peso y resistencia del acero)
	rotation.z = lerp(rotation.z, angulo_objetivo_z, suavizado * delta)
