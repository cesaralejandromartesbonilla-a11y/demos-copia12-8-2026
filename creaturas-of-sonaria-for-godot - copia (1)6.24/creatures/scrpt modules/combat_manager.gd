extends Node
class_name CombatManager

@export var bite_cooldown: float = 1.0
var can_bite: bool = true

@onready var controller = get_parent()

func perform_mathematical_bite(attacker: CharacterBody3D, damage: float) -> void:
	if not can_bite: return
	
	# 1. Validación de estado global.
	if controller.current_action_mode != controller.ActionMode.EXPLORATION:
		return
		
	can_bite = false
	
	var space_state = attacker.get_world_3d().direct_space_state
	var shape = SphereShape3D.new()
	shape.radius = 1.0 * attacker.scale.x
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = attacker.global_transform.translated_local(Vector3(0, 0.5, -1.5))
	query.exclude = [attacker.get_rid()]
	query.collide_with_areas = true
	
	var results = space_state.intersect_shape(query)
	for res in results:
		var target = res.collider
		if target.has_method("take_damage"):
			target.take_damage(damage)

	await get_tree().create_timer(bite_cooldown).timeout
	can_bite = true
