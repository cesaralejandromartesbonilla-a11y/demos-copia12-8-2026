extends AbilityBase

@export var heal_amount: float = 5.0
@export var tick_interval: float = 0.5
@export var total_duration: float = 3.0
@export var original_scene: PackedScene

func _execute_ability() -> void:
	# Esta habilidad se queda pegada al que la lanzó
	if caster:
		# Creamos un Timer para los "ticks" de curación
		var timer = Timer.new()
		timer.wait_time = tick_interval
		add_child(timer)
		timer.timeout.connect(_on_heal_tick)
		timer.start()
		
		# Reposicionar el aura en los pies de la criatura
		global_position = caster.global_position
		
		# Autodestrucción tras la duración total
		get_tree().create_timer(total_duration).timeout.connect(end_ability)

func _physics_process(_delta: float) -> void:
	# Hacer que el aura siga a la criatura mientras cura
	if is_instance_valid(caster):
		global_position = caster.global_position

func _on_heal_tick() -> void:
	if is_instance_valid(caster):
		var survival = caster.get_node_or_null("SurvivalManager")
		if survival:
			# Curación: sumamos vida sin pasarnos del máximo
			survival.current_health = min(survival.current_health + heal_amount, survival.max_health)
			print("Curando... Vida actual: ", survival.current_health)
			
			# (Opcional) Mostrar número verde sobre el jugador
			if caster.has_method("_spawn_damage_label"):
				caster._spawn_damage_label(heal_amount, Color.GREEN)
