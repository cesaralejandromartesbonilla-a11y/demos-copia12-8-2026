# UI_Garaje.gd
extends CanvasLayer

@onready var label_dinero = $LabelDinero

func _process(_delta):
	label_dinero.text = "Dinero: $" + str(GestionGaraje.dinero)

func _on_boton_comprar_heavy_pressed():
	# En lugar de buscar por ruta "/root/Mundo...", buscamos en el grupo
	var nodo_garaje = get_tree().get_first_node_in_group("garajes")
	
	if nodo_garaje:
		nodo_garaje.intentar_cambiar_vehiculo("Camioneta_Heavy")
	else:
		print("ERROR: No se encontró ningún nodo en el grupo 'garajes'")
