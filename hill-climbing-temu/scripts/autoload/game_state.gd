extends Node

const SAVE_PATH := "user://save.json"
const BASE_STATS_PATH := "res://resources/vehicle_stats.tres"

var best_distance: float = 0.0
var total_coins: int = 0

var current_run_distance: float = 0.0
var current_run_coins: int = 0
var death_reason: String = ""

var selected_vehicle_id: String = "jeep"
var selected_map_id: String = "countryside"
var unlocked_vehicles: Array[String] = ["jeep"]
var unlocked_maps: Array[String] = ["countryside"]
var vehicle_upgrades: Dictionary = {}
var map_best_distances: Dictionary = {}

signal run_coins_changed(amount: int)
signal garage_changed()


func _ready() -> void:
	load_game()


func reset_run() -> void:
	current_run_distance = 0.0
	current_run_coins = 0
	death_reason = ""
	run_coins_changed.emit(current_run_coins)


func add_run_coins(amount: int) -> void:
	if amount <= 0:
		return

	current_run_coins += amount
	run_coins_changed.emit(current_run_coins)


func end_run(distance: float, coins: int) -> void:
	current_run_distance = distance
	current_run_coins = coins

	var map_key := selected_map_id
	var previous_best: float = float(map_best_distances.get(map_key, 0.0))
	if distance > previous_best:
		map_best_distances[map_key] = distance

	if distance > best_distance:
		best_distance = distance

	total_coins += coins
	save_game()


func is_vehicle_unlocked(vehicle_id: String) -> bool:
	return vehicle_id in unlocked_vehicles


func is_map_unlocked(map_id: String) -> bool:
	return map_id in unlocked_maps


func can_unlock_vehicle(vehicle_id: String) -> bool:
	if is_vehicle_unlocked(vehicle_id):
		return false

	var def := ContentRegistry.get_vehicle(vehicle_id)
	if def == null or not def.available:
		return false

	return total_coins >= def.unlock_cost


func can_unlock_map(map_id: String) -> bool:
	if is_map_unlocked(map_id):
		return false

	var def := ContentRegistry.get_map(map_id)
	if def == null or not def.available:
		return false

	return total_coins >= def.unlock_cost


func unlock_vehicle(vehicle_id: String) -> bool:
	if not can_unlock_vehicle(vehicle_id):
		return false

	var def := ContentRegistry.get_vehicle(vehicle_id)
	total_coins -= def.unlock_cost
	unlocked_vehicles.append(vehicle_id)
	selected_vehicle_id = vehicle_id
	save_game()
	garage_changed.emit()
	return true


func unlock_map(map_id: String) -> bool:
	if not can_unlock_map(map_id):
		return false

	var def := ContentRegistry.get_map(map_id)
	total_coins -= def.unlock_cost
	unlocked_maps.append(map_id)
	selected_map_id = map_id
	save_game()
	garage_changed.emit()
	return true


func select_vehicle(vehicle_id: String) -> bool:
	if not is_vehicle_unlocked(vehicle_id):
		return false

	var def := ContentRegistry.get_vehicle(vehicle_id)
	if def == null or not def.available:
		return false

	selected_vehicle_id = vehicle_id
	save_game()
	garage_changed.emit()
	return true


func select_map(map_id: String) -> bool:
	if not is_map_unlocked(map_id):
		return false

	var def := ContentRegistry.get_map(map_id)
	if def == null or not def.available:
		return false

	selected_map_id = map_id
	save_game()
	garage_changed.emit()
	return true


func get_vehicle_upgrade_levels(vehicle_id: String) -> Dictionary:
	if not vehicle_upgrades.has(vehicle_id):
		vehicle_upgrades[vehicle_id] = {
			"engine": 0,
			"suspension": 0,
			"tank": 0,
		}
	return vehicle_upgrades[vehicle_id]


func get_upgrade_level(type: UpgradeDefs.Type, vehicle_id: String = "") -> int:
	if vehicle_id.is_empty():
		vehicle_id = selected_vehicle_id

	var levels := get_vehicle_upgrade_levels(vehicle_id)
	match type:
		UpgradeDefs.Type.ENGINE:
			return int(levels.get("engine", 0))
		UpgradeDefs.Type.SUSPENSION:
			return int(levels.get("suspension", 0))
		UpgradeDefs.Type.TANK:
			return int(levels.get("tank", 0))
		_:
			return 0


func get_upgrade_cost(type: UpgradeDefs.Type, vehicle_id: String = "") -> int:
	return UpgradeDefs.get_cost(type, get_upgrade_level(type, vehicle_id))


