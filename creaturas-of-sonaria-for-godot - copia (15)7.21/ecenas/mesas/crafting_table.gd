extends Node3D
class_name CraftingTable

@export var available_recipes: Array[RecipeData] = []
@onready var ui_scene = preload("res://ecenas/mesas/crafting_ui.tscn")
@onready var item_base_scene = preload("res://items/pickable_item.tscn")
@export var machine_name: String = "Mesa de Elaboración"

@onready var processor = get_node_or_null("ProcessorComponent")

@export_group("Visuales y Animación")
@export var anim_player: AnimationPlayer
@export var indicator_mesh: MeshInstance3D 
@export var light_material_index: int = 0 
@export var LuzNocturna: OmniLight3D

@onready var mat_off = preload("res://materiales/luces/luz_roja.tres")
@onready var mat_working = preload("res://materiales/luces/luz_verde.tres")
@onready var mat_jammed = preload("res://materiales/luces/luz_amarilla.tres")

@export_group("Cañón")
@export var ejector_point: Marker3D
@export var expulcion_aleatoria: bool = false
@export var fuerza_de_expluscion: float = 4.0

var is_in_use: bool = false

func _ready() -> void:
	add_to_group("estructuras")
	
	if not processor:
		for child in get_children():
			if child is ProcessorComponent: 
				processor = child
				break
				
	if processor:
		processor.optional_power_state.connect(_on_optional_power)
		processor.request_spawn_drop.connect(spawn_result)
		processor.machine_state_changed.connect(_on_machine_state_changed)
	else:
		print("Error: CraftingTable no encontró un ProcessorComponent.")

func _on_optional_power(has_power: bool) -> void:
	if LuzNocturna:
		LuzNocturna.visible = has_power

func interact(player: Node3D) -> void:
	if is_in_use: return
	
	for child in get_children():
		if child is ProcessorComponent: 
			processor = child
			break

	if ui_scene != null and processor != null:
		var player_hands = player.get_node_or_null("HandsInventory")
		
		if player_hands:
			if player_hands.item_in_right: _try_deposit(player_hands.item_in_right, processor, player_hands)
			if player_hands.item_in_left: _try_deposit(player_hands.item_in_left, processor, player_hands)
		
		var ui_instance = ui_scene.instantiate()
		get_tree().current_scene.add_child(ui_instance)
		
		ui_instance.setup(processor, player_hands, item_base_scene, machine_name)
		
		is_in_use = true
		ui_instance.tree_exited.connect(func(): is_in_use = false)
	else:
		print("Error: Falta UI o ProcessorComponent al intentar interactuar.")

func _try_deposit(item_node: Node3D, proc: ProcessorComponent, hands: Node) -> void:
	var data = item_node.data
	if proc.input_inv and proc.input_inv.can_accept(data):
		proc.input_inv.add_item(data)
		hands.consume_item(item_node)
	elif proc.fuel_inv and proc.fuel_inv.can_accept(data):
		proc.fuel_inv.add_item(data)
		hands.consume_item(item_node)

func spawn_result(item_data: ItemData) -> void:
	if expulcion_aleatoria:
		if item_base_scene:
			var drop = item_base_scene.instantiate()
			drop.data = item_data
			get_tree().current_scene.add_child(drop)
			
			drop.global_position = global_position + Vector3(0, 1.5, 0)
			
			if drop is RigidBody3D:
				var random_dir = Vector3(randf_range(-1.0, 1.0), 1.5, randf_range(-1.0, 1.0)).normalized()
				drop.apply_central_impulse(random_dir * fuerza_de_expluscion)
	else:
		if item_base_scene == null or ejector_point == null: 
			print("Error: Falta item_base_scene o un marker3D en la Máquina")
			return
			
		var drop = item_base_scene.instantiate()
		drop.data = item_data
		get_tree().current_scene.add_child(drop)
		
		drop.global_position = ejector_point.global_position
		
		if drop is RigidBody3D:
			var forward_dir = -ejector_point.global_transform.basis.z
			var shoot_dir = (forward_dir + Vector3(0, 0.5, 0)).normalized()
			drop.apply_central_impulse(shoot_dir * fuerza_de_expluscion) 

func _on_machine_state_changed(new_state: String) -> void:
	match new_state:
		"OFF", "NO_FUEL", "NO_POWER", "IDLE":
			_set_indicator_light(mat_off)
			if anim_player: 
				anim_player.play("idle")
		
		"WORKING":
			_set_indicator_light(mat_working)
			if anim_player and processor.current_recipe:
				var anim_name = "work"
				if anim_player.has_animation(anim_name):
					var current_anim = anim_player.get_animation(anim_name)
					var speed_scale = current_anim.length / processor.current_recipe.craft_time
					anim_player.play(anim_name, -1, speed_scale)
		
		"JAMMED":
			_set_indicator_light(mat_jammed)
			if anim_player: 
				anim_player.pause()

func _set_indicator_light(material: Material) -> void:
	if indicator_mesh and material:
		indicator_mesh.set_surface_override_material(light_material_index, material)
