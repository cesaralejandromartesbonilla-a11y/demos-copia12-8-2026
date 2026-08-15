class_name GameEnums
extends RefCounted

enum DamageType { 
	SHARP, 
	CRUSH, 
	FIRE, 
	ICE, 
	ENERGY, 
	PLASMA 
}

enum TargetingMode {
	FIRST,
	LAST,
	STRONG,
	CLOSE
}

enum PlacementType {
	STANDARD,
	PATH,
	WATER
}
