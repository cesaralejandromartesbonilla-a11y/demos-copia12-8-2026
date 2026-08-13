extends Area3D
class_name SocketMecanico

## Punto de anclaje mecánico sobre el larguero. Reemplaza a InteractiveSocket
## (proyecto de criaturas): ese representaba un hueso, este representa dónde
## y con qué orientación se crea el HingeJoint3D al acoplar una pieza.
##
## El eje +Z local del socket es siempre el eje de giro de la pieza que se
## acople acá — mismo criterio que ya usás en ModuloSuspension.gd
## (global_transform.basis.z como eje de bisagra). Orientá el nodo en el
## editor para que +Z apunte en la dirección de giro que querés.
##
## Recordá poner un collision_layer propio acá (ej. capa 10) y usar el mismo
## valor como collision_mask del raycast en EnsambladorMecanicoUI — si no,
## el raycast no lo va a detectar.

@export var socket_name: String = ""
var is_occupied: bool = false

func _ready() -> void:
	if get_children().is_empty():
		_generar_sensor()
	if collision_layer == 0:
		push_warning("SocketMecanico '%s': collision_layer en 0 — el raycast del ensamblador no lo va a encontrar." % socket_name)

func _generar_sensor(radio: float = 0.3) -> void:
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radio
	collision.shape = sphere
	add_child(collision)
