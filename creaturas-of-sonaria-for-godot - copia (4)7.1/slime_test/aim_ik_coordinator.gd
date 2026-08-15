extends Node3D
class_name AimIKCoordinator

var current_grabbed_object: Node3D = null

func set_grab_target(interactable_node: Node3D):
	current_grabbed_object = interactable_node

func release_grab():
	current_grabbed_object = null

func get_grab_position():
	if is_instance_valid(current_grabbed_object):
		# Si es un ConsumableItem, leemos directamente su propiedad exportada
		if current_grabbed_object is ConsumableItem and current_grabbed_object.grab_point:
			return current_grabbed_object.grab_point.global_position
			
		# Si por alguna razón no tiene la propiedad, usamos el centro del objeto como plan B
		return current_grabbed_object.global_position
		
	return null
