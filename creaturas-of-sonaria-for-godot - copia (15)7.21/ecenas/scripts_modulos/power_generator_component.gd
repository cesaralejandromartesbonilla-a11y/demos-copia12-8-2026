extends Node
class_name PowerGeneratorComponent

@export var max_generation_kw: float = 50.0
@export var burner: BurnerComponent
var my_connector = null 

func get_current_generation() -> float:
	if burner != null:
		if burner.is_burning:
			return max_generation_kw
		else:
			return 0.0
			
	return max_generation_kw
