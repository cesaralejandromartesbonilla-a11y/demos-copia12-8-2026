extends Area3D
class_name PistonMachine

@export_group("Configuración del Pistón")
@export var machine_name: String = "Pistón Lineal"
@export var target_speed: float = 2.0
@export var max_force: float = 200.0

@onready var ui_scene = preload("res://ecenas/mesas/motor_ui.tscn")
@onready var processor: ProcessorComponent = get_node_or_null("ProcessorComponent")

var is_in_use: bool = false
var is_active: bool = false

var joint_velocities: Dictionary = {}

func _ready() -> void:
	add_to_group("estructuras")
	
	# Registramos todos los SliderJoint3D que tenga esta máquina
	for child in get_children():
		if child is SliderJoint3D:
			joint_velocities[child] = 0.0
	
	if processor:
		processor.machine_state_changed.connect(_on_machine_state_changed)
	else:
		print("Error: El Pistón no encontró su ProcessorComponent.")
		
	_set_motor_active(false)

# --- EL MOTOR FÍSICO MANUAL ---
func _physics_process(_delta: float) -> void:
	if not is_active: return
	
	for child in get_children():
		if child is SliderJoint3D and joint_velocities.has(child):
			var speed_multiplier = joint_velocities[child]
			var node_b = child.get_node_or_null(child.node_b)
			
			if node_b is RigidBody3D:
				node_b.sleeping = false
				
				# 1. Obtenemos la dirección exacta del riel en el mundo 3D
				var force_dir = child.global_transform.basis.x.normalized()
				
				# 2. Leemos la velocidad a la que se está moviendo el objeto sobre ese riel
				var current_vel = node_b.linear_velocity.dot(force_dir)
				
				# 3. Calculamos la velocidad objetivo basada en la palanca de la HUD
				var desired_vel = speed_multiplier * target_speed
				
				# 4. Diferencia entre lo que queremos y lo que está pasando
				var vel_error = desired_vel - current_vel
				
				# 5. El pistón aplica fuerza para corregir esa diferencia (freno/acelerador)
				var force_magnitude = vel_error * max_force
				
				# 6. Limitamos la fuerza máxima para evitar que el motor de físicas explote
				force_magnitude = clamp(force_magnitude, -max_force, max_force)
				
				var applied_force = force_dir * force_magnitude
				node_b.apply_central_force(applied_force)

func interact(_player: Node3D) -> void:
	if is_in_use: return
	
	if ui_scene != null and processor != null:
		var ui_instance = ui_scene.instantiate()
		get_tree().current_scene.add_child(ui_instance)
		ui_instance.setup(self, processor)
		is_in_use = true
		ui_instance.tree_exited.connect(func(): is_in_use = false)

func _on_machine_state_changed(new_state: String) -> void:
	match new_state:
		"IDLE", "WORKING":
			_set_motor_active(true)
		"OFF", "NO_FUEL", "NO_POWER", "NO_FLUID", "JAMMED":
			_set_motor_active(false)

func _set_motor_active(active: bool) -> void:
	is_active = active
	if not active:
		# Si se apaga, reseteamos la fuerza de empuje de todos los pistones a 0
		for joint in joint_velocities.keys():
			joint_velocities[joint] = 0.0

# --- FUNCIONES PARA COMUNICARSE CON LA HUD ---
func get_piston_speed(joint: SliderJoint3D) -> float:
	if joint_velocities.has(joint):
		return joint_velocities[joint]
	return 0.0

func set_piston_speed(joint: SliderJoint3D, multiplier: float) -> void:
	if joint_velocities.has(joint):
		joint_velocities[joint] = multiplier
