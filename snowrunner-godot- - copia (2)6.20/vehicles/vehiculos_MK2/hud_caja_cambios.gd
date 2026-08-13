extends CanvasLayer
class_name HudVehiculo

@export_group("Módulos Conectados")
@export var controlador_vehiculo: Node3D
@export var caja_cambios: CajaCambios
@export var motor: Motor
@export var radiador: Radiador
@export var tanque_gasolina: TanqueCombustible

@export_group("Testigos (Luces HUD)")
@export var luz_traccion: Control     # Luces para el panel (ColorRect o similar)
@export var luz_diferencial: Control
@export var luz_parking: Control
@export var luz_check_engine: Control

# Referencias a los nodos de la interfaz
@onready var lbl_marcha: Label = $VBoxContainer2/ContenedorMarchas/LblMarcha
@onready var btn_bajar: Button = $VBoxContainer2/ContenedorMarchas/BtnBajar
@onready var btn_subir: Button = $VBoxContainer2/ContenedorMarchas/BtnSubir
@onready var lbl_alerta: Label = $VBoxContainer2/LblAlerta

@onready var pb_motor: ProgressBar = $VBoxContainer2/ContenedorMotor/ProgressBar
@onready var pb_caja: ProgressBar = $VBoxContainer2/ContenedorMarchas/Pbcaja
@onready var pb_radiador: ProgressBar = $VBoxContainer2/ContenedorRadiador/pbRadiador
@onready var pb_combustible: ProgressBar = $VBoxContainer2/ContenedorCombustible/pbCombustible

func _ready() -> void:
	if btn_subir: btn_subir.pressed.connect(_on_btn_subir_pressed)
	if btn_bajar: btn_bajar.pressed.connect(_on_btn_bajar_pressed)
	if lbl_alerta: lbl_alerta.text = ""

func _process(_delta: float) -> void:
	# Es vital verificar que los nodos existen antes de cada actualización
	if is_instance_valid(caja_cambios): _actualizar_caja()
	if is_instance_valid(motor): _actualizar_motor()
	if is_instance_valid(radiador): _actualizar_radiador()
	if is_instance_valid(tanque_gasolina): _actualizar_combustible()
	_gestionar_alertas()
	_actualizar_testigos()

# --- FUNCIONES DE ACTUALIZACIÓN VISUAL ---
func _actualizar_caja() -> void:
	# 1. Nombre de la marcha (P, R, N, D...)
	lbl_marcha.text = caja_cambios.get_nombre_marcha()
	
	# 2. Color del texto: Si el embrague está caliente, se pone amarillo. Si se quema, rojo.
	if caja_cambios.embrague_quemado:
		lbl_marcha.modulate = Color(1, 0, 0) # Rojo puro
	elif caja_cambios.temperatura_embrague > (caja_cambios.temperatura_maxima * 0.7):
		lbl_marcha.modulate = Color(1, 0.5, 0) # Naranja/Amarillo (Aviso de calor)
	else:
		lbl_marcha.modulate = Color(1, 1, 1) # Blanco normal

	# 3. Temperatura del Aceite (Barra)
	if pb_caja:
		pb_caja.max_value = caja_cambios.temp_maxima_aceite
		pb_caja.value = caja_cambios.temp_aceite_caja
		
		# Feedback visual en la barra
		if caja_cambios.caja_recalentada:
			pb_caja.modulate = Color(1, 0, 0)
		else:
			pb_caja.modulate = Color(1, 1, 1)

func _actualizar_motor() -> void:
	if not pb_motor: return
	pb_motor.max_value = motor.temp_maxima_motor
	pb_motor.value = motor.temp_actual_motor
	pb_motor.modulate = Color(1, 0, 0) if motor.motor_recalentado else Color(1, 1, 1)

func _actualizar_radiador() -> void:
	if not pb_radiador: return
	pb_radiador.max_value = radiador.temp_maxima_refrigerante
	pb_radiador.value = radiador.temp_refrigerante
	
	# Efecto azul cuando el ventilador está trabajando
	pb_radiador.modulate = Color(0.3, 0.7, 1.0) if radiador.ventilador_encendido else Color(1, 1, 1)

func _actualizar_combustible() -> void:
	if not pb_combustible: return
	pb_combustible.max_value = tanque_gasolina.capacidad_maxima
	pb_combustible.value = tanque_gasolina.cantidad_actual
	
	# Alerta visual: Rojo si queda menos del 15% (Reserva)
	if tanque_gasolina.cantidad_actual < (tanque_gasolina.capacidad_maxima * 0.15):
		pb_combustible.modulate = Color(1, 0, 0) 
	else:
		pb_combustible.modulate = Color(1, 1, 1)

func _gestionar_alertas() -> void:
	if not lbl_alerta: return
	var alertas: Array[String] = []
	
	if caja_cambios.embrague_quemado: alertas.append("¡EMBRAGUE DESTRUIDO!")
	if caja_cambios.caja_recalentada: alertas.append("¡CAJA BLOQUEADA POR CALOR!")
	if motor.motor_recalentado: alertas.append("¡FALLO CRÍTICO DE MOTOR!")
	if radiador.temp_refrigerante > (radiador.temp_maxima_refrigerante * 0.9):
		alertas.append("¡SOBRECALENTAMIENTO!")
		
	# --- Alertas de combustible y motor ---
	if is_instance_valid(motor) and not motor.motor_encendido:
		alertas.append("MOTOR APAGADO")
		
	if is_instance_valid(tanque_gasolina):
		if tanque_gasolina.cantidad_actual <= 0.0:
			alertas.append("¡SIN COMBUSTIBLE!")
		elif tanque_gasolina.cantidad_actual < (tanque_gasolina.capacidad_maxima * 0.15):
			alertas.append("Nivel de combustible bajo")

	lbl_alerta.text = "\n".join(alertas)

# --- NUEVO FRAGMENTO: GESTIÓN DE TESTIGOS ---
func _actualizar_testigos() -> void:
	# 1. Testigos del chasis (Tracción y Diferencial)
	if is_instance_valid(controlador_vehiculo):
		if luz_traccion:
			luz_traccion.modulate = Color(0, 1, 0) if controlador_vehiculo.traccion_total_activada else Color(0.2, 0.2, 0.2)
		if luz_diferencial:
			luz_diferencial.modulate = Color(1, 0.5, 0) if controlador_vehiculo.diferencial_bloqueado else Color(0.2, 0.2, 0.2)
			
	# 2. Testigo de Freno de Mano / Parking
	if is_instance_valid(caja_cambios) and luz_parking:
		luz_parking.modulate = Color(1, 0, 0) if caja_cambios.en_parking else Color(0.2, 0.2, 0.2)
		
	# 3. Testigo Check Engine (Peligro térmico)
	if is_instance_valid(motor) and luz_check_engine:
		luz_check_engine.modulate = Color(1, 0, 0) if motor.temp_actual_motor > 100.0 else Color(0.2, 0.2, 0.2)

# --- BOTONES ---
func _on_btn_subir_pressed() -> void:
	if is_instance_valid(caja_cambios): caja_cambios.subir_marcha()

func _on_btn_bajar_pressed() -> void:
	if is_instance_valid(caja_cambios): caja_cambios.bajar_marcha()
