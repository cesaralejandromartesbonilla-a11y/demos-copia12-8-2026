extends Node

@export var animated_skeleton: Skeleton3D
@export var physical_skeleton: Skeleton3D

@export var angular_spring_stiffness: float = 4000.0
@export var angular_spring_damping: float = 80.0
@export var max_angular_force: float = 9999.0

var physics_bones: Array = []

func _ready():
	# Encendemos las físicas del esqueleto visible
	physical_skeleton.physical_bones_start_simulation()
	
	# Recolectamos todos los huesos físicos sin importar cuántos sean
	for child in physical_skeleton.get_children():
		if child is PhysicalBone3D:
			physics_bones.append(child)

func hookes_law(displacement: Vector3, current_velocity: Vector3, stiffness: float, damping: float) -> Vector3:
	return (stiffness * displacement) - (damping * current_velocity)

func _physics_process(delta):
	# Iteramos sobre TODOS los huesos de la hormiga
	for b in physics_bones:
		var bone_id = b.get_bone_id()
		
		# Obtenemos hacia dónde apunta el IK en el esqueleto invisible
		var target_transform: Transform3D = animated_skeleton.global_transform * animated_skeleton.get_bone_global_pose(bone_id)
		
		# Obtenemos dónde está el hueso físico caído por la gravedad
		var current_transform: Transform3D = physical_skeleton.global_transform * physical_skeleton.get_bone_global_pose(bone_id)
		
		# Calculamos la diferencia
		var rotation_difference: Basis = (target_transform.basis * current_transform.basis.inverse())
		
		# Aplicamos la matemática del músculo
		var torque = hookes_law(rotation_difference.get_euler(), b.angular_velocity, angular_spring_stiffness, angular_spring_damping)
		torque = torque.limit_length(max_angular_force)
		
		# El hueso físico persigue al hueso IK procedural
		b.angular_velocity += torque * delta
