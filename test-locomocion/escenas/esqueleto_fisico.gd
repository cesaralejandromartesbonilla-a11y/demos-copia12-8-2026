extends Skeleton3D

@onready var physical_skel : Skeleton3D = $"."

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	physical_skel.call_deferred("physical_bones_start_simulation")
