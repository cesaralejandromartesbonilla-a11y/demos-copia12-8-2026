extends Area3D
class_name WeatherEntity

@export var tornado_scene: PackedScene
@export var max_lifetime: float = 600.0 # 10 minutos de vida máxima
@export var map_radius: float = 300.0   # Distancia máxima del centro antes de regresar

var category: int = 1
var move_direction: Vector3 = Vector3.ZERO
var speed: float = 2.0
var change_direction_timer: float = 0.0
var age: float = 0.0

func _ready():
	# Dirección inicial aleatoria
	_pick_new_direction()
	area_entered.connect(_on_area_entered)
	
	# Añadimos a grupo para que otras nubes nos encuentren
	add_to_group("weather_entity")

func _physics_process(delta: float):
	# 1. Movimiento básico
	global_position += move_direction * speed * delta
	
	# 2. Lógica de Viento (Cada 30 segundos)
	change_direction_timer += delta
	if change_direction_timer >= 30.0:
		change_direction_timer = 0.0
		_pick_new_direction()
	
	# 3. Comportamiento de "Imán" o Retorno al Mapa
	_check_boundaries(delta)
	
	# 4. Envejecimiento y Disipación
	age += delta
	if age > max_lifetime * 0.8: # Empezar a encogerse al llegar al 80% de vida
		var shrink_factor = 1.0 - ((age - (max_lifetime * 0.8)) / (max_lifetime * 0.2))
		scale = Vector3(shrink_factor, shrink_factor, shrink_factor) * (1.0 + (category * 0.3))
		
	if age >= max_lifetime:
		queue_free()

func _pick_new_direction():
	# Crea un vector aleatorio y lo mezcla un poco con el actual para que no sea un giro brusco
	var random_v = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	move_direction = (move_direction + random_v).normalized()

func _check_boundaries(delta: float):
	# Si la nube se aleja mucho del centro (0,0,0), la obligamos a girar hacia el centro
	var distance_from_center = global_position.distance_to(Vector3.ZERO)
	
	if distance_from_center > map_radius:
		var direction_to_center = (Vector3.ZERO - global_position).normalized()
		# Usamos lerp para que el giro hacia el centro sea suave y natural
		move_direction = move_direction.lerp(direction_to_center, delta * 0.5).normalized()

func _on_area_entered(area: Area3D):
	if area.is_in_group("weather_entity") and area is WeatherEntity:
		# Solo una nube procesa la fusión para evitar errores
		if get_instance_id() < area.get_instance_id(): return
		
		print("Fusión detectada: ", category, " + ", area.category)
		category += area.category
		
		# Al fusionarse, la nube "se renueva" y recupera tiempo de vida
		age = max(0, age - 120.0) 
		
		# Crecer visualmente
		var target_scale = 1.0 + (category * 0.4)
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector3(target_scale, target_scale, target_scale), 1.5).set_trans(Tween.TRANS_SINE)
		
		area.queue_free()
		
		if category >= 3:
			_spawn_tornado()

func _spawn_tornado():
	if tornado_scene:
		var tornado = tornado_scene.instantiate()
		get_tree().current_scene.add_child(tornado)
		tornado.global_position = global_position
		# El tornado puede ser más rápido o errático
		if "category" in tornado:
			tornado.category = category
	queue_free()
