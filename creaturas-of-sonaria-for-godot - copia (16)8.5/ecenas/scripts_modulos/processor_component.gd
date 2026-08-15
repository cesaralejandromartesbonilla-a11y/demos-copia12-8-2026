extends Node
class_name ProcessorComponent

signal progress_updated(percent: float)
signal status_changed(msg: String)
signal request_spawn_drop(item: ItemData)
signal machine_state_changed(state: String)
signal optional_power_state(has_power: bool)

@export_group("Conexiones")
@export var input_inv: InventoryComponent
@export var fuel_inv: InventoryComponent
@export var output_inv: InventoryComponent
@export var burner: BurnerComponent
@export var power_receiver: PowerReceiverComponent

@export_group("Configuración de Máquina")
@export var is_automatic: bool = false
@export var recipes: Array[RecipeData] = []

@export_group("Requisitos Operativos")
@export_enum("Ninguno", "Opcional", "Requerido") var fuel_mode: int = 2 
@export_enum("Ninguno", "Opcional", "Requerido") var power_mode: int = 0

@export_group("depurar")
@export var señales: bool = false

var current_recipe: RecipeData = null
var progress: float = 0.0
var current_state: String = "OFF"
var is_machine_enabled: bool = false 
var lights_enabled: bool = true

func toggle_machine() -> void:
	is_machine_enabled = !is_machine_enabled
	if not is_machine_enabled:
		_change_state("OFF")
		if power_receiver: power_receiver.turn_machine_off()
	else:
		_change_state("IDLE")

func toggle_lights() -> void:
	lights_enabled = !lights_enabled

func _process(delta: float) -> void:
	if not is_machine_enabled:
		if power_receiver: power_receiver.turn_machine_off()
		_change_state("OFF")
		optional_power_state.emit(false)
		return

	var can_run = true
	var error_state = "IDLE" 
	var has_power_for_lights = false

	if señales:
		print("Estado actual: " + current_state + " | Error: " + error_state)

	# Consumo de Energía
	if power_mode != 0 and power_receiver:
		var power_ratio = power_receiver.try_consume_power(delta)
		if power_ratio < 1.0: 
			if power_mode == 2:
				can_run = false
				error_state = "NO_POWER"
		else:
			has_power_for_lights = true
			

	# Consumo de Combustible
	if fuel_mode != 0 and burner:
		if not burner.is_burning:
			if fuel_inv and fuel_inv.stored_items.size() > 0:
				var fuel = fuel_inv.stored_items[0]
				burner.add_fuel(20.0)
				fuel_inv.remove_item(fuel)
				
		if not burner.is_burning:
			if fuel_mode == 2:
				can_run = false
				error_state = "NO_FUEL"

	optional_power_state.emit(has_power_for_lights and lights_enabled)

	if can_run:
		if current_recipe != null:
			if not _can_output_recipe(current_recipe):
				_change_state("JAMMED")
			else:
				_change_state("WORKING")
				_continue_processing(delta)
		elif is_automatic:
			_change_state("IDLE")
			_check_for_recipes()
		else:
			_change_state("IDLE")
	else:
		_change_state(error_state)
		if progress > 0: progress -= delta * 0.5

func _check_for_recipes() -> void:
	for r in recipes:
		if señales: print("Revisando receta: " + r.recipe_name)
		if _has_ingredients(r) and _can_output_recipe(r):
			if señales: print("Receta lista para fabricar: " + r.recipe_name)
			current_recipe = r
			status_changed.emit("Procesando: " + r.recipe_name)
			return

func _has_ingredients(recipe: RecipeData) -> bool:
	# 1. Revisar requerimientos de items sólidos
	if recipe.required_items.size() > 0:
		if input_inv == null: return false
		for req in recipe.required_items:
			var count = 0
			for item in input_inv.stored_items:
				if item.item_name == req.item_name: count += 1
			if count < 1: return false 
			

	return true

func _can_output_recipe(recipe: RecipeData) -> bool:
	var can_output_item = (output_inv == null) or (recipe.result_item == null) or output_inv.can_accept(recipe.result_item)
	return can_output_item 

func _continue_processing(delta: float) -> void:
	progress += delta
	progress_updated.emit(progress / current_recipe.craft_time)
	
	if progress >= current_recipe.craft_time:
		# Extraer sólidos
		for req in current_recipe.required_items:
			input_inv.extract_item_by_name(req.item_name)
		
		# Generar sólidos
		if current_recipe.result_item != null:
			if output_inv and output_inv.add_item(current_recipe.result_item):
				pass # Sólido guardado
			else:
				request_spawn_drop.emit(current_recipe.result_item)
				

		status_changed.emit("¡Proceso terminado!")
		current_recipe = null
		progress = 0.0
		progress_updated.emit(0.0)

func start_recipe(recipe: RecipeData) -> void:
	if current_recipe != null: return 
	
	var can_output = (output_inv == null) or output_inv.can_accept(recipe.result_item)
	if _has_ingredients(recipe) and can_output:
		current_recipe = recipe
		status_changed.emit("Procesando: " + recipe.recipe_name)
	else:
		status_changed.emit("Faltan ingredientes o salida llena")

func _change_state(new_state: String) -> void:
	if current_state != new_state:
		current_state = new_state
		machine_state_changed.emit(current_state)

func _ready() -> void:
	if input_inv: input_inv.inventory_changed.connect(_wake_up_machine)
	if output_inv: output_inv.inventory_changed.connect(_wake_up_machine)

func _wake_up_machine() -> void:
	if is_automatic and current_recipe == null and is_machine_enabled:
		_check_for_recipes()

func _wake_up_machine_fluid(_fluid_name: String, _vol: float) -> void:
	_wake_up_machine()
