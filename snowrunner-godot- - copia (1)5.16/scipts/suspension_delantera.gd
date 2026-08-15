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
@export var escala_ballesta_reposo: float = 1.0

@onready var malla_ballesta = $Eje_Metal_Malla
@onready var pivote_direccion_i = $Pivote_Direccion_DI
@onready var malla_llanta_i = $Pivote_Direccion_DI/Llanta_Visual_DI
@onready var pivote_direccion_d = $Pivote_Direccion_DD
@onready var malla_llanta_d = $Pivote_Direccion_DD/Llanta_Visual_DD

func _ready() -> void:
	raycast_d.force_raycast_update()
	raycast_i.force_raycast_update()
	if vehiculo_raiz:
		raycast_i.add_exception(vehiculo_raiz)
		raycast_d.add_exception(vehiculo_raiz)

func _physics_process(delta: float) -> void:
	_procesar_esquina(raycast_i, rueda_fisica_i, pivote_direccion_i, malla_llanta_i, delta)
	_procesar_esquina(raycast_d, rueda_fisica_d, pivote_direccion_d, malla_llanta_d, delta)
	
	# Promediar la altura del contenedor principal para evitar que la izquierda y derecha peleen
	var altura_i = -raycast_i.global_position.distance_to(raycast_i.get_collision_point()) + radio_rueda if raycast_i.is_colliding() else -extension_maxima
	var altura_d = -raycast_d.global_position.distance_to(raycast_d.get_collision_point()) + radio_rueda if raycast_d.is_colliding() else -extension_maxima
	var altura_centro = (altura_i + altura_d) / 2.0
	
	position.y = lerp(position.y, clamp(altura_centro, -extension_maxima, 0.0), 20.0 * delta)

func _procesar_esquina(ray: RayCast3D, rueda: VehicleWheel3D, pivote: Node3D, llanta: Node3D, delta: float) -> void:
	# Compresión de la ballesta
	if ray.is_colliding():
		var distancia = ray.global_position.distance_to(ray.get_collision_point())
		var compresion = clamp(1.0 - (distancia / extension_maxima), 0.0, 1.0)
		malla_ballesta.scale.y = lerp(escala_ballesta_reposo, escala_ballesta_reposo * 0.3, compresion)
	else:
		malla_ballesta.scale.y = escala_ballesta_reposo

	# Dirección y Rodamiento
	pivote.rotation.y = rueda.steering
	var radianes_por_segundo = rueda.get_rpm() * (PI / 30.0)
	llanta.rotate_x(radianes_por_segundo * delta)