func can_purchase_upgrade(type: UpgradeDefs.Type, vehicle_id: String = "") -> bool:
	if vehicle_id.is_empty():
		vehicle_id = selected_vehicle_id

	if not is_vehicle_unlocked(vehicle_id):
		return false

	var cost := get_upgrade_cost(type, vehicle_id)
	return cost >= 0 and total_coins >= cost


func purchase_upgrade(type: UpgradeDefs.Type, vehicle_id: String = "") -> bool:
	if vehicle_id.is_empty():
		vehicle_id = selected_vehicle_id

	if not can_purchase_upgrade(type, vehicle_id):
		return false

	var cost := get_upgrade_cost(type, vehicle_id)
	total_coins -= cost

	var levels := get_vehicle_upgrade_levels(vehicle_id)
	match type:
		UpgradeDefs.Type.ENGINE:
			levels["engine"] = int(levels.get("engine", 0)) + 1
		UpgradeDefs.Type.SUSPENSION:
			levels["suspension"] = int(levels.get("suspension", 0)) + 1
		UpgradeDefs.Type.TANK:
			levels["tank"] = int(levels.get("tank", 0)) + 1

	vehicle_upgrades[vehicle_id] = levels
	save_game()
	garage_changed.emit()
	return true


func get_selected_vehicle() -> VehicleDef:
	return ContentRegistry.get_vehicle(selected_vehicle_id)


func get_selected_map() -> MapDef:
	return ContentRegistry.get_map(selected_map_id)


func get_map_best_distance(map_id: String) -> float:
	return float(map_best_distances.get(map_id, 0.0))


func build_vehicle_stats(vehicle_id: String = "") -> VehicleStats:
	if vehicle_id.is_empty():
		vehicle_id = selected_vehicle_id

	var vehicle_def := ContentRegistry.get_vehicle(vehicle_id)
	var stats_path := BASE_STATS_PATH
	if vehicle_def != null and not vehicle_def.stats_path.is_empty():
		stats_path = vehicle_def.stats_path

	var base_stats := load(stats_path) as VehicleStats
	var stats: VehicleStats = base_stats.duplicate() as VehicleStats

	var engine_level := get_upgrade_level(UpgradeDefs.Type.ENGINE, vehicle_id)
	var suspension_level := get_upgrade_level(UpgradeDefs.Type.SUSPENSION, vehicle_id)
	var tank_level := get_upgrade_level(UpgradeDefs.Type.TANK, vehicle_id)

	stats.engine_force *= 1.0 + engine_level * 0.12
	stats.suspension_damping *= 1.0 + suspension_level * 0.18
	stats.suspension_stiffness *= maxf(0.55, 1.0 - suspension_level * 0.07)
	stats.fuel_capacity *= 1.0 + tank_level * 0.15

	return stats


func save_game() -> void:
	var data := {
		"best_distance": best_distance,
		"total_coins": total_coins,
		"selected_vehicle_id": selected_vehicle_id,
		"selected_map_id": selected_map_id,
		"unlocked_vehicles": unlocked_vehicles,
		"unlocked_maps": unlocked_maps,
		"vehicle_upgrades": vehicle_upgrades,
		"map_best_distances": map_best_distances,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if not parsed is Dictionary:
		return

	best_distance = float(parsed.get("best_distance", 0.0))
	total_coins = int(parsed.get("total_coins", 0))
	selected_vehicle_id = str(parsed.get("selected_vehicle_id", ContentRegistry.get_default_vehicle_id()))
	selected_map_id = str(parsed.get("selected_map_id", ContentRegistry.get_default_map_id()))

	unlocked_vehicles = _to_string_array(parsed.get("unlocked_vehicles", ["jeep"]))
	unlocked_maps = _to_string_array(parsed.get("unlocked_maps", ["countryside"]))
	map_best_distances = parsed.get("map_best_distances", {})

	if parsed.has("vehicle_upgrades"):
		vehicle_upgrades = parsed.get("vehicle_upgrades", {})
	else:
		_migrate_legacy_upgrades(parsed)


func _migrate_legacy_upgrades(parsed: Dictionary) -> void:
	vehicle_upgrades["jeep"] = {
		"engine": int(parsed.get("upgrade_engine", 0)),
		"suspension": int(parsed.get("upgrade_suspension", 0)),
		"tank": int(parsed.get("upgrade_tank", 0)),
	}


func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			result.append(str(item))
	return result
