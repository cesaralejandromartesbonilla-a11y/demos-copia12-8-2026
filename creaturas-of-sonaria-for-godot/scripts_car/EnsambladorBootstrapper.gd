extends Node3D
class_name EnsambladorBootstrapper

## Mismo espíritu que RequirementsBootstrapper.gd del proyecto de criaturas:
## genera toda la jerarquía por código en vez de armarla a mano en el editor.
## Poné este script en una escena vacía y dale a jugar — vas a tener el
## larguero, los 3 sockets, el ensamblador, la UI y hasta el catálogo de
## piezas (con mesh y colisión placeholder) ya armados y cableados. Después,
## si querés, seleccioná esta rama en el árbol remoto y "Guardar rama como
## escena" para tener un .tscn de verdad — mismo flujo que ya usaste con el
## constructor de criaturas.
##
## Este nodo hace de "Construccion" (el contenedor común del diagrama de
## LEEME.md) — Larguero, EnsambladorMecanico y EnsambladorMecanicoUI cuelgan
## directo de acá.

## Capa de colisión para los SocketMecanico. Uso la 11 (1 << 10) y no la 10
## porque tu CameraController.gd ya usa collision_mask = 513 (capas 1 y 10)
## para el internal_ray del buceo. No debería chocar en la práctica (esa
## raycast solo mira bodies, no areas) pero mejor no pisar una capa que ya
## está en uso — confirmá en Project Settings > Layer Names > 3D Physics
## que la 11 esté libre en tu proyecto.
const CAPA_SOCKETS := 1 << 10

@export var camera: Camera3D  # opcional — si no la asignás, la busca vía CameraController o en el viewport
@export var colocar_piezas_automaticamente: bool = true  # true = arma el vehículo completo al arrancar, sin pasar por la UI de clic — para probar SOLO la física primero
@export var congelar_larguero_diagnostico: bool = true  # TEMPORAL: si el larguero también rota (por el torque de reacción de los 3 motores), eso se mezcla con el giro propio de cada pieza. Congelarlo aísla si el problema viene de ahí. Ponelo en false cuando termines de diagnosticar — un chasis de verdad tiene que poder rotar.
@export var crear_controlador_vehiculo: bool = true  # true = genera un ControladorVehiculo y lo mete solo en el grupo "controlador_vehiculo" — así PiezaMotor tiene dónde registrarse sin que armes nada a mano

var controlador_vehiculo: ControladorVehiculo

var larguero: Larguero
var ensamblador: EnsambladorMecanico
var ensamblador_ui: EnsambladorMecanicoUI
var datos_motor: DatosPiezaMecanica
var datos_engranaje: DatosPiezaMecanica
var datos_rueda: DatosPiezaMecanica
var socket_motor: SocketMecanico
var socket_engranaje: SocketMecanico
var socket_rueda: SocketMecanico


func _ready() -> void:
	_crear_larguero()
	_crear_ensamblador()

	if crear_controlador_vehiculo:
		_crear_controlador_vehiculo()

	var camera_controller := get_tree().get_first_node_in_group("camara_principal")
	_crear_ui(camera_controller)
	_activar_orbital(camera_controller)
	_crear_catalogo()

	if colocar_piezas_automaticamente:
		_colocar_piezas_automaticamente()

	_set_owner_recursivo(self, self)
	print("EnsambladorBootstrapper: jerarquía generada. Mirala en el árbol remoto mientras corre la escena — datos_motor / datos_engranaje / datos_rueda ya están listos para ensamblador_ui.set_selected_part().")


func _crear_larguero() -> void:
	larguero = Larguero.new()
	larguero.name = "Larguero"
	larguero.lock_rotation = congelar_larguero_diagnostico
	add_child(larguero)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 0.3, 0.6)
	mesh.mesh = box
	mesh.material_override = _material(Color.SLATE_GRAY)
	larguero.add_child(mesh)

	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box.size
	col.shape = box_shape
	larguero.add_child(col)

	socket_motor = _crear_socket("SocketMotor", Vector3(-0.7, 0.6, 0))
	socket_engranaje = _crear_socket("SocketEngranaje", Vector3(0.0, 0.6, 0))
	socket_rueda = _crear_socket("SocketRueda", Vector3(0.7, 0.6, 0))


func _crear_socket(nombre: String, posicion_local: Vector3) -> SocketMecanico:
	var socket := SocketMecanico.new()
	socket.name = nombre
	socket.socket_name = nombre
	socket.collision_layer = CAPA_SOCKETS
	socket.position = posicion_local
	socket.rotation_degrees.y = 90.0  # eje de giro (+Z local) apuntando de costado — ajustalo cuando tengas mallas reales
	larguero.add_child(socket)
	return socket


func _crear_ensamblador() -> void:
	ensamblador = EnsambladorMecanico.new()
	ensamblador.name = "EnsambladorMecanico"
	add_child(ensamblador)
	ensamblador.larguero = larguero


