extends Area3D
class_name PhysicalDropZone

@export var target_inventory: InventoryComponent 

func _ready() -> void:
	# Detectar cuando un objeto físico (RigidBody) entra en esta área
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	# Comprobamos si lo que cayó es un item del mundo (Ajusta 'PickableItem' a la clase que uses)
	if body is PickableItem and target_inventory:
		
		# Si el inventario acepta este item...
		if target_inventory.add_item(body.data):
			print("Item succionado por la máquina: ", body.data.item_name)
			body.queue_free() # Destruimos el modelo 3D porque ya está "dentro" de la máquina
		else:
			print("La máquina está llena o no acepta este tipo de objeto.")
