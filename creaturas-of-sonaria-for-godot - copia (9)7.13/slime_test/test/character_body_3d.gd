extends CharacterBody3D

var active_limbs: Array = [] # Requerido por _assemble_modular_creature
@export var collision_shape: CollisionShape3D

func register_limb(limb): pass # Requerido si tus piezas registran lógica
func move_hold_position_to(marker): pass