## Genera el ControladorVehiculo y lo agrupa solo — así respondo tu duda:
## joints_traccion NO lo llenás vos a mano, PiezaMotor.al_ser_montada() hace
## controlador.joints_traccion.append(joint_montaje) apenas se coloca cada
## motor. Lo único que hacía falta era que este nodo existiera y estuviera
## en el grupo "controlador_vehiculo" ANTES de que _colocar_piezas_automaticamente()
## corra — por eso esta función va antes que esa en _ready().
func _crear_controlador_vehiculo() -> void:
	controlador_vehiculo = ControladorVehiculo.new()
	controlador_vehiculo.name = "ControladorVehiculo"
	add_child(controlador_vehiculo)
	controlador_vehiculo.add_to_group("controlador_vehiculo")


func _crear_ui(camera_controller: Node) -> void:
	ensamblador_ui = EnsambladorMecanicoUI.new()
	ensamblador_ui.name = "EnsambladorMecanicoUI"
	add_child(ensamblador_ui)
	ensamblador_ui.ensamblador = ensamblador
	ensamblador_ui.socket_collision_mask = CAPA_SOCKETS
	ensamblador_ui.hologram_material = _material(Color(1, 1, 1, 0.4), true)

	if camera_controller and camera_controller.has_method("get_camera"):
		ensamblador_ui.camera = camera_controller.get_camera()
	elif camera:
		ensamblador_ui.camera = camera
	else:
		ensamblador_ui.camera = get_viewport().get_camera_3d()
		push_warning("EnsambladorBootstrapper: no encontré un CameraController en el grupo 'camara_principal' ni asignaste 'camera' a mano — uso la cámara activa del viewport como último recurso.")


func _activar_orbital(camera_controller: Node) -> void:
	if not camera_controller:
		push_warning("EnsambladorBootstrapper: no hay ningún nodo en el grupo 'camara_principal'. Agregá tu CameraController a ese grupo (panel Node > Groups), o llamá a mano a camera_controller.enter_orbital_mode(larguero).")
		return
	if camera_controller.has_method("enter_orbital_mode"):
		camera_controller.enter_orbital_mode(larguero, Vector3(0, 0.5, 0))
	else:
		push_warning("EnsambladorBootstrapper: el nodo en 'camara_principal' no tiene enter_orbital_mode() — ¿es una copia de CameraController.gd sin el modo orbital agregado?")


func _crear_catalogo() -> void:
	datos_motor = _crear_datos("Motor", DatosPiezaMecanica.PartType.MOTOR, PiezaMotor, Color.ORANGE_RED, Vector3(0.3, 0.3, 0.3))
	datos_engranaje = _crear_datos("Engranaje", DatosPiezaMecanica.PartType.ENGRANAJE, PiezaEngranaje, Color.STEEL_BLUE, Vector3(0.25, 0.25, 0.25))
	datos_rueda = _crear_datos("Rueda", DatosPiezaMecanica.PartType.RUEDA, PiezaRueda, Color.FOREST_GREEN, Vector3(0.35, 0.35, 0.35))


## A propósito salteamos EnsambladorMecanicoUI acá: nada de raycast, nada de
## mouse, nada de socket.is_occupied dependiendo de un click que nunca pasa.
## Esto llama a EnsambladorMecanico.acoplar_pieza() directo, tres veces, para
## aislar si el problema estaba en la física (joints + propagación) o en la
## UI — si ves 3 cajas de colores prendidas de la barra gris al arrancar,
## la física anda. Poné colocar_piezas_automaticamente en false cuando
## quieras volver a probar con clic.
func _colocar_piezas_automaticamente() -> void:
	var motor := ensamblador.acoplar_pieza(socket_motor, datos_motor)
	var engranaje := ensamblador.acoplar_pieza(socket_engranaje, datos_engranaje)
	var rueda := ensamblador.acoplar_pieza(socket_rueda, datos_rueda)
	if motor and engranaje and rueda:
		print("EnsambladorBootstrapper: vehículo armado automáticamente. Si ves 3 cajas de colores sobre la barra gris, la física funcionó — dale al acelerador de ControladorVehiculo y fijate si giran.")
	else:
		push_error("EnsambladorBootstrapper: algo falló acoplando una pieza automática — mirá los mensajes de arriba en la consola (Output), ahí dice cuál.")


## Arma una escena mínima (RigidBody3D + caja de mesh/colisión) por código y
## la empaqueta en un PackedScene — así tenés un DatosPiezaMecanica de
## verdad para probar sin guardar un solo .tscn a mano.
func _crear_datos(nombre: String, tipo: DatosPiezaMecanica.PartType, script: Script, color: Color, tamano: Vector3) -> DatosPiezaMecanica:
	var raiz := RigidBody3D.new()
	raiz.set_script(script)
	raiz.name = nombre

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = tamano
	mesh.mesh = box
	mesh.material_override = _material(color)
	raiz.add_child(mesh)
	mesh.owner = raiz

	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = tamano
	col.shape = box_shape
	raiz.add_child(col)
	col.owner = raiz

	var paquete := PackedScene.new()
	paquete.pack(raiz)

	var datos := DatosPiezaMecanica.new()
	datos.display_name = nombre
	datos.part_type = tipo
	datos.part_scene = paquete
	return datos


func _material(color: Color, transparente: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if transparente:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


func _set_owner_recursivo(nodo: Node, dueno: Node) -> void:
	for hijo in nodo.get_children():
		if hijo.owner == null:
			hijo.owner = dueno
		_set_owner_recursivo(hijo, dueno)
