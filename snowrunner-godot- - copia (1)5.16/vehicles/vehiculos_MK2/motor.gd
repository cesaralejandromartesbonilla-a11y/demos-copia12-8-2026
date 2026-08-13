extends Node
class_name Motor

@export var radiador: Radiador

@export_group("Especificaciones")
@export var fuerza_base_motor: float = 3000.0
@export var temp_ambiente: float = 25.0
@export var temp_maxima_motor: float = 115.0

@export_group("Curva de Potencia")
@export var velocidad_max_volante: float = 80.0 
@export var curva_potencia: Curve 
@export var vel_ralenti_volante: float = 10.0

@export_group("Termodinámica")
@export var tasa_calentamiento: float = 12.0
@export var conductividad_termica: float = 2.5 

var temp_actual_motor: float = 25.0
var motor_recalentado: bool = false

func _ready() -> void:
	temp_actual_motor = temp_ambiente




func procesar_motor(input_acelerador: float, vel_volante: float, delta: float) -> float:
	if motor_recalentado:
		return 0.0 
		
	# --- NUEVO: LÓGICA DE RALENTÍ ---
	# Mantenemos un "acelerador interno" activo para que el motor no muera
	var acelerador_efectivo = input_acelerador
	if vel_volante < vel_ralenti_volante:
		# Si las RPM bajan del mínimo, la computadora inyecta aceleración (15%) automáticamente
		acelerador_efectivo = max(input_acelerador, 0.15)

	# 1. Generación de calor (ahora usa el acelerador efectivo)
	if acelerador_efectivo > 0.0:
		temp_actual_motor += acelerador_efectivo * tasa_calentamiento * delta
		
	# 2. Intercambio de calor (REFRIGERACIÓN CORREGIDA)
	if is_instance_valid(radiador):
		temp_actual_motor = radiador.intercambiar_calor(temp_actual_motor, conductividad_termica, delta)
	else:
		if temp_actual_motor > temp_ambiente:
			# Disipación térmica dinámica: se enfría más rápido mientras más caliente está
			var exceso_calor = temp_actual_motor - temp_ambiente
			temp_actual_motor -= (exceso_calor * 0.15) * delta

	# 3. Verificar daños por recalentamiento
	if temp_actual_motor >= temp_maxima_motor:
		temp_actual_motor = temp_maxima_motor
		motor_recalentado = true
		print("¡MOTOR FUNDIDO / RECALENTADO!")
		
	var eficiencia = 1.0
	if temp_actual_motor > 100.0:
		eficiencia = 1.0 - ((temp_actual_motor - 100.0) / (temp_maxima_motor - 100.0) * 0.5)
		
	var multiplicador_curva: float = 1.0
	var rpm_normalizada = clamp(vel_volante / velocidad_max_volante, 0.0, 1.0)
	
	if is_instance_valid(curva_potencia):
		multiplicador_curva = curva_potencia.sample(rpm_normalizada)
	else:
		multiplicador_curva = max(0.2, sin(rpm_normalizada * PI))
		
	return fuerza_base_motor * acelerador_efectivo * eficiencia * multiplicador_curva
