extends AbilityBase

@export var speed: float = 20.0
@export var damage: float = 10.0
@export var lifetime: float = 5.0
@export var freeze_effect: StatusEffect # Arrastra aquí tu recurso de congelacion

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
	_apply_to_target(area.get_parent())

func _on_impact_body(body: Node3D) -> void:
	_apply_to_target(body)

func _apply_to_target(target: Node) -> void:
	# 1. Aplicar daño directo si el objetivo tiene la función
	if target.has_method("take_damage"):
		target.take_damage(damage)
	
	# 2. Aplicar efecto de quemadura si tiene un EffectManager
	if target.has_method("apply_status_effect") and freeze_effect:
		target.apply_status_effect(freeze_effect)
	
	# Desaparecer al impactar
	end_ability()
