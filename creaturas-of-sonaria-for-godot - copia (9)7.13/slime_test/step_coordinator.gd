extends Node
class_name StepCoordinator

@export var legs: Array[LegStepper]

func _process(_delta):
	var group_a_stepping = false
	var group_b_stepping = false
	
	# 0. Limpieza en tiempo real: Eliminamos las piernas que hayan sido destruidas por el TransformationModule
	for i in range(legs.size() - 1, -1, -1):
		if not is_instance_valid(legs[i]):
			legs.remove_at(i)
	
	# Si no hay piernas, no hacemos nada para evitar errores matemáticos
	if legs.is_empty():
		return
	
	# 1. Detectar si alguna extremidad está actualmente viajando por el aire
	for leg in legs:
		if leg.is_stepping:
			if leg.step_group == 0:
				group_a_stepping = true
			else:
				group_b_stepping = true
				
	# 2. Mantener bloqueo estricto si un grupo ya está en proceso de dar un paso
	if group_a_stepping or group_b_stepping:
		for leg in legs:
			if leg.step_group == 0:
				leg.can_step = not group_b_stepping
			else:
				leg.can_step = not group_a_stepping
		return 
		
	# 3. Si todos están apoyados, leemos las urgencias unificadas de las piernas
	var max_urgency_a: float = -999.0
	var max_urgency_b: float = -999.0
	
	for leg in legs:
		if leg.step_group == 0 and leg.urgency > max_urgency_a:
			max_urgency_a = leg.urgency
		elif leg.step_group == 1 and leg.urgency > max_urgency_b:
			max_urgency_b = leg.urgency
			
	# 4. Ceder el turno únicamente al grupo que tenga la mayor necesidad real
	var a_has_priority = max_urgency_a > max_urgency_b
	
	for leg in legs:
		if leg.step_group == 0:
			leg.can_step = a_has_priority
		else:
			leg.can_step = not a_has_priority
