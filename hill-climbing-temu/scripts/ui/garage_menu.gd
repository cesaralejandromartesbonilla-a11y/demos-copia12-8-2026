extends Control

@onready var coins_label: Label = %CoinsLabel
@onready var loadout_label: Label = %LoadoutLabel
@onready var tab_container: TabContainer = %TabContainer
@onready var vehicles_list: VBoxContainer = %VehiclesList
@onready var maps_list: VBoxContainer = %MapsList
@onready var upgrades_vehicle_label: Label = %UpgradesVehicleLabel
@onready var engine_label: Label = %EngineLabel
@onready var engine_button: Button = %EngineButton
@onready var suspension_label: Label = %SuspensionLabel
@onready var suspension_button: Button = %SuspensionButton
@onready var tank_label: Label = %TankLabel
@onready var tank_button: Button = %TankButton
@onready var back_button: Button = %BackButton
@onready var play_button: Button = %PlayButton


func _ready() -> void:
	engine_button.pressed.connect(func() -> void: GameState.purchase_upgrade(UpgradeDefs.Type.ENGINE))
	suspension_button.pressed.connect(func() -> void: GameState.purchase_upgrade(UpgradeDefs.Type.SUSPENSION))
	tank_button.pressed.connect(func() -> void: GameState.purchase_upgrade(UpgradeDefs.Type.TANK))
	back_button.pressed.connect(_on_back_pressed)
	play_button.pressed.connect(_on_play_pressed)
	GameState.garage_changed.connect(_refresh_all)
	_refresh_all()


func _refresh_all() -> void:
	coins_label.text = "Monedas: %d" % GameState.total_coins

	var vehicle_def := GameState.get_selected_vehicle()
	var map_def := GameState.get_selected_map()
	var vehicle_name := vehicle_def.display_name if vehicle_def else "?"
	var map_name := map_def.display_name if map_def else "?"
	loadout_label.text = "Equipado: %s  ·  %s" % [vehicle_name, map_name]

	_refresh_vehicles()
	_refresh_maps()
	_refresh_upgrades()


func _refresh_vehicles() -> void:
	_clear_children(vehicles_list)
	for vehicle_def: VehicleDef in ContentRegistry.get_all_vehicles():
		vehicles_list.add_child(_build_vehicle_row(vehicle_def))


func _refresh_maps() -> void:
	_clear_children(maps_list)
	for map_def: MapDef in ContentRegistry.get_all_maps():
		maps_list.add_child(_build_map_row(map_def))


func _refresh_upgrades() -> void:
	var vehicle_def := GameState.get_selected_vehicle()
	var vehicle_name := vehicle_def.display_name if vehicle_def else "Vehículo"
	upgrades_vehicle_label.text = "Mejoras de: %s" % vehicle_name

	_update_upgrade_row(UpgradeDefs.Type.ENGINE, engine_label, engine_button)
	_update_upgrade_row(UpgradeDefs.Type.SUSPENSION, suspension_label, suspension_button)
	_update_upgrade_row(UpgradeDefs.Type.TANK, tank_label, tank_button)


func _build_vehicle_row(vehicle_def: VehicleDef) -> PanelContainer:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(48, 48)
	swatch.color = vehicle_def.preview_color
	row.add_child(swatch)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var title := Label.new()
	title.text = vehicle_def.display_name
	info.add_child(title)

	var desc := Label.new()
	desc.text = vehicle_def.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	info.add_child(desc)

	var action := Button.new()
	row.add_child(action)

	var unlocked := GameState.is_vehicle_unlocked(vehicle_def.id)
	var selected := GameState.selected_vehicle_id == vehicle_def.id

	if not vehicle_def.available:
		action.text = "Próximamente"
		action.disabled = true
	elif unlocked:
		action.text = "Equipado" if selected else "Equipar"
		action.disabled = selected
		action.pressed.connect(func() -> void: GameState.select_vehicle(vehicle_def.id))
	else:
		action.text = "Desbloquear (%d)" % vehicle_def.unlock_cost
		action.disabled = not GameState.can_unlock_vehicle(vehicle_def.id)
		action.pressed.connect(func() -> void: GameState.unlock_vehicle(vehicle_def.id))

	return panel


func _build_map_row(map_def: MapDef) -> PanelContainer:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(48, 48)
	swatch.color = map_def.ground_color
	row.add_child(swatch)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var title := Label.new()
	title.text = map_def.display_name
	info.add_child(title)

	var best := int(GameState.get_map_best_distance(map_def.id))
	var desc_text := map_def.description
	if best > 0:
		desc_text += "\nRécord: %d m" % best
	var desc := Label.new()
	desc.text = desc_text
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	info.add_child(desc)

	var action := Button.new()
	row.add_child(action)

	var unlocked := GameState.is_map_unlocked(map_def.id)
	var selected := GameState.selected_map_id == map_def.id

	if not map_def.available:
		action.text = "Próximamente"
		action.disabled = true
	elif unlocked:
		action.text = "Seleccionado" if selected else "Seleccionar"
		action.disabled = selected
		action.pressed.connect(func() -> void: GameState.select_map(map_def.id))
	else:
		action.text = "Desbloquear (%d)" % map_def.unlock_cost
		action.disabled = not GameState.can_unlock_map(map_def.id)
		action.pressed.connect(func() -> void: GameState.unlock_map(map_def.id))

	return panel


func _update_upgrade_row(type: UpgradeDefs.Type, info_label: Label, buy_button: Button) -> void:
	var vehicle_id := GameState.selected_vehicle_id
	var level := GameState.get_upgrade_level(type, vehicle_id)
	var cost := GameState.get_upgrade_cost(type, vehicle_id)

	info_label.text = "%s  ·  Nivel %d/%d\n%s" % [
		UpgradeDefs.get_display_name(type),
		level,
		UpgradeDefs.MAX_LEVEL,
		UpgradeDefs.get_description(type),
	]

	if not GameState.is_vehicle_unlocked(vehicle_id):
		buy_button.text = "Desbloquea el vehículo"
		buy_button.disabled = true
		return

	if cost < 0:
		buy_button.text = "Nivel máximo"
		buy_button.disabled = true
		return

	buy_button.text = "Mejorar (%d)" % cost
	buy_button.disabled = not GameState.can_purchase_upgrade(type, vehicle_id)


func _clear_children(container: Node) -> void:
	for child: Node in container.get_children():
		child.queue_free()


func _on_back_pressed() -> void:
	ScenePaths.go_to_main_menu()


func _on_play_pressed() -> void:
	ScenePaths.go_to_game()
