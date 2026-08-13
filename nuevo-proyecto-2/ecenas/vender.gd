extends Button

@export var item_a_generar: Item # Aquí arrastras tu archivo .tres
@export var tienda: Node       # Aquí arrastras el nodo Tienda desde la escena

func _ready():
	# Conectamos el click del botón a la función de la tienda
	# Usamos 'bind' para que el botón le envíe su propio ítem al hacer click
	if tienda and item_a_generar:
		self.pressed.connect(tienda.comprar_item.bind(item_a_generar))
