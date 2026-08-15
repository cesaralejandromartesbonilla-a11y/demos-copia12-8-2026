extends Node3D

@export_group("Referencias Físicas")
@export var vehiculo_raiz: VehicleBody3D
@export var rueda_fisica_i: VehicleWheel3D
@export var rueda_fisica_d: VehicleWheel3D
@export var raycast_i: RayCast3D
@export var raycast_d: RayCast3D

@export_group("Parámetros")
@export var radio_rueda: float = 0.5
@export var extension_maxima: float = 0.6
@export var ancho_eje: float = 2.0

@onready var malla_llanta_i = $Pivote_L/Malla_Llanta_TI
@onready var malla_llanta_d = $Pivote_R/Malla_Llanta_TD

func _ready() -> void:
	raycast_i.force_raycast_update()
	raycast_d.force_raycast_update()
	if vehiculo_raiz:
		raycast_i.add_exception(vehiculo_raiz)
		raycast_d.add_exception(vehiculo_raiz)

func _physics_process(delta: float) -> void:
	var dist_i = extension_maxima + radio_rueda
	var dist_d = extension_maxima + radio_rueda
	
	if raycast_i.is_colliding():
		dist_i = raycast_i.global_position.distance_to(raycast_i.get_collision_point())
	
	if raycast_d.is_colliding():
		dist_d = raycast_d.global_position.distance_to(raycast_d.get_collision_point())
	
	# Posición Y (Centro del eje)
	var altura_i = -dist_i + radio_rueda
	var altura_d = -dist_d + radio_rueda
	var altura_centro = (altura_i + altura_d) / 2.0
	
	position.y = lerp(position.y, clamp(altura_centro, -extension_maxima, 0.0), 15.0 * delta)
	
	# Inclinación Lateral (Eje Z)
	var diferencia_altura = dist_i - dist_d
	var angulo_z = atan2(diferencia_altura, ancho_eje)
	rotation.z = lerp_angle(rotation.z, angulo_z, 15.0 * delta)

	# Rodamiento
	malla_llanta_i.rotate_x((rueda_fisica_i.get_rpm() * (PI / 30.0)) * delta)
	malla_llanta_d.rotate_x((rueda_fisica_d.get_rpm() * (PI / 30.0)) * delta)
