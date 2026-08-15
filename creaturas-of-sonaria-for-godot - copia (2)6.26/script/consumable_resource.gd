extends Area3D
class_name ConsumableResource

@export var max_capacity: float = 100.0
@export var current_capacity: float = 100.0
@export var is_infinite: bool = false # Actívalo para lagos de agua

func _ready():
	current_capacity = max_capacity

# Esta función devuelve cuánta comida realmente pudiste sacar este frame
func extract_resource(requested_amount: float) -> float:
	if is_infinite:
		return requested_amount
		
	if current_capacity <= 0:
		return 0.0
		
	var amount_given = min(requested_amount, current_capacity)
	current_capacity -= amount_given
	
	# Efecto visual opcional: encoger la comida a medida que se agota
	var scale_factor = current_capacity / max_capacity
	scale = Vector3(scale_factor, scale_factor, scale_factor)
	
	if current_capacity <= 0:
		queue_free() # Destruye el objeto cuando se acaba la comida
		
	return amount_given
