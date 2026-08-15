extends Node3D

# --- CONFIGURACIÓN DE MÚSCULOS ---
@export var angular_spring_stiffness: float = 1000.0 
@export var angular_spring_damping: float = 120.0 # Subimos esto un poco para estabilizar
@export var max_angular_force: float = 1500.0     # ¡EL SALVAVIDAS ANTI-TORNADO!
@export var ragdoll_mode := false
@export var altura_deseada: float = 1.0

@export var cerebro_ik: Node3D 

@onready var physical_skel: Skeleton3D = $"."
@onready var bone_simulator: PhysicalBoneSimulator3D = $PhysicalBoneSimulator3D
@onready var hueso_central: PhysicalBone3D = $"PhysicalBoneSimulator3D/Physical Bone Bone"

# --- MOVIMIENTO ---
const SPEED = 30.0
const DAMPING = 0.9

var physics_bones = []
var animated_skel: Skeleton3D
var current_delta: float

func _ready():
	if cerebro_ik:
		animated_skel = cerebro_ik.get_node("EsqueletoAnimado")
		
	bone_simulator.physical_bones_start_simulation()
	physics_bones = bone_simulator.get_children().filter(func(x): return x is PhysicalBone3D)

func _input(_event):
	# Puedes cambiar "ui_accept" por "press_r" si lo prefieres
	if Input.is_action_just_pressed("ui_accept"): 
		ragdoll_mode = not ragdoll_mode

func _physics_process(delta):
	if not animated_skel or physics_bones.is_empty(): return
	current_delta = delta
	
	# SINCRONIZACIÓN CORREGIDA: Seguimos al cuerpo, pero manteniendo el Cerebro de pie
	if is_instance_valid(hueso_central):
		var pos_cuerpo = hueso_central.global_position
		# El cerebro sigue al cuerpo en X y Z, pero se mantiene "levantado" en Y
		cerebro_ik.global_position = Vector3(pos_cuerpo.x, pos_cuerpo.y + altura_deseada, pos_cuerpo.z)

	if not ragdoll_mode:
		# CONTROLES DE MOVIMIENTO
		var dir = Vector3.ZERO
		if Input.is_action_pressed("press_w"): dir += cerebro_ik.global_transform.basis.z
		if Input.is_action_pressed("press_a"): dir += cerebro_ik.global_transform.basis.x
		if Input.is_action_pressed("press_d"): dir -= cerebro_ik.global_transform.basis.x
		if Input.is_action_pressed("press_s"): dir -= cerebro_ik.global_transform.basis.z
		
		if dir != Vector3.ZERO:
			dir = dir.normalized()
			# Aplicamos la fuerza al hueso central para moverla
			hueso_central.linear_velocity += dir * SPEED * delta
			
		hueso_central.linear_velocity *= Vector3(DAMPING, 1, DAMPING)

	actualizar_musculos()

func actualizar_musculos():
	if ragdoll_mode: return

	for b: PhysicalBone3D in physics_bones:
		var bone_name = physical_skel.get_bone_name(b.get_bone_id())
		var bone_id_anim = animated_skel.find_bone(bone_name)
		
		if bone_id_anim != -1:
			var target_transform = animated_skel.global_transform * animated_skel.get_bone_global_pose(bone_id_anim)
			var current_transform = physical_skel.global_transform * physical_skel.get_bone_global_pose(b.get_bone_id())
			
			var rotation_difference: Basis = (target_transform.basis * current_transform.basis.inverse())
			
			var diff_quat = rotation_difference.get_rotation_quaternion()
			var torque = hookes_law(diff_quat.get_euler(), b.angular_velocity, angular_spring_stiffness, angular_spring_damping)
			
			# ESTO EVITA QUE EXPLOTE AL LEVANTARSE
			torque = torque.limit_length(max_angular_force)
			
			if torque.is_finite():
				b.angular_velocity += torque * current_delta

func hookes_law(displacement: Vector3, current_velocity: Vector3, stiffness: float, damping: float) -> Vector3:
	return (stiffness * displacement) - (damping * current_velocity)
