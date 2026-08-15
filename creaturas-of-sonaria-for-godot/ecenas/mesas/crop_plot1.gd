extends Area3D

@export var coin_yield: int = 15
@export var grow_time: float = 10.0 # Segundos que tarda en crecer

enum State { EMPTY, GROWING, READY }
var current_state: State = State.EMPTY

@onready var timer = Timer.new()

func _ready() -> void:
	add_child(timer)
	timer.one_shot = true
	timer.timeout.connect(_on_crop_ready)
	
	# Aquí podrías cambiar el color de la tierra o mostrar una plantita vacía
	print("Parcela lista para plantar.")

# Usamos una función de interacción en lugar de body_entered para que no sea automático al pisarlo
func interact(player: Node3D) -> void:
	match current_state:
		State.EMPTY:
			_plant_seed()
		State.GROWING:
			print("Aún está creciendo... Faltan ", int(timer.time_left), " segundos.")
		State.READY:
			_harvest(player)

func _plant_seed() -> void:
	current_state = State.GROWING
	timer.start(grow_time)
	print("Semilla plantada. Esperando a que crezca...")
	# Aquí podrías mostrar el modelo 3D de un brote

func _on_crop_ready() -> void:
	current_state = State.READY
	print("¡Cosecha lista!")
	# Aquí podrías cambiar el modelo 3D al de una planta adulta

func _harvest(_player: Node3D) -> void:
	InventoryManager.add_coins(coin_yield)
	current_state = State.EMPTY
	print("Cosechado. +", coin_yield, " monedas. Parcela vacía de nuevo.")
	
	# Quitamos la planta 
	queue_free()
