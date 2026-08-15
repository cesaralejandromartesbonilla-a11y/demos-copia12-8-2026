extends Marker3D
class_name ArmTracker

@export var tracking_speed: float = 15.0
@export var rest_speed: float = 8.0
@export var max_reach: float = 2.0 # El largo máximo de tu brazo extendido

var rest_anchor: Node3D = null
var active_target: Vector3 = Vector3.INF

func _ready():
	set_as_top_level(true)
	rest_anchor = get_parent() 

func _physics_process(delta):
	if active_target != Vector3.INF:
		var target_pos = active_target
		
		if is_instance_valid(rest_anchor):
			var dist_to_target = rest_anchor.global_position.distance_to(active_target)
			if dist_to_target > max_reach:
				# Calculamos la dirección y ponemos un tope a la distancia
				var direction = rest_anchor.global_position.direction_to(active_target)
				target_pos = rest_anchor.global_position + (direction * max_reach)
		
		# Movemos el marcador (mano) hacia el objetivo clampeado
		global_position = global_position.lerp(target_pos, delta * tracking_speed)

func set_target(new_pos: Vector3):
	active_target = new_pos

func clear_target():
	active_target = Vector3.INF
