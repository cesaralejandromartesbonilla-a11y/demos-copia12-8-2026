extends RigidBody3D

@export_group("Configuración de Suspensión")
@export var stiffness: float = 8000.0          # Fuerza del resorte (k)
@export var damping_compression: float = 300.0 # Amortiguación al subir (Bump - suave)
@export var damping_rebound: float = 600.0     # Amortiguación al bajar (Rebound - duro)
@export var angulo_reposo: float = 0.0         # Ángulo de descanso
@export var fuerza_maxima: float = 100.0       # EL SEGURO DE VIDA: Límite de fuerza

@export_group("Estabilidad Anti-Vibración")
@export var deadzone: float = 0.005                # Ignora errores menores a este ángulo
@export var suavizado_fuerza: float = 0.1          # Entre 0 y 1. Menor es más suave/lento.
@export var limite_velocidad_angular: float = 10.0 # Velocidad máxima permitida al brazo
@export var limite_superior_grados: float = 30.0   # Tu límite de compresión máxima
@export var fuerza_bump_stop: float = 50000.0      # Bloqueo extremo al llegar al límite

var torque_previo: float = 0.0
@onready var pivote: HingeJoint3D = $"../PivoteChasis"
var chasis: RigidBody3D

func _ready() -> void:
	# 1. Buscamos el RigidBody3D padre (El Camión)
	var parent = get_parent()
	while parent and not parent is RigidBody3D:
		parent = parent.get_parent()
		
	# 2. ¡CRUCIAL! Asignamos el parent a nuestra variable chasis
	if parent is RigidBody3D:
		chasis = parent
		
		# 3. Reconectamos el pivote al chasis por código (¡No olvides esto!)
		pivote.node_b = chasis.get_path()
		add_collision_exception_with(chasis)
	
	# 4. Buscamos el motor y le pasamos la rueda
	if chasis:
		var motor = chasis.get_node_or_null("ModuloMotor")
		if motor:
			var nodo_rueda = $"../Rueda" as RigidBody3D
			var eje_rueda = $"../EjeRueda" as Generic6DOFJoint3D # Tu 6DOF de la rueda
			
			if nodo_rueda and eje_rueda:
				# DETECTAMOS QUÉ EJE ESTÁ LIBRE (Límite desactivado)
				var eje_local = Vector3.ZERO
				
				# Revisamos los flags (banderas) de Godot para ver qué eje NO tiene límite
				if not eje_rueda.get_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT):
					eje_local = Vector3.RIGHT # Gira en X (1, 0, 0)
				elif not eje_rueda.get_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT):
					eje_local = Vector3.UP    # Gira en Y (0, 1, 0)
				else:
					eje_local = Vector3.FORWARD # Gira en Z (0, 0, 1) por defecto
					
				# Le enviamos al motor LA RUEDA y SU EJE DE GIRO
				motor.registrar_rueda(nodo_rueda, eje_local)

func _physics_process(delta: float) -> void:
	if not chasis: return
	_simular_suspension(delta)

func hookes_law_angular(angle_displacement: float, current_angular_vel: float, k: float, c: float) -> float:
	# F = (k * x) - (c * v)
	return (k * angle_displacement) - (c * current_angular_vel)

func _simular_suspension(delta: float) -> void:
	var angulo_actual = rotation.z 
	var desplazamiento = angulo_reposo - angulo_actual
	var vel_angular = angular_velocity.z
	
	# --- 1. APAGADO TOTAL SI ESTÁ QUIETO (Mata el micro-temblor) ---
	# Si el brazo casi no se mueve y el error es mínimo, apagamos la fuerza
	if abs(desplazamiento) < deadzone and abs(vel_angular) < 0.1:
		torque_previo = 0.0 # Reiniciamos el suavizado
		return # No aplicamos fuerza, dejamos que descanse
		
	var damping_actual = damping_rebound
	if (desplazamiento > 0 and vel_angular < 0) or (desplazamiento < 0 and vel_angular > 0):
		damping_actual = damping_compression
	
	# --- NUEVA LÓGICA DE RESORTE DE UNA VÍA ---
	var fuerza_objetivo = 0.0
	
	if desplazamiento >= 0.0:
		fuerza_objetivo = (stiffness * desplazamiento) - (damping_actual * vel_angular)
	else:
		fuerza_objetivo = 0.0 - (damping_actual * vel_angular)
	
	# --- 2. EL BUMP STOP (Bloqueo al límite) ---
	# Si el ángulo se acerca al límite superior (ej. falta 2 grados para chocar)
	var margen_bloqueo = limite_superior_grados - 2.0
	if angulo_actual > margen_bloqueo:
		# Calculamos cuánto se ha metido en la zona de bloqueo
		var penetracion = angulo_actual - margen_bloqueo
		# Aplicamos una contrafuerza masiva que actúa como un bloque de goma sólida
		fuerza_objetivo -= penetracion * fuerza_bump_stop

	# Suavizado y aplicación
	var torque_suavizado = lerp(torque_previo, fuerza_objetivo, suavizado_fuerza)
	torque_suavizado = clamp(torque_suavizado, -fuerza_maxima, fuerza_maxima)
	torque_previo = torque_suavizado
	
	var torque_final = global_transform.basis.z * torque_suavizado * mass
	apply_torque(torque_final)
	
	if chasis:
		chasis.apply_force(-torque_final, global_position - chasis.global_position)
