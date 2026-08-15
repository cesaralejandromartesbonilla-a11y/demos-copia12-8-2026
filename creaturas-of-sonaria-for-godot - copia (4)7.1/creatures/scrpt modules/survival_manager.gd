extends Node
class_name SurvivalManager

# --- SEÑALES PARA LA UI ---
signal stats_changed(health, hunger, thirst, energy, growth, time)
signal creature_died

# --- CONFIGURACIÓN (Ajustable desde el Inspector) ---
@export_group("Límites Máximos")
@export var max_health: float = 100.0
@export var max_hunger: float = 100.0
@export var max_thirst: float = 100.0
@export var max_energy: float = 100.0

@export_group("Desgaste y Daño")
@export var hunger_drain: float = 0.5 
@export var thirst_drain: float = 0.8
@export var damage_starvation: float = 2.0 # Daño por segundo al estar en 0

@export_group("Crecimiento y Tiempo")
@export var growth_speed: float = 0.01
@export var update_tick: float = 1.0 # Cada cuánto segundo se actualiza el tiempo de vida

# --- VARIABLES DE ESTADO ---
var current_health: float
var current_hunger: float
var current_thirst: float
var current_energy: float
var growth_percent: float = 0.05
var seconds_lived: int = 0
var is_dead: bool = false

func _ready() -> void:
	# Inicializar stats (esto lo llamaremos desde el World.gd también)
	current_health = max_health
	current_hunger = max_hunger
	current_thirst = max_thirst
	current_energy = max_energy
	
	# Timer para el tiempo de vida
	var survival_timer = Timer.new()
	survival_timer.wait_time = 1.0
	survival_timer.autostart = true
	add_child(survival_timer)
	survival_timer.timeout.connect(_on_second_passed)

func _process(delta: float) -> void:
	if is_dead: return
	
	# 1. Drenaje pasivo
	current_hunger = max(0.0, current_hunger - hunger_drain * delta)
	current_thirst = max(0.0, current_thirst - thirst_drain * delta)
	
	# 2. Daño por necesidad a cero
	if current_hunger <= 0 or current_thirst <= 0:
		take_damage(damage_starvation * delta)
		
	# 3. Crecimiento
	if current_hunger > 20 and current_thirst > 20 and growth_percent < 1.0:
		growth_percent += growth_speed * delta
	
	# 4. Enviar datos a la UI (puedes llamar esto cada frame o con señal)
	stats_changed.emit(current_health, current_hunger, current_thirst, current_energy, growth_percent, get_formatted_time())

func take_damage(amount: float):
	current_health = clamp(current_health - amount, 0.0, max_health)
	if current_health <= 0 and not is_dead:
		die()

func die():
	if is_dead: return
	is_dead = true
	creature_died.emit()
	
	# Buscamos la pantalla de muerte
	# Usamos find_child por si el GameOverLayer está en la raíz de la escena World
	var ui_death = get_tree().root.find_child("GameOverLayer", true, false)
	
	if ui_death:
		ui_death.show_death_screen(get_formatted_time(), growth_percent)
	else:
		print("ADVERTENCIA: No se encontró la pantalla de GameOverLayer en la escena.")

func _on_second_passed():
	if not is_dead:
		seconds_lived += 1

# Convierte los segundos en un texto legible "05:20"
func get_formatted_time() -> String:
	var minutes = seconds_lived / 60.0
	var seconds = seconds_lived % 60
	return "%02d:%02d" % [minutes, seconds]
