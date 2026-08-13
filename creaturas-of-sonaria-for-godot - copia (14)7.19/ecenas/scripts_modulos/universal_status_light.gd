extends MeshInstance3D
class_name UniversalStatusLight

@export var surface_index: int = 0

@export_group("Materiales")
@onready var mat_green = preload("res://materiales/luces/luz_verde.tres")
@onready var mat_orange = preload("res://materiales/luces/luz_amarilla.tres")
@onready var mat_red = preload("res://materiales/luces/luz_roja.tres")

# Asignamos valores numéricos para usar el sistema de prioridades
# RED (2) siempre le ganará a ORANGE (1) y a GREEN (0)
enum LightState { GREEN = 0, ORANGE = 1, RED = 2 }

@export_group("Monitoreo: Inventario")
@export var inventory: InventoryComponent
@export_enum("Desactivado", "Modo Salida (Rojo = Lleno)", "Modo Entrada (Rojo = Vacío)") var inventory_mode: int = 0

@export_group("Monitoreo: Quemador")
@export var burner: BurnerComponent
@export_enum("Desactivado", "Activado") var burner_mode: int = 0

@export_group("Monitoreo: Receptor de Energía")
@export var power_receiver: PowerReceiverComponent
@export_enum("Desactivado", "Activado") var receiver_mode: int = 0

@export_group("Monitoreo: Generador")
@export var generator: PowerGeneratorComponent
@export_enum("Desactivado", "Activado") var generator_mode: int = 0

func _process(_delta: float) -> void:
	var current_highest_state: int = LightState.GREEN
	var is_monitoring_anything: bool = false
	
	# --- 1. EVALUAR INVENTARIO ---
	if inventory != null and inventory_mode != 0:
		is_monitoring_anything = true
		var inv_state = _get_inventory_state()
		if inv_state > current_highest_state: current_highest_state = inv_state
		
	# --- 2. EVALUAR QUEMADOR ---
	if burner != null and burner_mode != 0:
		is_monitoring_anything = true
		var burn_state = LightState.GREEN if burner.is_burning else LightState.RED
		if burn_state > current_highest_state: current_highest_state = burn_state

	# --- 3. EVALUAR RECEPTOR DE ENERGÍA ---
	if power_receiver != null and receiver_mode != 0:
		is_monitoring_anything = true
		# Según tu script actual, usamos is_machine_running para saber si recibe energía
		var rec_state = LightState.GREEN
		if not power_receiver.is_machine_running:
			rec_state = LightState.RED
			
		# NOTA: Si en el futuro tu PowerReceiverComponent tiene una variable como 'current_power_received', 
		# podrías añadir aquí la lógica para el color Naranja (ej: si recibe algo de energía pero no los required_kw).
		
		if rec_state > current_highest_state: current_highest_state = rec_state
		
	# --- 4. EVALUAR GENERADOR ---
	if generator != null and generator_mode != 0:
		is_monitoring_anything = true
		var gen_state = LightState.RED
		
		# Verificamos si está produciendo (asumiendo que depende de su quemador)
		if generator.burner != null:
			if generator.burner.is_burning:
				gen_state = LightState.GREEN
			else:
				# Se podría marcar en naranja (falta combustible). 
				# Por ahora, como no hay un is_enabled en Generator, lo marcamos en Rojo.
				gen_state = LightState.RED 
		
		if gen_state > current_highest_state: current_highest_state = gen_state

	# --- APLICAR EL COLOR GANADOR ---
	# Si te olvidaste de configurar la luz en el inspector, se queda apagada (Roja)
	if not is_monitoring_anything:
		set_surface_override_material(surface_index, mat_red)
		return
		
	match current_highest_state:
		LightState.GREEN:
			set_surface_override_material(surface_index, mat_green)
		LightState.ORANGE:
			set_surface_override_material(surface_index, mat_orange)
		LightState.RED:
			set_surface_override_material(surface_index, mat_red)

# --- FUNCIÓN AUXILIAR PARA EL INVENTARIO ---
func _get_inventory_state() -> int:
	var count = inventory.stored_items.size()
	var cap = inventory.max_capacity
	
	if inventory_mode == 1: # MODO SALIDA
		if count >= cap: return LightState.RED
		elif count > 0 and count < cap: return LightState.ORANGE
		else: return LightState.GREEN
		
	elif inventory_mode == 2: # MODO ENTRADA
		if count == 0: return LightState.RED
		elif count > 0 and count < cap: return LightState.ORANGE
		else: return LightState.GREEN
		
	return LightState.GREEN
