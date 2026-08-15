extends VehicleBody3D

# --- SEÑALES ---
signal datos_actualizados(combustible: float, velocidad: float, rpm: float)
signal traccion_cambiada(es_4x4: bool)
signal motor_estado_cambiado(encendido: bool)
signal dif_cambiado(bloqueado: bool)

# --- CONFIGURACIÓN EXPORTADA ---
@export_group("Motor y Transmisión")
@export var max_torque: float = 600.0
@export var max_rpm: float = 3000.0
@export var curvas_torque: Curve
@export var steering_max: float = 0.6
@export var steering_speed: float = 2.5

@export_group("Combustible")
@export var combustible_max: float = 100.0

@export_group("Remolque")
@export var nodo_quinta_rueda: Marker3D

# --- VARIABLES INTERNAS ---
var combustible_actual: float = 0.0
var motor_encendido: bool = false
var es_4x4: bool = false
var dif_bloqueado: bool = false

# Variables Remolque
var remolque_acoplado: Node3D = null
var joint_acople: Joint3D = null

# Variables Barro
var en_barro: bool = false
var factor_resistencia_barro: float = 0.0

func _ready() -> void:
	combustible_actual = combustible_max
	
	if not curvas_torque:
		curvas_torque = Curve.new()
		curvas_torque.add_point(Vector2(0, 1))
		curvas_torque.add_point(Vector2(1, 0.2))

func _physics_process(delta: float) -> void:
	_gestionar_inputs()
	_aplicar_fisicas_motor(delta)
	_aplicar_fisicas_barro(delta)
	
	# Emitir datos a la UI
	var vel = linear_velocity.length() * 3.6
	var rpm = 0.0
	if motor_encendido:
		rpm = clamp((linear_velocity.length() / 20.0) * max_rpm, 800.0, max_rpm)
	datos_actualizados.emit(combustible_actual, vel, rpm)

func _gestionar_inputs() -> void:
	# E: Motor
	if Input.is_action_just_pressed("press_e"):
		if combustible_actual > 0:
			motor_encendido = !motor_encendido
			motor_estado_cambiado.emit(motor_encendido)

	# T: Tracción 4x4
	if Input.is_action_just_pressed("press_t"):
		es_4x4 = !es_4x4
		traccion_cambiada.emit(es_4x4)

	# Z: Diferencial
	if Input.is_action_just_pressed("press_z"):
		dif_bloqueado = !dif_bloqueado
		dif_cambiado.emit(dif_bloqueado)
	
	# F: Remolque
	if Input.is_action_just_pressed("press_f"):
		if remolque_acoplado:
			_desacoplar()
		else:
			_acoplar()

func _aplicar_fisicas_motor(delta: float) -> void:
	var aceleracion = 0.0
	var direccion = Input.get_axis("press_d", "press_a") # D/A para izquierda/derecha

	# Lógica Motor
	if motor_encendido and combustible_actual > 0:
		aceleracion = Input.get_axis("press_s", "press_w") # S/W para freno/gas
		_consumir_combustible(aceleracion, delta)
	else:
		aceleracion = 0.0
		if combustible_actual <= 0:
			motor_encendido = false

	# Calcular fuerza
	var ratio = clamp(linear_velocity.length() / 25.0, 0.0, 1.0)
	var torque_final = aceleracion * max_torque * curvas_torque.sample(ratio)

	# Aplicar dirección
	steering = move_toward(steering, direccion * steering_max, steering_speed * delta)

	# Aplicar fuerza a las ruedas
	for wheel in get_children():
		if wheel is VehicleWheel3D:
			var es_trasera = wheel.position.z > 0
			var es_motriz = es_trasera or es_4x4
			
			wheel.engine_force = torque_final if es_motriz else 0.0
			wheel.wheel_friction_slip = 8.0 if dif_bloqueado else 2.0
			
			# Frenado simple
			if aceleracion == 0 and linear_velocity.length() < 1.0:
				wheel.brake = 5.0
			else:
				wheel.brake = 0.0

func _consumir_combustible(acel: float, delta: float) -> void:
	var base = 0.5 if acel != 0 else 0.1
	if es_4x4: base *= 1.2
	if dif_bloqueado: base *= 1.1
	combustible_actual -= base * delta

func _aplicar_fisicas_barro(delta: float) -> void:
	if en_barro:
		# Frenar el chasis según viscosidad
		var resistencia = -linear_velocity.normalized() * (linear_velocity.length() * factor_resistencia_barro) * mass * delta
		apply_central_force(resistencia)
		
		# Quitar agarre a ruedas
		for w in get_children():
			if w is VehicleWheel3D:
				w.wheel_friction_slip = 0.8

# --- SISTEMA REMOLQUE ---
func _acoplar():
	if not nodo_quinta_rueda: return
	
	var remolques = get_tree().get_nodes_in_group("remolques")
	for r in remolques:
		if r.has_node("PuntoPerno"):
			var dist = nodo_quinta_rueda.global_position.distance_to(r.get_node("PuntoPerno").global_position)
			if dist < 20.5:
				_crear_joint(r)
				return

func _crear_joint(remolque):
	remolque_acoplado = remolque
	# Alinear posiciones
	var offset = remolque.global_position - remolque.get_node("PuntoPerno").global_position
	remolque.global_position = nodo_quinta_rueda.global_position + offset
	
	# Joint Físico
	joint_acople = ConeTwistJoint3D.new()
	add_child(joint_acople)
	joint_acople.global_position = nodo_quinta_rueda.global_position
	joint_acople.node_a = self.get_path()
	joint_acople.node_b = remolque.get_path()
	
	# Params
	joint_acople.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(60))
	joint_acople.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(20))
	
	add_collision_exception_with(remolque)
	if remolque.has_method("set_conectado"):
		remolque.set_conectado(true)

func _desacoplar():
	if joint_acople:
		joint_acople.queue_free()
		joint_acople = null
	
	if remolque_acoplado:
		remove_collision_exception_with(remolque_acoplado)
		if remolque_acoplado.has_method("set_conectado"):
			remolque_acoplado.set_conectado(false)
		remolque_acoplado = null

# Llamadas externas (Area3D de lodo)
func set_en_barro(estado: bool, viscosidad: float):
	en_barro = estado
	factor_resistencia_barro = viscosidad

func repostar(cantidad: float):
	combustible_actual += cantidad
	# Clamp para no superar el máximo
	if combustible_actual > combustible_max:
		combustible_actual = combustible_max
 
	# Emitimos la señal para actualizar la UI inmediatamente
	datos_actualizados.emit(combustible_actual)
