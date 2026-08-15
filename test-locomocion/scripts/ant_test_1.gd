extends Node3D

# --- MOVIMIENTO ---
const SPEED = 50
const DAMPING = 0.9

# --- RESORTES (MÚSCULOS) ---
@export var angular_spring_stiffness: float = 1000.0 # Bajé esto a 1000. 4000 es mucho para una hormiga
@export var angular_spring_damping: float = 80.0
@export var max_angular_force: float = 9999.0

@export var ragdoll_mode := false
var physics_bones = [] 
var current_delta:float

# --- REFERENCIAS ---
@onready var physical_skel : Skeleton3D = $EsqueletoFisico
@onready var bone_simulator = $EsqueletoFisico/PhysicalBoneSimulator3D 
@onready var animated_skel : Skeleton3D = $CerebroIK/EsqueletoAnimado
@onready var physical_bone_body : PhysicalBone3D = $"EsqueletoFisico/PhysicalBoneSimulator3D/Physical Bone Body" # Asegúrate de que el nombre coincida

func _ready():
	# 1. Despertamos las físicas
	bone_simulator.physical_bones_start_simulation()
	physics_bones = bone_simulator.get_children().filter(func(x): return x is PhysicalBone3D)
	print("¡Huesos físicos listos!: ", physics_bones.size())
	
	# 2. Iniciamos el IK del Fantasma automáticamente
	for child in animated_skel.get_children():
		if child is SkeletonIK3D:
			child.start()

func _input(_event):
	if Input.is_action_just_pressed("press_r"): 
		ragdoll_mode = not ragdoll_mode
		print("Modo Ragdoll: ", ragdoll_mode)

func _physics_process(delta):
	current_delta = delta
	
	# 3. SINCRONIZACIÓN: El Fantasma(IK) debe teletransportarse a donde está el cuerpo real
	if is_instance_valid(physical_bone_body):
		animated_skel.global_position = physical_bone_body.global_position

	if not ragdoll_mode:
		# --- LÓGICA DE CAMINAR (Empuja el cuerpo físico) ---
		var dir = Vector3.ZERO
		if Input.is_action_pressed("press_w"): dir += animated_skel.global_transform.basis.z
		if Input.is_action_pressed("press_a"): dir += animated_skel.global_transform.basis.x
		if Input.is_action_pressed("press_d"): dir -= animated_skel.global_transform.basis.x
		if Input.is_action_pressed("press_s"): dir -= animated_skel.global_transform.basis.z
		
		if dir != Vector3.ZERO:
			dir = dir.normalized()
			physical_bone_body.linear_velocity += dir * SPEED * delta
			
		# Fricción para que no resbale como hielo
		physical_bone_body.linear_velocity *= Vector3(DAMPING, 1, DAMPING)

		# --- LEY DE HOOKE (MÚSCULOS) ---
		for b:PhysicalBone3D in physics_bones:
			var bone_id_phys = b.get_bone_id()
			var bone_name = physical_skel.get_bone_name(bone_id_phys)
			var bone_id_anim = animated_skel.find_bone(bone_name)
			
			if bone_id_anim != -1: 
				var target_transform: Transform3D = animated_skel.global_transform * animated_skel.get_bone_global_pose(bone_id_anim)
				var current_transform: Transform3D = physical_skel.global_transform * physical_skel.get_bone_global_pose(bone_id_phys)
				
				var rotation_difference: Basis = (target_transform.basis * current_transform.basis.inverse())
				var torque = hookes_law(rotation_difference.get_euler(), b.angular_velocity, angular_spring_stiffness, angular_spring_damping)
				torque = torque.limit_length(max_angular_force)
				
				b.angular_velocity += torque * current_delta

func hookes_law(displacement: Vector3, current_velocity: Vector3, stiffness: float, damping: float) -> Vector3:
	return (stiffness * displacement) - (damping * current_velocity)
