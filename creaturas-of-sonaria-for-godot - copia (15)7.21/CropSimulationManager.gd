extends Node
class_name CropSimulationManager

var registered_crops: Array[Node3D] = []

func _ready() -> void:
	var weather = get_node_or_null("/root/WeatherManager")
	if weather:weather.time_changed.connect(_on_weather_time_tick)
	add_to_group("crop_manager")

func register_free_crop(crop_node: Node3D) -> void:
	if not registered_crops.has(crop_node):registered_crops.append(crop_node)

func unregister_free_crop(crop_node: Node3D) -> void:
	if registered_crops.has(crop_node):registered_crops.erase(crop_node)

func _on_weather_time_tick(current_time: float) -> void:
	if registered_crops.is_empty(): return
	var tick_energy: float = 1.0 
	for i in range(registered_crops.size() - 1, -1, -1):
		var crop = registered_crops[i]
		if is_instance_valid(crop):
			if crop.has_method("process_tick"):crop.process_tick(tick_energy)
		else:registered_crops.remove_at(i)
