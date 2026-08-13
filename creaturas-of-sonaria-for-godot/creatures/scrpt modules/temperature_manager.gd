extends Node
class_name TemperatureManager

@onready var survival = $"../SurvivalManager"
@onready var evo_manager = $"../EvolutionManager"
@onready var controller = $".."
@onready var model_holder = $"../ModelHolder"

# Arrastra tu escena del cubo de hielo aquí en el inspector de Godot
@export var ice_cube_scene: PackedScene 
@export var cold_effect_scene: PackedScene # Arrastra aquí tu escena de daño por frío
var effect_timer: float = 0.5 
var internal_temperature: float = 50.0

# Stats de Evolución
var heat_insulation: float = 1.0
var cold_insulation: float = 1.0
var recovery_speed: float = 1.0

# Variables para la mecánica de congelamiento
var current_ice_cube: Node3D = null
var is_frozen: bool = false
signal temp_changed(new_temp: float)

func _process(delta: float) -> void:
	if not survival or survival.is_dead: return
	_update_stats_from_evolution()
	_process_internal_temp(delta)
	_apply_temperature_consequences(delta)

func _update_stats_from_evolution():
	var stage = evo_manager._get_current_stage()
	if stage:
		heat_insulation = stage.get("heat_insulation") if stage.get("heat_insulation") != null else 1.0
		cold_insulation = stage.get("cold_insulation") if stage.get("cold_insulation") != null else 1.0
		recovery_speed = stage.get("recovery_speed") if stage.get("recovery_speed") != null else 1.0

func _process_internal_temp(delta: float):
	var env_manager = $"../EnvironmentManager"
	if not env_manager: return
	
	var ambient_temp = env_manager.ambient_target_temp
	var difference = ambient_temp - internal_temperature
	
	if abs(difference) < 0.1:
		internal_temperature = ambient_temp # ¡SNAP! Lo forzamos a llegar exacto
	else:
		var change_rate = 0.0
		if ambient_temp > 55: change_rate = (difference / heat_insulation) * 0.1
		elif ambient_temp < 45: change_rate = (difference / cold_insulation) * 0.1
		else: change_rate = (50.0 - internal_temperature) * recovery_speed * 0.2
		internal_temperature += change_rate * delta
	# Emitimos la señal para el HUD
	temp_changed.emit(internal_temperature)

func _apply_temperature_consequences(delta: float):
	# 1. Efectos menores (Hambre y Sed)
	if internal_temperature > 55:
		var thirst_drain = (internal_temperature - 50) * 0.1
		survival.current_thirst -= thirst_drain * delta
		
	if internal_temperature < 45 and internal_temperature > 10:
		var hunger_drain = (50 - internal_temperature) * 0.1
		survival.current_hunger -= hunger_drain * delta
		
	# 2. Calor Extremo (Quemaduras)
	if internal_temperature > 90:
		survival.take_damage(2.0 * delta)
		
		# DAÑO ESCALONADO POR DEBAJO DE 25
	if internal_temperature <= 25.0 and internal_temperature > 0.1:
		effect_timer += delta
		if effect_timer >= 1.0: # Cada 1 segundo instanciamos los efectos
			effect_timer = 0.0
			var amount_to_spawn = 0
			
			if internal_temperature <= 18.0:
				amount_to_spawn = 7
			elif internal_temperature <= 20.0:
				amount_to_spawn = 5
			else: # Entre 20 y 25
				amount_to_spawn = 2
				
			_spawn_cold_effects(amount_to_spawn)
			
	# 3. Frío Extremo (Petrificación por Hielo)
	if internal_temperature <= 10.0 and internal_temperature > 0.0:
		_handle_freezing_effect(delta)
	elif internal_temperature > 10.0 and is_frozen:
		_thaw_creature() # Se descongela si logra calentarse antes de morir
		
		# 4. Muerte Instantánea por Temperatura 0
	if internal_temperature <= 0.0:
		if not survival.is_dead:
			print("GAME OVER: Congelamiento Total.")
			survival.is_dead = true
			survival.current_health = 0
			survival.stats_changed.emit(0, survival.current_hunger, survival.current_thirst, survival.current_energy, survival.growth_percent, "")
			
			# Aquí llamas a la función real de muerte de tu juego. 
			# Si en SurvivalManager tienes una función die(), llámala:
			if survival.has_method("die"):
				survival.die() 

func _handle_freezing_effect(delta: float):
	if not is_frozen:
		is_frozen = true
		if "is_frozen_by_temp" in controller:
			controller.is_frozen_by_temp = true # Bloquea TODO movimiento
		
		# Opcional: Si tienes un AnimationPlayer, puedes pausarlo aquí
		# $"../AnimationPlayer".pause()
		
		# Instanciar el cubo de hielo
		if ice_cube_scene and not current_ice_cube:
			current_ice_cube = ice_cube_scene.instantiate()
			add_child(current_ice_cube)
			# Lo ponemos en la misma posición, pero lo empezamos pequeñito
			current_ice_cube.global_position = controller.global_position
			current_ice_cube.scale = Vector3(0.1, 0.1, 0.1)
			
	# Escalar el cubo y levantar a la criatura gradualmente
	if current_ice_cube:
		var target_scale = Vector3(2.0, 2.0, 2.0) # Ajusta este tamaño según tu criatura
		current_ice_cube.scale = current_ice_cube.scale.lerp(target_scale, delta * 0.5)

func _thaw_creature():
	is_frozen = false
	if "is_frozen_by_temp" in controller:
		controller.is_frozen_by_temp = false # Libera el movimiento
		
	# $"../AnimationPlayer".play() # Despausar animación
	
	if current_ice_cube:
		current_ice_cube.queue_free()
		current_ice_cube = null
		
	if model_holder:
		model_holder.position.y = 0.0 # Bajar la criatura al suelo de nuevo

func _spawn_cold_effects(amount: int):
	if not cold_effect_scene: return
	
	for i in range(amount):
		var effect = cold_effect_scene.instantiate()
		controller.add_child(effect)
		# Opcional: Si quieres que aparezcan un poco esparcidos alrededor del jugador
		var random_offset = Vector3(randf_range(-1, 1), randf_range(0, 2), randf_range(-1, 1))
		effect.position = random_offset
