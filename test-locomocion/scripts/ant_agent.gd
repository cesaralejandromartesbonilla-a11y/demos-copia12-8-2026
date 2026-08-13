extends CharacterBody3D

@export var move_speed: float = 3.0
@export var turn_speed: float = 2.0

var group_a: Array = []
var group_b: Array = []

# 0 significa que el Grupo A tiene el turno, 1 significa el Grupo B
var priority_group: int = 0 

func _ready():
	return
	# Inicializar IKs
	for ik in find_children("*", "SkeletonIK3D"):
		ik.start()
		
	# Clasificar patas automáticamente por su variable step_group
	var all_steppers = find_children("*", "LegStepper") 
	for stepper in all_steppers:
		if stepper.step_group == 0:
			group_a.append(stepper)
		else:
			group_b.append(stepper)
	print("Patas en Grupo A: ", group_a.size(), " | Patas en Grupo B: ", group_b.size())

func _physics_process(delta):
	return
	# Control básico para mover la hormiga y probar
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity = direction * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	move_and_slide()
	
	# Llamamos al nuevo gestor de marcha infalible
	_manage_gait()

func _manage_gait():
	var a_is_stepping = false
	var b_is_stepping = false
	
	# 1. Revisamos quién está en el aire en este momento exacto
	for leg in group_a: 
		if leg.is_stepping: a_is_stepping = true
	for leg in group_b: 
		if leg.is_stepping: b_is_stepping = true

	# 2. Lógica de bloqueo estricto
	if a_is_stepping:
		# Si A se está moviendo, bloqueamos B por seguridad
		_set_group_permission(group_a, true)
		_set_group_permission(group_b, false)
		priority_group = 1 # Dejamos preparado que el siguiente turno será de B
		
	elif b_is_stepping:
		# Si B se está moviendo, bloqueamos A por seguridad
		_set_group_permission(group_a, false)
		_set_group_permission(group_b, true)
		priority_group = 0 # Dejamos preparado que el siguiente turno será de A
		
	else:
		# 3. Nadie se está moviendo (cuerpo quieto o avanzando sin alcanzar el límite aún).
		# Desbloqueamos SOLO al grupo que tiene la prioridad para evitar empates.
		if priority_group == 0:
			_set_group_permission(group_a, true)
			_set_group_permission(group_b, false)
		else:
			_set_group_permission(group_a, false)
			_set_group_permission(group_b, true)

# Función auxiliar para no repetir código
func _set_group_permission(group: Array, permission: bool):
	for leg in group:
		leg.can_step = permission
