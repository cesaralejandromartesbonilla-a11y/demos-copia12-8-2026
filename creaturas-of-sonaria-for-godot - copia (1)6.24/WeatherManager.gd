# GLOBAL / AUTOLOAD (WeatherManager)
extends Node
signal time_changed(current_time: float)
signal weather_changed(new_weather: WeatherType)
signal tick_1s
signal tick_30s
signal tick_1m
signal tick_30m
signal tick_1h
signal tick_1d

enum WeatherType { CLEAR, RAIN, STORM, DROUGHT }
var current_weather: WeatherType = WeatherType.CLEAR

enum TempState { EXTREME_HOT, HOT, TROPICAL, TEMPERATE, COLD, EXTREME_COLD }
var current_temp: TempState = TempState.TEMPERATE

# VELOCIDAD DEL JUEGO: Si está en 60.0, 1 segundo de la vida real = 1 minuto en el juego.
# A esta velocidad, un día completo del juego (24h) dura 24 minutos reales.
@export var in_game_seconds_per_real_second: float = 60.0

var current_biome: String = "pradera" 
var time_of_day: float = 8.0 # El juego inicia a las 8.0 (8 AM)
var is_day: bool = true
var time_multiplier: float = 1.0 
var in_game_seconds: int = 0
var in_game_minutes: int = 0
var in_game_hours: int = 8
var in_game_days: int = 1
var _time_accumulator: float = 0.0
var weather_entity_scene = preload("res://models/clima/cloud.tscn")
var spawn_timer: float = 0.0

# --- INICIALIZACIÓN ---
func _ready() -> void:
	in_game_hours = int(time_of_day)
	in_game_minutes = int((time_of_day - in_game_hours) * 60)

func _process(delta: float) -> void:
	_handle_master_clock(delta)
	_handle_weather_spawning(delta)

# --- EL RELOJ MAESTRO ---
func _handle_master_clock(delta: float) -> void:
	# Acumulamos el tiempo
	_time_accumulator += delta * in_game_seconds_per_real_second * time_multiplier
	
	# Despachamos los "Ticks" para los sistemas lógicos
	while _time_accumulator >= 1.0:
		_time_accumulator -= 1.0
		_advance_tick()
	
	# Calculamos la variable float 
	var exact_seconds = in_game_seconds + _time_accumulator
	time_of_day = float(in_game_hours) + (float(in_game_minutes) / 60.0) + (exact_seconds / 3600.0)
	
	# Comprobar día/noche (Lógica original)
	var was_day = is_day
	is_day = (time_of_day >= 6.0 and time_of_day <= 18.0)
	if was_day != is_day:
		print("Día/Noche cambiado. Es de día: ", is_day)
	
	# Emitimos la señal original
	time_changed.emit(time_of_day)

func _advance_tick() -> void:
	in_game_seconds += 1
	tick_1s.emit()
	
	if in_game_seconds % 30 == 0:
		tick_30s.emit()
		
	if in_game_seconds >= 60:
		in_game_seconds = 0
		in_game_minutes += 1
		tick_1m.emit()
		
		if in_game_minutes % 30 == 0:
			tick_30m.emit()
			
		if in_game_minutes >= 60:
			in_game_minutes = 0
			in_game_hours += 1
			tick_1h.emit()
			
			if in_game_hours >= 24:
				in_game_hours = 0
				in_game_days += 1
				tick_1d.emit()

# --- LÓGICA DE CLIMA ---
func _handle_weather_spawning(delta: float):
	spawn_timer += delta * time_multiplier
	if spawn_timer >= 60.0:
		spawn_timer = 0.0
		_spawn_random_weather()

func _spawn_random_weather():
	if not weather_entity_scene:
		print("no hay nubes")
		return
	
	var spawn_points = get_tree().get_nodes_in_group("weather_spawn")
	if spawn_points.is_empty(): return
	var random_spawner = spawn_points[randi() % spawn_points.size()]
	
	var new_weather = weather_entity_scene.instantiate()
	get_tree().current_scene.add_child(new_weather)
	new_weather.global_position = random_spawner.global_position
	print("se spawneo una nube")

func set_weather(new_weather: WeatherType):
	if current_weather != new_weather:
		current_weather = new_weather
		weather_changed.emit(current_weather)
		print("El clima ha cambiado a: ", WeatherType.keys()[current_weather])
