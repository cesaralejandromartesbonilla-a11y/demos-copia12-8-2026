extends PiezaMecanica
class_name PiezaMotor

## El motor NO lee ninguna 'fuente' (a diferencia de PiezaTransmision) — lo
## maneja directo el input del jugador, a través de tu ControladorVehiculo.gd
## YA EXISTENTE. No hace falta tocar ese script ni una línea: apenas esta
## pieza se monta, se registra sola en su 'joints_traccion'.
##
## Único paso manual: seleccioná el nodo que tiene ControladorVehiculo.gd
## en el editor y agregalo al grupo "controlador_vehiculo" (panel Node > Groups).

func al_ser_montada() -> void:
	super()
	joint_montaje.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.0)  # explícito, no confiamos en el default del joint

	var controlador := get_tree().get_first_node_in_group("controlador_vehiculo")
	if controlador and ("joints_traccion" in controlador):
		controlador.joints_traccion.append(joint_montaje)
		print("PiezaMotor: registrado en joints_traccion de ", controlador.name)
	else:
		push_warning("PiezaMotor: no encontré un nodo en el grupo 'controlador_vehiculo'. Agregá joint_montaje a joints_traccion a mano, o revisá el grupo.")
