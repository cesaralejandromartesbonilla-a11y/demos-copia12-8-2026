extends Node3D

@export_group("Configuración de Dirección")
@export var grados_maximos: float = 30.0
@export var velocidad_volante: float = 5.0

@export_group("Retorno Automático")
@export var auto_centrar: bool = true
@export var velocidad_retorno: float = 8.0 

@export_group("Modos de Dirección Permitidos")
@export var permitir_modo_normal: bool = true
@export var permitir_modo_opuesta: bool = true
@export var permitir_modo_cangrejo: bool = true
@export var permitir_modo_eje: bool = true
enum ModoDireccion { NORMAL, OPUESTA, CANGREJO, EJE }
var modo_direccion_actual: ModoDireccion = ModoDireccion.NORMAL

@export_group("modulos")
@export var radiador: Radiador
@export var caja_cambios: CajaCambios
@export var motor: Motor
@export var volante_inercia: HingeJoint3D

@export_group("Configuración ruedas direccionales")
@export var fuerza_direccion: float = 1500.0 
@export var direccion_principal: Array[HingeJoint3D] = []
@export var direccion_secundaria: Array[HingeJoint3D] = []

@export_group("Configuración ruedas motrices")
@export var fuerza_frenado: float = 3000.0
@export var multiplicador_diferencial: float = 3.0
@export var traccion_principal: Array[HingeJoint3D] = []
@export var traccion_secundaria: Array[HingeJoint3D] = []

var traccion_total_activada: bool = false 
var diferencial_bloqueado: bool = false
var posicion_anterior: Vector3 = Vector3.ZERO
var velocidad_real_camion: float = 0.0

func _set_motor_active(joint: HingeJoint3D, active: bool) -> void:
	joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, active)
	if not active:
		joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, 0.0)

func _ready() -> void:
	var limite_radianes = deg_to_rad(grados_maximos)
	var todas_direccion = direccion_principal + direccion_secundaria
	for joint in todas_direccion:
		if is_instance_valid(joint):
			joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
			joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, -limite_radianes)
			joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, limite_radianes)
			joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)

	# Aseguramos que todas las ruedas de tracción inicien libres
	var todas_traccion = traccion_principal + traccion_secundaria
	for joint in todas_traccion:
		if is_instance_valid(joint):
			_set_motor_active(joint, false)

