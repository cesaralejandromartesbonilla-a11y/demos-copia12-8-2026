#script global de la ecena 

extends Node3D

var template_explosion = preload("res://addons/example/scenes/Explosion/Explosion.tscn")

@onready var aircraft = get_node("Aircraft")

var is_reloading_fuel = false

func _ready():
	## LOADING DATA
	# If singleton has preloaded static save data, apply it to the scene
	if SaveManager.loaded_data != null:
		load_data(SaveManager.loaded_data)
		# Empty static data
		SaveManager.loaded_data = null
	
	# Try to load config file
	# If config file does not exist, load default values

	var cr = $Simulation/ColorRect
	var water = $Water
	var sim_tex = $Simulation.get_texture()
	var col_tex = $Collision.get_texture()

	water.mesh.surface_get_material(0).set_shader_parameter('simulation', sim_tex)
	water.mesh.surface_get_material(0).set_shader_parameter('simulation2', sim_tex)

	aircraft.connect("crashed", Callable(self, "_on_Aircraft_crashed"))
	aircraft.connect("parked", Callable(self, "_on_Aircraft_parked"))
	aircraft.connect("moved", Callable(self, "_on_Aircraft_moved"))
	
	$Aircraft/Engine.connect("update_interface", Callable($Aircraft/Model/MovingParts/Engine, "_on_Engine_update_interface"))
	$Aircraft/Steering.connect("update_interface", Callable($Aircraft/Model/MovingParts/Steering, "_on_Steering_update_interface"))
	$Aircraft/Flaps.connect("update_interface", Callable($Aircraft/Model/MovingParts/Flaps, "_on_Flaps_update_interface"))
	$Aircraft/LandingGear.connect("update_interface", Callable($Aircraft/Model/MovingParts/LandingGear, "_on_LandingGear_update_interface"))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_Aircraft_crashed(_impact_velocity):
	var new_explosion = template_explosion.instantiate()
	add_child(new_explosion)
	new_explosion.global_transform.origin = $Aircraft.global_transform.origin
	new_explosion.explode()
	aircraft.queue_free()
	await get_tree().create_timer(2.0).timeout
	load_data


func _on_Aircraft_parked():
	print("PARKED")
	if $FuelArea.overlaps_body(aircraft):
		# Parked on runway - refuel
		is_reloading_fuel = true
		print("RELOADING FUEL")


func _on_Aircraft_moved():
	# Started moving, if reloading fuel, stop
	if is_reloading_fuel:
		is_reloading_fuel = false
		print("REFUEL STOPPED")

func _physics_process(delta):
	if is_reloading_fuel and is_instance_valid(aircraft):
		var amount_per_second = 5.0
		var is_aircraft_full = aircraft.load_energy("fuel", amount_per_second * delta)
		if is_aircraft_full:
			is_reloading_fuel = false
			print("REFUEL COMPLETE")


func _on_BtnBack_pressed():
	get_tree().change_scene_to_file("res://example/ExampleList.tscn")
	

## SAVES=========================================================================================

const SAVE_PATH = "user://gamesave.save"

# Collect the data from the scene
func save_data(data: SaveGame):
	var save_file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	
	# Buscamos todos los nodos que deben persistir
	var save_nodes = get_tree().get_nodes_in_group("Persistente")
	
	for node in save_nodes:
		# Verificamos que no sea un nodo base del escenario
		if node.scene_file_path.is_empty():
			continue

		var node_data = node.save() # Llamamos a la función del objeto
		var json_string = JSON.stringify(node_data)
		save_file.store_line(json_string)
	
	print("Partida Guardada")
	#Collect data from the player node
	data = $Player.save_data(data)
	
	# Get all nodes from the special group
	var transforms = get_tree().get_nodes_in_group("save_transform")
	for t in transforms:
		var t_data = {
			"name": t.name,
			"pos": t.position,
			"rot": t.rotation,
			"spawned": false
		}
	var existing_nodes = get_tree().get_nodes_in_group("Persistente")
	for t in transforms:
		var t_data = {
			"name": t.name,
			"pos": t.position,
			"rot": t.rotation,
			"filename" : get_scene_file_path(),
			"parent" : get_parent().get_path(),
			"pos_x" : position.x,
			"pos_y" : position.y,
			"pos_z" : position.z,
			"spawned": false
		}
		# Check if node was spawned
		# so that loader could respawn it
		if t.has_meta("type"):
			t_data.spawned = true
			t_data.type = t.get_meta("type")
		data.transforms.append(t_data)
		
	
	return data

# Apply loaded data to the scene
func load_data(data: SaveGame):
	if not FileAccess.file_exists(SAVE_PATH):
		return # No hay partida guardada

	# Limpiar instancias actuales antes de cargar para evitar duplicados
	var existing_nodes = get_tree().get_nodes_in_group("Persistente")
	for n in existing_nodes:
		n.queue_free()

	var save_file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	
	while save_file.get_position() < save_file.get_length():
		var json_string = save_file.get_line()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
