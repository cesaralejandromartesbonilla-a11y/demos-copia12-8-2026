extends Node3D

@export var chasis: VehicleBody3D

@export_group("Filtro de Inercia")
# Este es el antídoto para el "latigazo". 
# Valores bajos (ej. 5.0) hacen que la inercia suba poco a poco. Valores altos (20.0) la hacen instantánea.
@export var velocidad_reaccion: float = 10.0 

@export_group("Sensibilidad (Fuerza G)")
@export var sens_frente: float = 1.5   # Al frenar
@export var sens_atras: float = 0.8    # Al acelerar (más bajo para evitar mirar al cielo)
@export var sens_der: float = 0.0      # Al girar izquierda (inercia a derecha)
@export var sens_izq: float = 0.0      # Al girar derecha (inercia a izquierda)
@export var sens_abajo: float = 0.5    # Baches

@export_group("Límites de Inclinación (Grados)")
@export var lim_frente_grados: float = 15.0
@export var lim_atras_grados: float = 5.0
@export var lim_der_grados: float = 0.0
@export var lim_izq_grados: float = 0.0  # Límite estricto para simular tope rígido

@export_group("Rigidez (Retorno al Centro)")
@export var rigidez_frente: float = 5.0
@export var rigidez_atras: float = 12.0
@export var rigidez_der: float = 4.0
@export var rigidez_izq: float = 4.0
@export var rigidez_vertical: float = 8.0

# Variables internas
var velocidad_anterior: Vector3 = Vector3.ZERO
var aceleracion_suavizada: Vector3 = Vector3.ZERO # Nuestra nueva inercia filtrada
var posicion_base: Vector3
var rotacion_base: Vector3

func _ready() -> void:
	posicion_base = position
	rotacion_base = rotation
	if chasis:
		velocidad_anterior = chasis.linear_velocity

func _physics_process(delta: float) -> void:
	if not chasis: return
	
	# 1. Obtener la aceleración pura del chasis
	var velocidad_actual = chasis.linear_velocity
	var aceleracion_global = (velocidad_actual - velocidad_anterior) / delta
	velocidad_anterior = velocidad_actual
	var aceleracion_local_cruda = chasis.global_transform.basis.inverse() * aceleracion_global
	
	# 2. EL SUAVIZADOR (Filtro de picos)
	# En lugar de usar la fuerza cruda, la suavizamos progresivamente
	aceleracion_suavizada = aceleracion_suavizada.lerp(aceleracion_local_cruda, velocidad_reaccion * delta)
	
	# --- 3. CÁLCULOS ASIMÉTRICOS ---
	
	# A. PITCH (Cabeceo Adelante / Atrás)
	var delta_pitch = -aceleracion_suavizada.z # Invertimos Z para la inercia
	var objetivo_rot_x = rotacion_base.x
	var rigidez_actual_x = 0.0
	
	if delta_pitch > 0:
		# Inercia hacia ADELANTE (Frenado)
		objetivo_rot_x += delta_pitch * sens_frente
		objetivo_rot_x = min(objetivo_rot_x, rotacion_base.x + deg_to_rad(lim_frente_grados))
		rigidez_actual_x = rigidez_frente
	else:
		# Inercia hacia ATRÁS (Acelerando)
		objetivo_rot_x += delta_pitch * sens_atras
		objetivo_rot_x = max(objetivo_rot_x, rotacion_base.x - deg_to_rad(lim_atras_grados))
		rigidez_actual_x = rigidez_atras

	# B. ROLL (Balanceo Izquierda / Derecha)
	var delta_roll = aceleracion_suavizada.x
	var objetivo_rot_z = rotacion_base.z
	var rigidez_actual_z = 0.0
	
	if delta_roll > 0:
		# Inercia hacia la DERECHA
		objetivo_rot_z -= delta_roll * sens_der
		objetivo_rot_z = max(objetivo_rot_z, rotacion_base.z - deg_to_rad(lim_der_grados))
		rigidez_actual_z = rigidez_der
	else:
		# Inercia hacia la IZQUIERDA
		objetivo_rot_z -= delta_roll * sens_izq
		objetivo_rot_z = min(objetivo_rot_z, rotacion_base.z + deg_to_rad(lim_izq_grados))
		rigidez_actual_z = rigidez_izq

	# C. REBOTE (Vertical)
	var objetivo_pos_y = posicion_base.y - (aceleracion_suavizada.y * sens_abajo)
	objetivo_pos_y = clamp(objetivo_pos_y, posicion_base.y - 0.5, posicion_base.y + 0.2)

	# --- 4. APLICAR MOVIMIENTO FLUIDO ---
	position.y = lerp(position.y, objetivo_pos_y, rigidez_vertical * delta)
	rotation.x = lerp(rotation.x, objetivo_rot_x, rigidez_actual_x * delta)
	rotation.z = lerp(rotation.z, objetivo_rot_z, rigidez_actual_z * delta)
