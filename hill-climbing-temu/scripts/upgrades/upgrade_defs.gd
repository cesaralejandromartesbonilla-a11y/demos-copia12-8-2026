class_name UpgradeDefs
extends RefCounted

enum Type {
	ENGINE,
	SUSPENSION,
	TANK,
}

const MAX_LEVEL: int = 5

const NAMES: Dictionary = {
	Type.ENGINE: "Motor",
	Type.SUSPENSION: "Suspensión",
	Type.TANK: "Tanque",
}

const DESCRIPTIONS: Dictionary = {
	Type.ENGINE: "+12% potencia por nivel",
	Type.SUSPENSION: "Mejor absorción de impactos",
	Type.TANK: "+15% combustible por nivel",
}

const BASE_COSTS: Dictionary = {
	Type.ENGINE: 50,
	Type.SUSPENSION: 40,
	Type.TANK: 45,
}

const COST_PER_LEVEL: Dictionary = {
	Type.ENGINE: 35,
	Type.SUSPENSION: 30,
	Type.TANK: 32,
}


static func get_cost(type: Type, current_level: int) -> int:
	if current_level >= MAX_LEVEL:
		return -1

	return int(BASE_COSTS[type]) + current_level * int(COST_PER_LEVEL[type])


static func get_display_name(type: Type) -> String:
	return NAMES.get(type, "")


static func get_description(type: Type) -> String:
	return DESCRIPTIONS.get(type, "")
