extends Node
class_name MagicInventory

@onready var player = get_parent()

const BASE_ITEM_SCENE = preload("res://slime_test/comsumableitem.tscn")

var stored_data: Array[Dictionary] = []
var stomach_container: Node3D

func _ready():
	stomach_container = Node3D.new()
	stomach_container.name = "StomachContents"
	call_deferred("_setup_container")

func _setup_container():
	if player.visuals:
		player.visuals.add_child(stomach_container)

func get_current_capacity() -> int:
	# 1. Conseguimos la capacidad base que dicta la forma actual
	var base_capacity = 3
	if player.transformation_module:
		base_capacity = player.transformation_module.get_capacity(player.current_form)
	
	# 2. CÁLCULO DE CRECIMIENTO
	if "base_visual_scale" in player:
		var current_growth = player.base_visual_scale.x - 1.0
		var extra_slots = floori(current_growth / 0.1) 
		
		return base_capacity + extra_slots
		
	return base_capacity

func store_physical_item(item: ConsumableItem) -> bool:
	if stored_data.size() < get_current_capacity():
		
		# 1. CREAR EL FANTASMA VISUAL
		var dummy = MeshInstance3D.new()
		if item.item_mesh:dummy.mesh = item.item_mesh
		
		stomach_container.add_child(dummy)
		
		# --- ANIMACIÓN DE ABSORCIÓN ---
		dummy.global_position = item.global_position 
		var random_stomach_pos = Vector3(randf_range(-0.3, 0.3), randf_range(0.2, 0.7), randf_range(-0.3, 0.3))
		
		var tween = get_tree().create_tween()
		tween.set_parallel(true)
		tween.tween_property(dummy, "position", random_stomach_pos, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(dummy, "scale", Vector3.ONE * 0.4, 0.3).set_trans(Tween.TRANS_SINE)
		
		# 2. GUARDAR LOS DATOS PUROS
		var item_data = {
			"item_name": item.item_name,
			"form_to_grant": item.form_to_grant,
			"item_mesh": item.item_mesh,
			"forma_colision": item.forma_colision,
			"item_weight": item.item_weight,
			"hands_required": item.hands_required,
			"dummy_node": dummy
		}
	
		stored_data.append(item_data)
		item.queue_free() 
		return true
		
	return false

func _reconstruct_item(data: Dictionary) -> ConsumableItem:
	# Destruimos el fantasma visual del estómago
	if is_instance_valid(data["dummy_node"]):
		data["dummy_node"].queue_free()
		
	# Instanciamos la escena base usando la CONSTANTE que definimos arriba
	var new_item = BASE_ITEM_SCENE.instantiate() as ConsumableItem
	
	if new_item != null:
		# INYECCIÓN DE DATOS: Le devolvemos su identidad
		new_item.item_mesh = data["item_mesh"]
		new_item.item_name = data["item_name"]
		new_item.form_to_grant = data["form_to_grant"]
		return new_item
	else:
		push_error("Error fatal: La constante BASE_ITEM_SCENE no pudo instanciarse.")
		return null

# --- EXTRACCIÓN Y RECONSTRUCCIÓN ---

func extract_last_item() -> ConsumableItem:
	if stored_data.is_empty():
		return null
		
	var data = stored_data.pop_back()
	
	# --- DESTRUIR EL FANTASMA DEL ESTÓMAGO ---
	if data.has("dummy_node") and is_instance_valid(data["dummy_node"]):
		data["dummy_node"].queue_free()
	# -------------------------------------------------
	
	# Creamos un objeto en blanco
	var new_item = BASE_ITEM_SCENE.instantiate()
	
	# EL DESEMPAQUETADO: Le inyectamos su memoria
	new_item.item_name = data["item_name"]
	new_item.form_to_grant = data["form_to_grant"]
	new_item.item_mesh = data["item_mesh"]
	new_item.forma_colision = data["forma_colision"] 
	new_item.item_weight = data["item_weight"]
	new_item.hands_required = data["hands_required"]
	
	return new_item

func extract_first_item() -> ConsumableItem:
	if stored_data.size() == 0: return null
	return _reconstruct_item(stored_data.pop_front())

# --- LÓGICA DE EXPULSIÓN ---

func _expel_internal_inventory():
	while stored_data.size() > 0:
		var item = extract_last_item()
		_drop_item_into_world(item)
		print("Objeto expulsado: No hay estómago.")

func _enforce_capacity_limit(form_index: int):
	if player.transformation_module:
		var new_capacity = player.transformation_module.get_capacity(form_index)
		while stored_data.size() > new_capacity:
			var item = extract_last_item()
			_drop_item_into_world(item)
			print("Objeto expulsado: Capacidad excedida.")

func _drop_item_into_world(item: ConsumableItem):
	if item == null: return
	
	# 1. Añadimos el objeto AL ÁRBOL PRIMERO (Vital para los RigidBody3D en Godot 4)
	get_tree().current_scene.add_child(item)
	
	# 2. Posicionamiento (CORREGIDO: -basis.z es 'hacia adelante' en Godot)
	var dispersion = Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
	var spawn_pos = player.global_position + (-player.global_transform.basis.z * 1.5) + Vector3(0, 1.5, 0) + dispersion
	
	# Usamos global_position ahora que es hijo de la escena
	item.global_position = spawn_pos
	
	# Restauramos las lógicas internas del item
	item.set_picked_up(false)
	
	# 3. TRUCO DE FANTASMAS: Excepción de colisión permanente con el jugador
	if item is CollisionObject3D:
		item.add_collision_exception_with(player)
		get_tree().create_timer(1.0).timeout.connect(func():
			if is_instance_valid(item) and is_instance_valid(player):
				item.remove_collision_exception_with(player)
		)
	
	# 4. EFECTO DE CRECIMIENTO SÓLO VISUAL
	if is_instance_valid(item.mesh_instance):
		item.mesh_instance.scale = Vector3.ONE * 0.01 
		
		var tween = get_tree().create_tween()
		tween.tween_property(item.mesh_instance, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 5. Impulso físico hacia afuera (CORREGIDO: también -basis.z)
	var fuerza_impulso = (-player.global_transform.basis.z * randf_range(2.0, 4.0)) + Vector3(0, randf_range(3.0, 5.0), 0)
	item.apply_central_impulse(fuerza_impulso)
