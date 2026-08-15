extends RefCounted 
class_name PowerGrid

var generators: Array = []
var receivers: Array = []
var connectors: Array = []
var satisfaction: float = 1.0

func update_logic() -> void:
	var supply = 0.0
	var demand = 0.0
	
	for i in range(generators.size() - 1, -1, -1):
		var gen = generators[i]
		if is_instance_valid(gen):
			supply += gen.get_current_generation()
		else:
			generators.remove_at(i)
	
	for i in range(receivers.size() - 1, -1, -1):
		var rec = receivers[i]
		if is_instance_valid(rec):
			if rec.is_machine_running:
				demand += rec.required_kw
		else:
			receivers.remove_at(i)
			
	if demand <= 0:
		satisfaction = 1.0
	else:
		satisfaction = clamp(supply / demand, 0.0, 1.0)
