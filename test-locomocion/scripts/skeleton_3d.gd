extends Skeleton3D

func _ready():
	# Esta línea le dice a Godot: "Apaga las animaciones/IK y enciende las físicas"
	physical_bones_start_simulation()
