#script de camion 

extends "res://addons/gevp/scenes/vehicle_base.gd"


const STEER_SPEED = 1.5
const STEER_LIMIT = 0.4
const BRAKE_STRENGTH = 2.0

@export var engine_force_value := 80.0

var previous_speed := linear_velocity.length()
var _steer_target := 0.0

@onready var desired_engine_pitch: float = $EngineSound.pitch_scale

func _physics_process(delta: float) -> void:
	# 🔑 Solo este vehículo responde si está montado
	if !is_mounted:
		# Resetear fuerzas para que no se mueva solo
		_reset_vehicle_forces()
		return

	# Lógica de acople/desacople con tecla "F"
	if Input.is_action_just_pressed("press_f"):
		if remolque_acoplado == null:
			intentar_acoplar()
		else:
			desacoplar()

	var _fwd_mps := (linear_velocity * transform.basis).x

	_steer_target = Input.get_axis(&"press_d", &"press_a")
	_steer_target *= STEER_LIMIT

	# Engine sound simulation (not realistic, as this car script has no notion of gear or engine RPM).
	desired_engine_pitch = 0.05 + linear_velocity.length() / (engine_force_value * 0.5)
	# Change pitch smoothly to avoid abrupt change on collision.
	$EngineSound.pitch_scale = lerpf($EngineSound.pitch_scale, desired_engine_pitch, 0.2)

	if abs(linear_velocity.length() - previous_speed) > 1.0:
		# Sudden velocity change, likely due to a collision. Play an impact sound to give audible feedback,
		# and vibrate for haptic feedback.
		$ImpactSound.play()
		Input.vibrate_handheld(100)
		for joypad in Input.get_connected_joypads():
			Input.start_joy_vibration(joypad, 0.0, 0.5, 0.1)

	# Automatically accelerate when using touch controls (reversing overrides acceleration).
	if DisplayServer.is_touchscreen_available() or Input.is_action_pressed(&"press_w"):
		# Increase engine force at low speeds to make the initial acceleration faster.
		var speed := linear_velocity.length()
		if speed < 5.0 and not is_zero_approx(speed):
			engine_force = clampf(engine_force_value * 5.0 / speed, 0.0, 100.0)
		else:
			engine_force = engine_force_value

		if not DisplayServer.is_touchscreen_available():
			# Apply analog throttle factor for more subtle acceleration if not fully holding down the trigger.
			engine_force *= Input.get_action_strength(&"press_w")
	else:
		engine_force = 0.0

	if Input.is_action_pressed(&"press_s"):
		# Increase engine force at low speeds to make the initial reversing faster.
		var speed := linear_velocity.length()
		if speed < 5.0 and not is_zero_approx(speed):
			engine_force = -clampf(engine_force_value * BRAKE_STRENGTH * 5.0 / speed, 0.0, 100.0)
		else:
			engine_force = -engine_force_value * BRAKE_STRENGTH

		# Apply analog brake factor for more subtle braking if not fully holding down the trigger.
		engine_force *= Input.get_action_strength(&"press_s")

	steering = move_toward(steering, _steer_target, STEER_SPEED * delta)

	previous_speed = linear_velocity.length()

# ——————————————————————————————
# DESCARGAR CARGA (Corregido para Remolques)
# ——————————————————————————————

func _input(event):
	if event.is_action_pressed("press_g") and is_mounted:
# En Camion.gd dentro de la función de descarga
		if remolque_acoplado:
			for hijo in remolque_acoplado.get_children():
				if hijo.has_method("funcion_de_vehiculo"):
					hijo.funcion_de_vehiculo()
		
		# Si el remolque tiene el Area3D de carga, reseteamos sus slots
		var zona_carga = remolque_acoplado.find_child("ZonaDeCarga") #esto es normal Cannot call method 'find_child' on a null value.
		if zona_carga:
			zona_carga.liberar_todos_los_slots()


		# 2. SI HAY UN REMOLQUE, buscar también en sus hijos
		if remolque_acoplado != null:
			print("Descargando desde el remolque...")
			for hijo in remolque_acoplado.get_children():
				if hijo.has_method("desacoplar_de_vehiculo"):
					hijo.desacoplar_de_vehiculo()



#acople de remolque==============================================================================

@onready var joint: ConeTwistJoint3D = $PinJoint3D
@onready var punto_camion: Marker3D = $PuntoAcopleCamion
@export var area_acople: Area3D 
var remolque_cercano: VehicleBody3D = null
var remolque_acoplado: VehicleBody3D = null

func intentar_acoplar():
	if remolque_cercano and not remolque_acoplado:
		var punto_remolque = remolque_cercano.get_node_or_null("PuntoAcopleRemolque")
		if punto_remolque:
			remolque_acoplado = remolque_cercano
			
			# Alineación exacta de los Marker3D
			var diff = punto_camion.global_position - punto_remolque.global_position
			remolque_acoplado.global_position += diff
			
			# Configurar Joint
			joint.global_position = punto_camion.global_position
			joint.node_a = self.get_path()
			joint.node_b = remolque_acoplado.get_path()
			
			# Ajuste de masa: el peso cae en la quinta rueda
			remolque_acoplado.center_of_mass_mode = VehicleBody3D.CENTER_OF_MASS_MODE_AUTO
			
			joint.exclude_nodes_from_collision = false

func desacoplar():
	if remolque_acoplado:
		joint.node_b = NodePath("")
		joint.node_a = NodePath("")
		remolque_acoplado.center_of_mass_mode = VehicleBody3D.CENTER_OF_MASS_MODE_AUTO
		center_of_mass_mode = VehicleBody3D.CENTER_OF_MASS_MODE_AUTO
		remolque_acoplado = null


func _on_zona_acople_body_entered(body: Node3D) -> void:
	if body is VehicleBody3D and body.is_in_group("remolques"):
		remolque_cercano = body
		print("Remolque listo para acoplar")

func _on_zona_acople_body_exited(body: Node3D) -> void:
	if body == remolque_cercano:
		remolque_cercano = null


# Función auxiliar para limpiar fuerzas==========================================================

func _reset_vehicle_forces():
	$Wheel2.engine_force = 0
	$Wheel4.engine_force = 0
	$Wheel1.steering = 0
	$Wheel3.steering = 0
	$Wheel1.brake = 0
	$Wheel3.brake = 0

#guardado=======================================================================================

@export var value: int = 1 # Valor personalizado del objeto

func _ready():
	# Asegurarse de que se añade al grupo al instanciarse dinámicamente
	if not is_in_group("Persistente"):
		add_to_group("Persistente")

# Función para ser llamada por el SaveManager
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