# En SaveManager.gd, dentro de la función load_game()
# ... (código anterior para abrir archivo y parsear JSON) ...

		if parse_result == OK:
			var dat = json.data
			
			# ... (instanciar y añadir al árbol) ...
			var new_object = load(data["filename"]).instantiate()
			get_node(data["parent"]).add_child(new_object)
			
			# Restauramos la posición
			new_object.position = Vector3(data["pos_x"], data["pos_y"], data["pos_z"])
			
			# Restauramos las velocidades (específico para RigidBody3D)
			# Verificamos que el objeto sea un RigidBody3D o tenga las propiedades
			if new_object is RigidBody3D:
				new_object.linear_velocity = Vector3(data["lin_vel_x"], data["lin_vel_y"], data["lin_vel_z"])
				new_object.angular_velocity = Vector3(data["ang_vel_x"], data["ang_vel_y"], data["ang_vel_z"])
			
			# Restauramos otras propiedades
			new_object.add_to_group("Persistente")

	print("Partida Cargada")

	%Player.load_data(data)
	
	var transforms = get_tree().get_nodes_in_group("save_transform")
	for d in data.transforms:
		if d.spawned == false:
			# Apply to preloaded objects
			for t in transforms:
				if t.name == d.name:
					if t is RigidBody3D:
						t.linear_velocity = Vector3.ZERO
						t.angular_velocity = Vector3.ZERO
					t.position = d.pos
					t.rotation = d.rot
		else:
			# Spawn a new object
			dispense_object(d.type, d.pos, d.rot)

## SCENE-RELATED METHODS


func turn_cannon(angle, anim):
	if anim:
		$BallDispenser/SourcePoint/Rotating.goal = -angle
		$BallDispenser/SourcePoint/Rotating.start_rotation()
	else:
		$BallDispenser/SourcePoint.rotation_degrees = Vector3(0, -angle, 0)

func dispense_object(type, pos = null, rot = null):
	var obj = load("res://objects/ball.tscn").instantiate()
	add_child(obj)
	obj.set_type(type)
	if pos == null:
		obj.position = $BallDispenser/SourcePoint/Source.global_position
		obj.apply_impulse($BallDispenser/SourcePoint/Source.global_transform.basis.y * 6)
	else:
		obj.position = pos
		obj.rotation = rot

@warning_ignore("integer_division")
## CONFIGS

# Applying configs to the scene
# and displaying the values on UI elements
# Normally it would be two separate processes,
# as settings UI would be in the menu scene
func configs_load():
	var aa_value = SaveManager.config.get_value("Graphics", "antialiasing", 0)
	RenderingServer.viewport_set_screen_space_aa(get_tree().get_root().get_viewport_rid(), aa_value)
	%FieldAA.set_pressed_no_signal(aa_value)
	var ao_value = SaveManager.config.get_value("Graphics", "occlusion", false)
	$Camera3D.environment.ssao_enabled = ao_value
	%FieldAO.set_pressed_no_signal(ao_value)

# Saving configs to persistent variable
# Just collecting data from objects and UI
# Normally the most of the data will be just stored in the variable
func configs_save():
	SaveManager.config.set_value("Gameplay", "player_speed", $Player.speed)
	SaveManager.config.set_value("Gameplay", "cannon_angle", %CannonSlider.value)
	SaveManager.config.set_value("Graphics", "antialiasing", 1 if %FieldAA.toggle_mode else 0)
	SaveManager.config.set_value("Graphics", "occlusion", %FieldAO.toggle_mode)
	SaveManager.config_save()

## INPUT

# Waiting for F5-F6 buttons
func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_released("press_f11"):
		SaveManager.game_save("test_save")
	elif Input.is_action_just_released("press_f12"):
		SaveManager.game_load("test_save")

# Save button
# It could open an UI to enter a savegame name instead
func _on_button_save():
	SaveManager.full_save()

# Load button
# It could be disabled if there are no save files
func _on_button_load():
	SaveManager.full_load()
	

func _on_speed_slider(_value_changed):
	$Player.speed = %SpeedSlider.value


func _on_cannon_angle_slider(_value_changed):
	var angle = %CannonSlider.value
	turn_cannon(angle, true)


func _on_field_aa_toggled(button_pressed):
	var value = Viewport.SCREEN_SPACE_AA_FXAA if button_pressed else 0
	RenderingServer.viewport_set_screen_space_aa(get_tree().get_root().get_viewport_rid(), value)


func _on_field_ao_toggled(button_pressed):
	$Camera3D.environment.ssao_enabled = button_pressed


func _on_button_save_configs():
	configs_save()


func _on_button_reset_configs():
	SaveManager.config_load(SaveManager.file_config_default)
	SaveManager.config_save()


func save_instanced_objects(data: SaveGame):
	data.dynamic_objects.clear() # Limpiar antes de guardar
	
	# Buscamos todos los RigidBody que compraste
	# Asumo que les pusiste el grupo "save_transform" como vi en tu código
	var objects_to_save = get_tree().get_nodes_in_group("save_transform")
	
	for obj in objects_to_save:
		var dict = {
			"scene_path": obj.scene_file_path,
			"pos": obj.global_position,
			"rot": obj.global_rotation,
			"linear_vel": obj.linear_velocity if obj is RigidBody3D else Vector3.ZERO
		}
		data.dynamic_objects.append(dict)

func load_instanced_objects(data: SaveGame):
	# 1. Borrar los actuales para no duplicar
	for old_obj in get_tree().get_nodes_in_group("save_transform"):
		old_obj.queue_free()
		
	# 2. Recrear desde el recurso
	for item_data in data.dynamic_objects:
		var scene = load(item_data["scene_path"])
		var instance = scene.instantiate()
		
		get_tree().current_scene.add_child(instance)
		
		instance.global_position = item_data["pos"]
		if instance is RigidBody3D:
			instance.linear_velocity = item_data["linear_vel"]
		
		instance.add_to_group("save_transform")
