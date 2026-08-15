extends MeshInstance3D
class_name InventoryLight

@export var inventory: InventoryComponent
@export var surface_index: int = 0
@export var max_capacity: int = 10 # La capacidad máxima que consideres para este inventario

@onready var mat_empty = preload("res://materiales/luces/luz_verde.tres")
@onready var mat_half = preload("res://materiales/luces/luz_amarilla.tres")
@onready var mat_full = preload("res://materiales/luces/luz_roja.tres")

func _process(_delta: float) -> void:
	if inventory == null: return
	
	var count = inventory.stored_items.size()
	
	if count == 0:
		set_surface_override_material(surface_index, mat_empty)
	elif count >= max_capacity:
		set_surface_override_material(surface_index, mat_full)
	else:
		set_surface_override_material(surface_index, mat_half)
