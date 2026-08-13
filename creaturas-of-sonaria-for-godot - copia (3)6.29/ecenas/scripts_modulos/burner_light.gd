extends MeshInstance3D
class_name BurnerLight

@export var burner: BurnerComponent
@export var surface_index: int = 0

@onready var mat_active = preload("res://materiales/luces/luz_verde.tres")
@onready var mat_waiting = preload("res://materiales/luces/luz_roja.tres")

func _process(_delta: float) -> void:
	if burner == null: return
	
	if burner.is_burning:
		set_surface_override_material(surface_index, mat_active)
	else:
		set_surface_override_material(surface_index, mat_waiting)
