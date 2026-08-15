extends Area3D

@export var coin_value: int = 10

func _ready() -> void:
	# Conectamos la señal de que algo entró en la moneda
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	# Verificamos si lo que tocó la moneda es el jugador (tu criatura)
	if body.is_in_group("player") or body.has_method("quick_save"):
		InventoryManager.add_coins(coin_value)
		# Podrías poner aquí un efecto de sonido o partículas antes de borrarla
		queue_free()
