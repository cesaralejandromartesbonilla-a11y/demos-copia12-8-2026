extends VehicleBody3D # O RigidBody3D según el caso

@export var tipo_accesorio: String = "Remolque"
var acoplado: bool = false
var vehiculo_padre: Node3D = null

# Esta función la llamará el camión cuando presiones "F" (interact)
func acoplar_a_camion(camion: Node3D, punto_union: Marker3D):
	acoplado = true
	vehiculo_padre = camion
	
	# Desactivamos colisiones con el camión para evitar que salgan volando
	add_collision_exception_with(camion)
	
	# Usamos el Joint del camión para la unión física
	var joint = camion.get_node("PinJoint3D")
	joint.node_a = camion.get_path()
	joint.node_b = self.get_path()
	joint.global_position = punto_union.global_position
	
	print("Accesorio tipo ", tipo_accesorio, " acoplado.")

func desacoplar():
	if vehiculo_padre:
		remove_collision_exception_with(vehiculo_padre)
		var joint = vehiculo_padre.get_node("PinJoint3D")
		joint.node_a = NodePath("")
		joint.node_b = NodePath("")
		
		acoplado = false
		vehiculo_padre = null
		print("Accesorio liberado.")
