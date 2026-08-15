extends Node3D

# --- VARIABLES DEL REPOSITORIO ORIGINAL ---
@export var angular_spring_stiffness: float = 4000.0
@export var angular_spring_damping: float = 80.0
@export var max_angular_force: float = 9999.0

@onready var physical_skel : Skeleton3D = $CuerpoRagdoll/EsqueletoFisico
@onready var animated_skel : Skeleton3D = $CerebroIK/EsqueletoAnimado

var physics_bones = []
var ragdoll_mode := false
var current_delta: float

func _ready():
	# 1. Encendemos el ragdoll con retraso seguro
	physical_skel.call_deferred("physical_bones_start_simulation")
	
	# 2. Guardamos todos los huesos físicos
	physics_bones = physical_skel.get_children().filter(func(x): return x is PhysicalBone3D)
	for b in physics_bones:
		b.freeze = false # Forzamos que no esté congelado
		b.collision_layer = 1 # Aseguramos que esté en una capa activa
		b.input_ray_pickable = true # A veces ayuda a despertar el nodo
		print("Hueso despertado: ", b.name)

func _input(_event):
	# Botón de pánico/prueba: Activa o desactiva la fuerza muscular
	if Input.is_action_just_pressed("ui_accept"): # Barra espaciadora por defecto
		ragdoll_mode = not ragdoll_mode
		print("Modo Ragdoll (Físicas puras): ", ragdoll_mode)

func _physics_process(delta):
	current_delta = delta
	
	# --- NUEVO: Sincronización de posición ---
	# Teletransportamos el esqueleto fantasma a donde está el físico para que no se separen
	if physics_bones.size() > 0:
		animated_skel.global_position = physics_bones[0].global_position

# --- LA FÓRMULA EXACTA DEL REPOSITORIO ---
func hookes_law(displacement: Vector3, current_velocity: Vector3, stiffness: float, damping: float) -> Vector3:
	return (stiffness * displacement) - (damping * current_velocity)

func _process(_delta):
	# En _process llamamos a la actualización de músculos (el repo original usaba una señal, esto es más seguro)
	actualizar_musculos()

func actualizar_musculos():
	if ragdoll_mode:
		return # Si está en ragdoll, no aplicamos fuerza muscular, se cae al suelo.

	for b: PhysicalBone3D in physics_bones:
		var bone_id = b.get_bone_id()
		
		# Obtenemos rotaciones
		var target_transform: Transform3D = animated_skel.global_transform * animated_skel.get_bone_global_pose(bone_id)
		var current_transform: Transform3D = physical_skel.global_transform * physical_skel.get_bone_global_pose(bone_id)
		
		# Calculamos diferencia y aplicamos Ley de Hooke
		var rotation_difference: Basis = (target_transform.basis * current_transform.basis.inverse())
		var torque = hookes_law(rotation_difference.get_euler(), b.angular_velocity, angular_spring_stiffness, angular_spring_damping)
		torque = torque.limit_length(max_angular_force)
		
		# Aplicamos la velocidad
		b.angular_velocity += torque * current_delta
