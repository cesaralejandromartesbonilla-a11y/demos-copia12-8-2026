extends Control

@onready var health_bar: ProgressBar = $VBoxContainer/HealthBar
@onready var hunger_bar: ProgressBar = $VBoxContainer/HungerBar
@onready var thirst_bar: ProgressBar = $VBoxContainer/ThirstBar
@onready var energy_bar: ProgressBar = $VBoxContainer/EnergyBar
@onready var growth_bar: ProgressBar = $VBoxContainer/GrowthBar
@onready var temp_bar: ProgressBar = $VBoxContainer/TempBar # NUEVA BARRA
@onready var slot1 = $VBoxContainer/AbilitySlot
@onready var slot2 = $VBoxContainer/AbilitySlot2
@onready var slot3 = $VBoxContainer/AbilitySlot3
@onready var left_hand_label = $VBoxContainer/LeftHandLabel
@onready var right_hand_label = $VBoxContainer/RightHandLabel

func _ready() -> void:
	# Esperamos un frame para que el World cargue todo
	await get_tree().process_frame
	
	# Buscamos al jugador local actual
	var player = get_tree().get_first_node_in_group("player")
	if player:
		setup_hud_for_player(player)
	else:
		print("HUD Error: No se encontró ninguna criatura en el grupo 'player'.")

# Eliminamos la búsqueda en _ready(). Ahora creamos una función manual.
func setup_hud_for_player(player_node: Node) -> void:
	var survival = player_node.get_node_or_null("SurvivalManager")
	var temp_manager = player_node.get_node_or_null("TemperatureManager")
	var am = player_node.get_node_or_null("AbilityManager")
	
	if survival:
		survival.stats_changed.connect(_on_stats_changed)
		health_bar.max_value = survival.current_health
		hunger_bar.max_value = survival.max_hunger
		thirst_bar.max_value = survival.max_thirst
		energy_bar.max_value = survival.max_energy
		growth_bar.max_value = survival.growth_percent
		# Actualización inicial
		_on_stats_changed(survival.current_health, survival.current_hunger, survival.current_thirst, survival.current_energy, survival.growth_percent, "")
		
	if temp_manager:
		temp_bar.max_value = 100.0
		temp_manager.temp_changed.connect(_on_temp_changed)
		_on_temp_changed(temp_manager.internal_temperature)
		
	if am:
		slot1.setup(0, am)
		slot2.setup(1, am)
		slot3.setup(2, am)
	var hands = player_node.get_node_or_null("HandsInventory")
	if hands:
		hands.inventory_changed.connect(_on_hands_changed)
		hands._update_ui() # Llamada inicial para que no salgan vacíos al cargar

func _on_stats_changed(health: float, hunger: float, thirst: float, energy: float, growth: float, _time: String) -> void:
	health_bar.value = health
	hunger_bar.value = hunger
	thirst_bar.value = thirst
	energy_bar.value = energy
	growth_bar.value = growth * 100

# Nueva función para recibir la señal de temperatura
func _on_temp_changed(new_temp: float) -> void:
	if temp_bar:
		temp_bar.value = new_temp

func _on_hands_changed(left_text: String, right_text: String) -> void:
	left_hand_label.text = "Mano Izq: " + left_text
	right_hand_label.text = "Mano Der: " + right_text
