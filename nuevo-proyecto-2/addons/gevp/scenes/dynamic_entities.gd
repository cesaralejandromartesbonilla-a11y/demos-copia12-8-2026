extends Node3D

# Ruta pre-cargada a la escena del objeto Rigidbody3D
const COIN_SCENE: PackedScene = preload("res://auto.tscn")

@onready var dynamic_entities_container = $"."

func _ready():
	# Ejemplo: Instanciar 3 monedas al inicio del juego
	spawn_coin(Vector3(0, 5, 5))
	spawn_coin(Vector3(2, 8, 5))
	spawn_coin(Vector3(-2, 10, 5))

# Función para instanciar un objeto RigidBody3D en el mundo
func spawn_coin(spawn_position: Vector3):
	var new_coin_instance = COIN_SCENE.instantiate()
	
	# Asignar la posición inicial
	new_coin_instance.position = spawn_position
	
	# Añadir al contenedor correcto en el árbol de escenas
	dynamic_entities_container.add_child(new_coin_instance)
	
	# Nota: El script de la moneda ya la añade al grupo "Persistente" en _ready()
	print("Moneda instanciada en: ", spawn_position)
