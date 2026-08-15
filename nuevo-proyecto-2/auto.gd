# auto.gd 
extends "res://addons/gevp/scenes/vehicle_base.gd"
@export_group("custom")
@export var fuerza = 200
@export var frenada = 10
@export var direccion = 0.3

func _physics_process(_delta: float) -> void:
	# 🔑 Solo este vehículo responde si está montado
	if !is_mounted:
		# Resetear fuerzas para que no se mueva solo
		_reset_vehicle_forces()
		return

	# Lógica de control normal (solo si montado)
	if Input.is_action_pressed("press_w"):
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

# Función auxiliar para limpiar fuerzas
func _reset_vehicle_forces():
	$VehicleWheel3D3.engine_force = 0
	$VehicleWheel3D4.engine_force = 0
	$VehicleWheel3D.steering = 0
	$VehicleWheel3D2.steering = 0
	$VehicleWheel3D.brake = 0
	$VehicleWheel3D2.brake = 0

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
