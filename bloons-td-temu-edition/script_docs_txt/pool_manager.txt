# src/autoload/pool_manager.gd
extends Node

var pools: Dictionary = {}

func get_instance(scene: PackedScene) -> Node2D:
	var scene_id: String = scene.resource_path
	
	if not pools.has(scene_id):
		pools[scene_id] = []
		
	if pools[scene_id].size() > 0:
		var instance: Node2D = pools[scene_id].pop_back()
		if instance.get_parent():
			instance.get_parent().remove_child(instance)
		instance.show()
		instance.set_process(true)
		instance.set_physics_process(true)
		if instance is Area2D:
			instance.set_deferred("monitoring", true)
			instance.set_deferred("monitorable", true)
		return instance
		
	return scene.instantiate()

func return_instance(instance: Node2D, scene_id: String) -> void:
	instance.hide()
	instance.set_process(false)
	instance.set_physics_process(false)
	if instance is Area2D:
		instance.set_deferred("monitoring", false)
		instance.set_deferred("monitorable", false)
		
	if instance.get_parent():
		instance.get_parent().call_deferred("remove_child", instance)
		
	if not pools.has(scene_id):
		pools[scene_id] = []
		
	pools[scene_id].append(instance)
