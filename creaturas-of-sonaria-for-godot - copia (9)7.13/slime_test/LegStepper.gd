extends Marker3D
class_name LegStepper

@export var raycast_sensor: RayCast3D 
@export var body_node: CharacterBody3D 
@export var step_distance: float = 0.5
@export var step_height: float = 0.2
@export var step_duration: float = 0.15
@export_enum("Grupo A", "Grupo B") var step_group: int = 0
@export var step_randomness: float = 0.1 
@export var rest_threshold: float = 0.05
@export var step_overshoot: float = 0.5
@export var search_radius: float = 10.0 
@export var search_depth: float = 3.0 
@export_flags_3d_physics var safe_terrain_mask: int = 1 
@export var prediction_factor: float = 0.25 # Tiempo en segundos hacia el futuro

@export var privileged_group: String = "" 
@export var privileged_activation_radius: float = 2.0 

var target_position: Vector3
var is_stepping: bool = false
var can_step: bool = false
var active_privileged_point: Marker3D = null

# --- NUEVA VARIABLE SINCRO ---
var urgency: float = 0.0 

func _ready():
	set_as_top_level(true) 
	target_position = global_position
	step_distance += randf_range(-step_randomness, step_randomness)

func _process(_delta):
	_scan_privileged_points()
	
	var current_intended_target = Vector3.INF
	
	# 1. EVALUACIÓN DE PUNTOS PRIVILEGIADOS (PRIORIDAD ALTA)
	if active_privileged_point and is_instance_valid(active_privileged_point):
		current_intended_target = active_privileged_point.global_position
		urgency = 999.0 
	else:
		# 2. DETERMINAR SI EL CUERPO SE ESTÁ MOVIENDO
		var is_moving = body_node and body_node.velocity.length() > 0.1
		var predicted_center = raycast_sensor.global_position
		
		if is_moving:
			# --- COMPORTAMIENTO DE LOCOMOCIÓN ACTIVA ---
			predicted_center += body_node.velocity * prediction_factor
			
			var move_direction = body_node.velocity.normalized()
			move_direction.y = 0 
			predicted_center += move_direction * (step_distance * step_overshoot)
			
			var safe_hit = find_best_foothold(predicted_center)
			if safe_hit != Vector3.INF:
				current_intended_target = safe_hit
				urgency = global_position.distance_to(safe_hit) - step_distance
			else:
				urgency = -999.0
		else:
			var safe_hit = find_best_foothold(predicted_center)
			if safe_hit != Vector3.INF:
				current_intended_target = safe_hit
				var distance_to_rest = global_position.distance_to(safe_hit)
				
				if distance_to_rest > rest_threshold:
					urgency = distance_to_rest 
				else:
					urgency = -999.0
			else:
				urgency = -999.0

	# 3. EJECUCIÓN DEL PASO O ENCLAVAMIENTO
	if not is_stepping:
		if active_privileged_point and is_instance_valid(active_privileged_point):
			if global_position.distance_to(current_intended_target) > 0.05:
				step_to(current_intended_target, true)
		elif current_intended_target != Vector3.INF and urgency > 0.0 and can_step:
			step_to(current_intended_target, false)
		else:
			# Si está estático y en su lugar, se queda rígidamente clavado aquí
			global_position = target_position

func _scan_privileged_points():
	if privileged_group.is_empty():
		active_privileged_point = null
		return
	var points = get_tree().get_nodes_in_group(privileged_group)
	var closest_point: Marker3D = null
	var min_distance = privileged_activation_radius
	for point in points:
		if point is Marker3D:
			var dist = raycast_sensor.global_position.distance_to(point.global_position)
			if dist < min_distance:
				min_distance = dist
				closest_point = point
	active_privileged_point = closest_point

func find_best_foothold(center_pos: Vector3) -> Vector3:
	var space_state = get_world_3d().direct_space_state
	var best_point = Vector3.INF
	var min_distance = 999.0
	var cone_origin = center_pos + (Vector3.UP * 1.0)
	var target_points = [cone_origin + (Vector3.DOWN * search_depth)] 
	
	var rings = 2 
	for r in range(1, rings + 1):
		var current_radius = (search_radius / float(rings)) * r
		for i in range(8): 
			var angle = i * (PI / 4.0)
			var x_offset = cos(angle) * current_radius
			var z_offset = sin(angle) * current_radius
			target_points.append(cone_origin + Vector3(x_offset, -search_depth, z_offset))
			
	var center_pos_2d = Vector2(center_pos.x, center_pos.z)
	for ray_end in target_points:
		var query = PhysicsRayQueryParameters3D.create(cone_origin, ray_end)
		query.collision_mask = safe_terrain_mask 
		var result = space_state.intersect_ray(query)
		if result:
			var hit_pos_2d = Vector2(result.position.x, result.position.z)
			var horizontal_dist = center_pos_2d.distance_to(hit_pos_2d)
			if horizontal_dist < min_distance:
				min_distance = horizontal_dist
				best_point = result.position
	return best_point

func step_to(new_position: Vector3, is_privileged: bool):
	is_stepping = true
	target_position = new_position
	
	if not is_privileged:
		target_position += Vector3(randf_range(-0.02, 0.02), 0, randf_range(-0.02, 0.02))
	
	var half_way = global_position.lerp(target_position, 0.5)
	half_way.y += step_height
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", half_way, step_duration / 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", target_position, step_duration / 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.finished.connect(func(): is_stepping = false)