func _physics_process(delta: float) -> void:
	var volante = Input.get_axis("press_a", "press_d") 
	var acelerador = Input.get_action_strength("press_w")
	var freno = Input.is_action_pressed("press_space") or Input.is_action_pressed("press_s")
	
	# Input para alternar la tracción 
	if Input.is_action_just_pressed("press_tab"):
		traccion_total_activada = !traccion_total_activada
		print("Tracción Total: ", "ACTIVADA" if traccion_total_activada else "DESACTIVADA")
	
	# Input para alternar el Bloqueo de Diferencial
	if Input.is_action_just_pressed("press_q"):
		diferencial_bloqueado = !diferencial_bloqueado
		print("Diferencial: ", "BLOQUEADO" if diferencial_bloqueado else "ABIERTO")
	
	# Input para ciclar entre los modos de dirección permitidos
	if Input.is_action_just_pressed("press_esc"):
		# Máximo 4 intentos para encontrar el siguiente modo habilitado
		for i in range(4):
			modo_direccion_actual = (modo_direccion_actual + 1) % 4 as ModoDireccion
			
			if modo_direccion_actual == ModoDireccion.NORMAL and permitir_modo_normal:
				print("Dirección: NORMAL (Solo delantera)")
				break
			elif modo_direccion_actual == ModoDireccion.OPUESTA and permitir_modo_opuesta:
				print("Dirección: OPUESTA (Curvas cerradas)")
				break
			elif modo_direccion_actual == ModoDireccion.CANGREJO and permitir_modo_cangrejo:
				print("Dirección: CANGREJO (Marcha diagonal)")
				break
			elif modo_direccion_actual == ModoDireccion.EJE and permitir_modo_eje:
				print("Dirección: EJE (Giro sobre sí mismo)")
				break
	# --- INPUTS DE CAJA DE CAMBIOS ---
	if caja_cambios:
		if Input.is_action_just_pressed("press_e"): # Tecla para subir marcha
			caja_cambios.subir_marcha()
		if Input.is_action_just_pressed("press_r"): # Tecla para bajar marcha (Cambia "press_x" por tu tecla)
			caja_cambios.bajar_marcha()
			
	# --- LÓGICA DE DIRECCIÓN ---
	var todas_direccion = direccion_principal + direccion_secundaria
	
	for joint in todas_direccion:
		if not is_instance_valid(joint): continue
		
		var velocidad_actual = 0.0
		var es_secundaria = direccion_secundaria.has(joint)
		
		# Si es secundaria y estamos en modo NORMAL, la forzamos a auto-centrarse
		if es_secundaria and modo_direccion_actual == ModoDireccion.NORMAL:
			if auto_centrar:
				var mangueta = joint.get_node_or_null(joint.node_b) as Node3D
				var brazo = joint.get_node_or_null(joint.node_a) as Node3D
				if mangueta and brazo:
					var transform_local = brazo.global_transform.affine_inverse() * mangueta.global_transform
					var angulo_actual = transform_local.basis.get_euler().y 
					if abs(angulo_actual) > 0.01:
						velocidad_actual = angulo_actual * velocidad_retorno 
		
		# Si es principal, o si es secundaria en un modo activo (OPUESTA o CANGREJO):
		else:
			var multiplicador_giro = 1.0
			
			# Nuevo Modo EJE (Tank Turn)
			if modo_direccion_actual == ModoDireccion.EJE:
				# to_local convierte la posición de la rueda a coordenadas relativas del camión.
				# Asumimos que el eje X es izquierda/derecha. sign() devuelve 1 (derecha) o -1 (izquierda).
				var pos_local = to_local(joint.global_position)
				var lado = sign(pos_local.x) 
				
				if es_secundaria:
					multiplicador_giro = lado * -1.0 # Traseras hacia el interior
				else:
					multiplicador_giro = lado * 1.0  # Delanteras hacia el exterior
					
			elif es_secundaria:
				if modo_direccion_actual == ModoDireccion.OPUESTA:
					multiplicador_giro = -1.0 # Gira al revés para curvas cerradas
				elif modo_direccion_actual == ModoDireccion.CANGREJO:
					multiplicador_giro = 1.0  # Gira igual para caminar en diagonal
			
			if abs(volante) > 0.05:
				velocidad_actual = velocidad_volante * (volante * multiplicador_giro)
			else:
				if auto_centrar:
					var mangueta = joint.get_node_or_null(joint.node_b) as Node3D
					var brazo = joint.get_node_or_null(joint.node_a) as Node3D
					if mangueta and brazo:
						var transform_local = brazo.global_transform.affine_inverse() * mangueta.global_transform
						var angulo_actual = transform_local.basis.get_euler().y 
						if abs(angulo_actual) > 0.01:
							velocidad_actual = angulo_actual * velocidad_retorno 
		
		joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, velocidad_actual)
		joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, fuerza_direccion)
	
	velocidad_real_camion = (global_position - posicion_anterior).length() / delta
	posicion_anterior = global_position
	
	# --- CÁLCULO DE VELOCIDAD Y AIRE ---
	velocidad_real_camion = (global_position - posicion_anterior).length() / delta
	posicion_anterior = global_position
	
	# Informamos al radiador del viento para enfriamiento pasivo
	if is_instance_valid(radiador):
		radiador.procesar_flujo_aire(velocidad_real_camion, delta)

	# --- CADENA DE POTENCIA Y VOLANTE DE INERCIA ---
	
	var inclinacion = global_transform.basis.y.dot(Vector3.UP)
	var motor_ahogado = inclinacion < 0.2 
	
	# --- PASO 1: Calcular la rotación del volante primero ---
	var vel_giro_volante: float = 0.0
	if is_instance_valid(volante_inercia):
		var vel_esperada = 0.0
		if is_instance_valid(caja_cambios):
			vel_esperada = caja_cambios.get_velocidad_objetivo()
			
		# ---  El volante siempre intenta mantener al menos el ralentí ---
		var vel_ralenti = motor.vel_ralenti_volante if is_instance_valid(motor) else 10.0
		var target_rpm = max(vel_ralenti, abs(vel_esperada) * acelerador) if not motor_ahogado else 0.0
		
		volante_inercia.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
		volante_inercia.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, target_rpm)
		volante_inercia.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, 500.0)
		
		var cuerpo_volante = get_node_or_null(volante_inercia.node_b) as RigidBody3D
		if cuerpo_volante:
			vel_giro_volante = cuerpo_volante.angular_velocity.length() 

	# --- AHORA ESTE ES EL PASO 2: Procesar el motor usando la velocidad del volante ---
	var fuerza_bruta_motor: float = 0.0
	if is_instance_valid(motor):
		var acelerador_efectivo = 0.0 if motor_ahogado else acelerador
		# Pasamos 'vel_giro_volante' al motor
		fuerza_bruta_motor = motor.procesar_motor(acelerador_efectivo, vel_giro_volante, delta)
		
		# Ahora sí, actualizamos el impulso del volante con la fuerza real del motor
		if is_instance_valid(volante_inercia):
			volante_inercia.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, fuerza_bruta_motor * 0.1)

	# 3. Leer el promedio de rotación física de las ruedas motrices reales
	# ... (El paso 3 y 4 continúan igual) ...
	var vel_giro_ruedas: float = 0.0
	var ruedas_contadas: int = 0
	var todas_traccion = traccion_principal + traccion_secundaria
	
	for joint in todas_traccion:
		if is_instance_valid(joint):
			var cuerpo_rueda = get_node_or_null(joint.node_b) as RigidBody3D
			if cuerpo_rueda:
				vel_giro_ruedas += cuerpo_rueda.angular_velocity.length()
				ruedas_contadas += 1
				
	if ruedas_contadas > 0:
		vel_giro_ruedas /= ruedas_contadas # Promedio rotacional de las llantas

	# 4. Enviamos las rotaciones a la caja en lugar de la velocidad del chasis
	var datos_caja = {"velocidad": 0.0, "fuerza": 0.0, "freno_parking": false}
	if is_instance_valid(caja_cambios):
		# ATENCIÓN: Pasamos vel_giro_volante y vel_giro_ruedas como nuevos parámetros
		datos_caja = caja_cambios.procesar_transmision(fuerza_bruta_motor, vel_giro_volante, vel_giro_ruedas, acelerador, delta)

	# --- APLICACIÓN DE FUERZAS A LAS RUEDAS ---
	
	for joint in todas_traccion:
		if not is_instance_valid(joint): continue
		
		var tiene_potencia = true
		if not traccion_total_activada and traccion_secundaria.has(joint):
			tiene_potencia = false
		
		# A) Parking (Bloqueo total)
		if datos_caja.get("freno_parking", false):
			joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
			joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.0)
			joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, fuerza_frenado * 5.0) 
			
		# B) Freno de pedal
		elif freno:
			joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
			joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.0)
			joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, fuerza_frenado)
			
		# C) Aceleración (Usando la fuerza final procesada por Motor + Caja)
		elif tiene_potencia and datos_caja.fuerza > 0.0:
			var vel_salida = datos_caja.velocidad
			var fuerza_final = datos_caja.fuerza
			
			if diferencial_bloqueado:
				fuerza_final *= multiplicador_diferencial
			
			joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
			joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, vel_salida)
			joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, fuerza_final)
			
		# D) Rueda libre
		else:
			_set_motor_active(joint, false)
