extends Node
class_name EnvironmentManager

@onready var interaction = $"../InteractionManager"
@onready var controller = get_parent()
@onready var roof_detector = $"../RoofDetector" 

@export_group("Efectos Visuales de Clima")
@export var rain_scene: PackedScene
@export var snow_storm_scene: PackedScene
@export var sand_storm_scene: PackedScene
@export var drought_heat_scene: PackedScene

var current_biome: String = "vacio"
var ambient_target_temp: float = 50.0 
var current_vfx_node: Node3D = null # Guarda la escena visual actual

func _ready() -> void:
	# Escuchamos si el global cambia el clima
	WeatherManager.weather_changed.connect(_on_global_weather_changed)

func _physics_process(_delta: float) -> void:
	_update_current_biome()
	_calculate_ambient_temperature()

func _update_current_biome():
	if not interaction: return
	var areas = interaction.get_overlapping_areas()
	var found_biome = "vacio"
	
	for area in areas:
		if area.is_in_group("bioma_desierto"): found_biome = "desierto"; break
		elif area.is_in_group("bioma_artico"): found_biome = "artico"; break
		elif area.is_in_group("bioma_pradera"): found_biome = "pradera"; break
		elif area.is_in_group("bioma_oceano"): found_biome = "oceano"; break
		elif area.is_in_group("bioma_lago"): found_biome = "lago"; break
			
	if current_biome != found_biome:
		current_biome = found_biome
		print("Entrando al bioma: ", current_biome)
		_update_local_weather_vfx() # Si cambiamos de bioma, actualizamos los gráficos

func _on_global_weather_changed(_new_weather):
	# Si el global cambia (ej. empieza a llover), actualizamos los gráficos
	_update_local_weather_vfx()

func _update_local_weather_vfx():
	var weather = WeatherManager.current_weather
	var scene_to_spawn: PackedScene = null
	
	# Decidimos qué escena usar combinando Clima Global + Bioma Local
	match weather:
		WeatherManager.WeatherType.RAIN:
			if current_biome == "artico": scene_to_spawn = snow_storm_scene # En ártico, la lluvia es nieve leve
			elif current_biome != "desierto": scene_to_spawn = rain_scene
			
		WeatherManager.WeatherType.STORM:
			if current_biome == "artico": scene_to_spawn = snow_storm_scene
			elif current_biome == "desierto": scene_to_spawn = sand_storm_scene
			else: scene_to_spawn = rain_scene # Aquí puedes añadir una escena de tormenta eléctrica
			
		WeatherManager.WeatherType.DROUGHT:
			if current_biome == "desierto" or current_biome == "pradera":
				scene_to_spawn = drought_heat_scene # Partículas de calor distorsionado
				
		WeatherManager.WeatherType.CLEAR:
			scene_to_spawn = null

	# Eliminamos el clima visual anterior si existe
	if current_vfx_node:
		current_vfx_node.queue_free()
		current_vfx_node = null
		
	# Instanciamos el nuevo (si corresponde) y lo hacemos hijo del jugador
	if scene_to_spawn:
		current_vfx_node = scene_to_spawn.instantiate()
		controller.add_child(current_vfx_node)
		current_vfx_node.position = Vector3.ZERO

func _calculate_ambient_temperature():
	var weather = WeatherManager.current_weather
	var is_day = WeatherManager.is_day
	var is_exposed = not roof_detector.is_colliding() and not controller.is_in_water
	var base_temp = 50.0 
	
	match current_biome:
		"desierto":
			base_temp = 85.0 if is_day else 30.0 
			if weather == WeatherManager.WeatherType.DROUGHT: base_temp += 15.0
		"artico":
			base_temp = 5.0 # Ajustado para que el frío se sienta
			if weather == WeatherManager.WeatherType.STORM: base_temp -= 20.0
		"oceano", "lago":
			base_temp = 45.0 
		"vacio", "pradera":
			base_temp = 50.0
			if not is_day: base_temp -= 10.0

	if not is_exposed:
		base_temp = lerp(base_temp, 50.0, 0.7)
		
	ambient_target_temp = base_temp
