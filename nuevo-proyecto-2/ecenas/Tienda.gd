extends Node

var dinero_jugador: int = 1000
@onready var punto_spawn = $SpawnPoint # Asegúrate de tener un Marker3D como hijo

func comprar_item(item: Item):
	if item == null: 
		print("Error: El ítem recibido es nulo")
		return
		
	if dinero_jugador >= item.precio:
		dinero_jugador -= item.precio
		var instancia = item.escena_visual.instantiate()
		get_tree().current_scene.add_child(instancia)
		instancia.global_position = punto_spawn.global_position
		print("Comprado: ", item.nombre, ". Dinero restante: ", dinero_jugador)
	else:
		print("No tienes suficiente dinero para: ", item.nombre)

func _ready():
	$Control.visible = false  # Desaparece


func _on_area_3d_body_entered(_body: Node3D) -> void:
	$Control.visible = true   # Aparece
	print("entro")


func _on_area_3d_body_exited(_body: Node3D) -> void:
	$Control.visible = false  # Desaparece
	print("salio")
