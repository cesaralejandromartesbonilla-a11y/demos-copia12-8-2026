extends Node
class_name EffectManager

# Diccionario: { "Veneno": [ {stack_data}, ... ] }
var active_stacks: Dictionary = {}
@export var max_stacks_allowed: int = 15 
var active_effects: Array[StatusEffect] = []
# Lista de nombres de efectos a los que este nodo es inmune (ej: "Quemadura", "Veneno")
@export var immunities: Array[String] = []
#@export var immunities: Array[StatusEffect] = [] #tambien es factible

func _process(_delta: float) -> void:
	if Input.is_action_pressed("press_r"):clear_all_effects()

func add_status_effect(effect: StatusEffect):
	if not effect: return
	#========================================
	#===sistema de inmunidada================
	#========================================
	if effect.effect_name in immunities:
		print("El objetivo es INMUNE a: ", effect.effect_name)
		return
	#===sistema de inmunidad por recursos.tres===
	#NOTA:los recursos no guardan nombres
	#for immunity in immunities:
		#if immunity != null and immunity.effect_name == effect.effect_name:
			#print("Inmunidad activada contra: ", effect.effect_name)
			#return
	#========================================
	#===sistema de inmunidada================
	#========================================

	var effect_name = effect.effect_name
	# --- CREAR NUEVO STACK (Porque aún no llegamos al límite) ---
	var duration_timer = Timer.new()
	var tick_timer = Timer.new()
	var new_stack = {
		"duration_timer": duration_timer,
		"tick_timer": tick_timer
	}

	
	# Si no existe la lista para este efecto, la creamos
	if not active_stacks.has(effect_name):
		active_stacks[effect_name] = []
	
	# --- LÓGICA DE ACUMULACIÓN ---
	# Si ya llegamos al máximo de stacks (ej. 15), solo refrescamos la duración de los existentes
	if active_stacks[effect_name].size() >= max_stacks_allowed:
		for stack in active_stacks[effect_name]:
			if is_instance_valid(stack.duration_timer):
				stack.duration_timer.start(effect.duration)
		return
	
	# Configurar temporizadores
	duration_timer.wait_time = effect.duration
	duration_timer.one_shot = true
	add_child(duration_timer)
	
	tick_timer.wait_time = effect.tick_interval
	tick_timer.autostart = true
	add_child(tick_timer)
	
	# Conexiones: 
	# El tick_timer aplica el efecto (daño) al padre
	duration_timer.timeout.connect(func(): _on_stack_expired(effect_name, new_stack))
	tick_timer.timeout.connect(func(): effect.apply_effect(get_parent()))
	
	duration_timer.start()
	tick_timer.start()
	
	active_stacks[effect_name].append(new_stack)
	
	# Aplicamos el primer golpe de daño al instante
	effect.apply_effect(get_parent())
	print("Stack añadido: ", effect_name, " (", active_stacks[effect_name].size(), "/", max_stacks_allowed, ")")

func _on_stack_expired(effect_name: String, stack_to_remove: Dictionary) -> void:
	if active_stacks.has(effect_name):
		if is_instance_valid(stack_to_remove.duration_timer): stack_to_remove.duration_timer.queue_free()
		if is_instance_valid(stack_to_remove.tick_timer): stack_to_remove.tick_timer.queue_free()
		
		active_stacks[effect_name].erase(stack_to_remove)
		
		if active_stacks[effect_name].is_empty():
			active_stacks.erase(effect_name)
			print("Efecto ", effect_name, " ha expirado completamente.")

func clear_all_effects() -> void:
	for effect_name in active_stacks.keys():
		for stack in active_stacks[effect_name]:
			if is_instance_valid(stack.duration_timer): stack.duration_timer.queue_free()
			if is_instance_valid(stack.tick_timer): stack.tick_timer.queue_free()
	active_stacks.clear()
