extends Node
class_name EnsambladorMecanico

## Equivalente a AssemblerModule del proyecto de criaturas, pero para piezas
## físicas de verdad. La diferencia central: allá, acoplar era
## "socket.add_child(pieza)" — puro parentesco de escena, cero física. Acá,
## acoplar significa instanciar un RigidBody3D independiente y crear un
## HingeJoint3D real que lo une al larguero. Nunca Generic6DOFJoint3D: el
## larguero es el único cuerpo estructural, todo lo demás es una pieza
## rotativa con un solo hinge.

@export var larguero: Larguero

var motor_actual: PiezaMotor = null
var engranaje_actual: PiezaTransmision = null
var rueda_actual: PiezaTransmision = null


func acoplar_pieza(socket: SocketMecanico, datos: DatosPiezaMecanica) -> PiezaMecanica:
	if not larguero:
		push_error("EnsambladorMecanico: falta asignar 'larguero' en el Inspector.")
		return null
	if socket.is_occupied:
		push_warning("EnsambladorMecanico: el socket '%s' ya está ocupado." % socket.socket_name)
		return null
	if not datos or not datos.part_scene:
		push_error("EnsambladorMecanico: DatosPiezaMecanica sin part_scene asignada.")
		return null

	var contenedor := larguero.get_parent()
	if not contenedor:
		push_error("EnsambladorMecanico: 'larguero' no tiene nodo padre — necesita un contenedor común (ej. 'Construccion') donde agregar las piezas nuevas.")
		return null

	var instancia := datos.part_scene.instantiate() as PiezaMecanica
	if not instancia:
		push_error("EnsambladorMecanico: la raíz de la escena de '%s' no es una PiezaMecanica." % datos.display_name)
		return null

	contenedor.add_child(instancia)
	instancia.global_transform = socket.global_transform

	instancia.joint_montaje = _crear_joint_hinge(socket, instancia)
	larguero.add_collision_exception_with(instancia)
	for otra in [motor_actual, engranaje_actual, rueda_actual]:
		if otra and otra != instancia:
			instancia.add_collision_exception_with(otra)
	socket.is_occupied = true

	_registrar_y_conectar(datos.part_type, instancia)
	instancia.al_ser_montada()

	print("EnsambladorMecanico: '%s' acoplada en socket '%s'." % [datos.display_name, socket.socket_name])
	return instancia


## Configura el joint COMPLETO antes de meterlo en el árbol — node_a, node_b
## y transform primero, add_child() al final. Al revés (que es como estaba
## antes) el joint entra al mundo físico sin cuerpos asignados todavía, y
## reasignar node_a/node_b después no siempre reconstruye bien el
## constraint. En una escena armada a mano en el editor esto nunca pasa,
## porque node_a/node_b ya están puestos en el .tscn antes de que la escena
## arranque — por eso modulo_motor.gd anda en tu proyecto pero acá no andaba.
func _crear_joint_hinge(socket: SocketMecanico, pieza: RigidBody3D) -> HingeJoint3D:
	var joint := HingeJoint3D.new()
	joint.global_transform = socket.global_transform
	joint.node_a = larguero.get_path()
	joint.node_b = pieza.get_path()
	larguero.add_child(joint)
	return joint


## Cablea 'fuente' según qué se montó y qué había antes — funciona sin
## importar el orden de armado (motor primero, rueda primero, etc.) porque
## SIEMPRE re-revisa las tres referencias actuales, no asume una secuencia.
func _registrar_y_conectar(tipo: DatosPiezaMecanica.PartType, pieza: PiezaMecanica) -> void:
	match tipo:
		DatosPiezaMecanica.PartType.MOTOR:
			motor_actual = pieza as PiezaMotor
			if engranaje_actual:
				engranaje_actual.fuente = motor_actual
			elif rueda_actual:
				rueda_actual.fuente = motor_actual  # todavía no hay engranaje: rueda a motor directo

		DatosPiezaMecanica.PartType.ENGRANAJE:
			engranaje_actual = pieza as PiezaTransmision
			if motor_actual:
				engranaje_actual.fuente = motor_actual
			if rueda_actual:
				rueda_actual.fuente = engranaje_actual  # la rueda pasa a escuchar al engranaje, no al motor

		DatosPiezaMecanica.PartType.RUEDA:
			rueda_actual = pieza as PiezaTransmision
			if engranaje_actual:
				rueda_actual.fuente = engranaje_actual
			elif motor_actual:
				rueda_actual.fuente = motor_actual
