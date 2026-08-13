extends AbilityBase 


@export var speed: float = 20.0
@export var damage: float = 10.0
@export var lifetime: float = 5.0
@export var burn_effect: Resource # (O StatusEffect si tienes esa clase)
@export var element_color: Color = Color(1.0, 0.4, 0.0) # Naranja por defecto

func _execute_ability() -> void:
	# Autodestrucción por tiempo para no llenar la memoria
	get_tree().create_timer(lifetime).timeout.connect(end_ability)
	
	# Conectar la señal de colisión
	area_entered.connect(_on_impact)
	body_entered.connect(_on_impact_body)

func _physics_process(delta: float) -> void:
	# Movimiento constante en la dirección recibida
	global_position += direction * speed * delta

func _on_impact(area: Area3D) -> void:
	# Ignoramos la colisión si chocamos con el entorno climático para evitar el suicidio
	if area.is_in_group("tornado") or area.is_in_group("weather_entity") or area.is_in_group("tornado_projectile"):
		return
		
	_apply_to_target(area.get_parent())

func _on_impact_body(body: Node3D) -> void:
	# Chocar contra paredes, suelo o enemigos
	_apply_to_target(body)

func _apply_to_target(target: Node) -> void:
	# 1. Aplicar daño directo si el objetivo tiene la función
	if target.has_method("take_damage"):
		target.take_damage(damage)
	
	# 2. Aplicar efecto de quemadura si tiene un EffectManager
	if target.has_method("apply_status_effect") and burn_effect:
		target.apply_status_effect(burn_effect)
	
	# Desaparecer al impactar contra algo válido
	end_ability()

func end_ability():
	queue_free()
