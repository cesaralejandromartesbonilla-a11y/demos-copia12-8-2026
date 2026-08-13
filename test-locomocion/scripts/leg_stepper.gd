extends Marker3D
class_name LegStepper

@export var raycast_sensor: RayCast3D # Usaremos su posición como "Centro Ideal"
@export var step_distance: float = 0.5
@export var step_height: float = 0.2
@export var step_duration: float = 0.15
@export_enum("Grupo A", "Grupo B") var step_group: int = 0
@export var step_randomness: float = 0.1 

# --- NUEVAS VARIABLES DE SUPERVIVENCIA ---
@export var search_radius: float = 10.0 # Qué tan lejos puede estirar la pata para buscar
@export_flags_3d_physics var safe_terrain_mask: int = 1 # Busca solo en la Capa 1 (Suelo Seguro)

var target_position: Vector3
var is_stepping: bool = false
var can_step: bool = false

func _ready():
	target_position = global_position
	step_distance += randf_range(-step_randomness, step_randomness)

func _process(delta):
	# 1. Buscamos el mejor lugar para pisar usando nuestro "radar"
	var safe_hit = find_best_foothold(raycast_sensor.global_position)
	
	# 2. Si safe_hit no es INF, encontramos un suelo válido
	if safe_hit != Vector3.INF:
		if global_position.distance_to(safe_hit) > step_distance and not is_stepping and can_step:
			step_to(safe_hit)
			
	if not is_stepping:
		global_position = global_position.lerp(target_position, delta * 25.0)

# --- EL RADAR DE SUPERVIVENCIA (VERSIÓN 2.0) ---
func find_best_foothold(center_pos: Vector3) -> Vector3:
	var space_state = get_world_3d().direct_space_state
	var best_point = Vector3.INF
	var min_distance = 999.0
	
	# Empezamos con el punto central ideal
	var offsets = [Vector3.ZERO]
	
	# 1. MEJORA: Anillos concéntricos. 
	# En lugar de un solo círculo, hacemos 2 (uno a la mitad del radio y otro al máximo)
	var rings = 2 
	for r in range(1, rings + 1):
		var current_radius = (search_radius / float(rings)) * r
		for i in range(8): # 8 puntos por anillo
			var angle = i * (PI / 4.0)
			offsets.append(Vector3(cos(angle) * current_radius, 0, sin(angle) * current_radius))
			
	# 2. MEJORA: Aplanamos el centro a 2D para medir la distancia real sin importar la altura
	var center_pos_2d = Vector2(center_pos.x, center_pos.z)
		
	# Disparamos los rayos
	for offset in offsets:
		var ray_origin = center_pos + offset
		ray_origin.y += 1.0 
		var ray_end = ray_origin + (Vector3.DOWN * 3.0) 
		
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		query.collision_mask = safe_terrain_mask 
		
		var result = space_state.intersect_ray(query)
		
		if result:
			# Aplanamos el punto de colisión a 2D
			var hit_pos_2d = Vector2(result.position.x, result.position.z)
			
			# Calculamos la distancia horizontal
			var horizontal_dist = center_pos_2d.distance_to(hit_pos_2d)
			
			# Si este punto está más cerca del centro ideal que el anterior, lo guardamos
			if horizontal_dist < min_distance:
				min_distance = horizontal_dist
				best_point = result.position
				
	return best_point

func step_to(new_position: Vector3):
	is_stepping = true
	target_position = new_position + Vector3(randf_range(-0.02, 0.02), 0, randf_range(-0.02, 0.02))
	
	var half_way = global_position.lerp(target_position, 0.5)
	half_way.y += step_height
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", half_way, step_duration / 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", target_position, step_duration / 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.finished.connect(func(): is_stepping = false)
