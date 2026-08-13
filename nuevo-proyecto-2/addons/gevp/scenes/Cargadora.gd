# auto.gd 
extends "res://addons/gevp/scenes/vehicle_base.gd"

@export_group("custom")
@export var fuerza = 200
@export var frenada = 10
@export var direccion = 0.3

@export var velocidad_carrito := 0.010
# Ajustes de velocidad y límites
@export var vel_brazo := 1.5
@export var vel_pala := 2.0

@onready var brazo = $BrazoPrincipal
@onready var pala = $BrazoPrincipal/PalaPivote
# Referencia al cuerpo físico para forzar la sincronización
@onready var pala_cuerpo = %AnimatableBody3D

# Límites de rotación (en grados)
var pala_min := -35.0
var pala_max := 50.0

func _physics_process(_delta: float) -> void:
	# 1. Verificación de montado
	if !is_mounted:
		return

	# 2. Control de Tracción y Dirección
	if Input.is_action_pressed("press_s"):
		$VehicleWheel3D3.engine_force = -fuerza
		$VehicleWheel3D4.engine_force = -fuerza
	elif Input.is_action_pressed("press_w"):
		$VehicleWheel3D3.engine_force = fuerza
		$VehicleWheel3D4.engine_force = fuerza
	else:
		$VehicleWheel3D3.engine_force = 0
		$VehicleWheel3D4.engine_force = 0
	
	if Input.is_action_pressed("press_a"):
		$VehicleWheel3D.steering = direccion
		$VehicleWheel3D2.steering = direccion
	elif Input.is_action_pressed("press_d"):
		$VehicleWheel3D.steering = -direccion
		$VehicleWheel3D2.steering = -direccion
	else:
		$VehicleWheel3D.steering = 0
		$VehicleWheel3D2.steering = 0
	
	if Input.is_action_pressed("press_space"):
		$VehicleWheel3D.brake = frenada
		$VehicleWheel3D2.brake = frenada
	else:
		$VehicleWheel3D.brake = 0
		$VehicleWheel3D2.brake = 0

	# 3. Control del Mástil/Brazo (Subir/Bajar)
	var input_carrito = Input.get_axis("press_h", "press_y")
	pala.position.y = clamp(pala.position.y + (input_carrito * velocidad_carrito), -0.2, 1.5)

	# 4. Control de la Inclinación (Tilt)
	var input_pala = Input.get_axis("press_r", "press_f")
	brazo.rotation_degrees.x = clamp(
		brazo.rotation_degrees.x + (input_pala * vel_pala), 
		pala_min, 
		pala_max
	)

	# 5. FORZAR SINCRONIZACIÓN DE FÍSICAS (Solución al CollisionShape quieto)
	if pala_cuerpo:
		pala_cuerpo.global_transform = pala_cuerpo.global_transform


func save():
	var save_dict = {
		"filename" : get_scene_file_path(),
		"parent" : get_parent().get_path(),
		"pos_x" : position.x,
		"pos_y" : position.y,
		"pos_z" : position.z,
		"spawned": false
	}
	return save_dict
