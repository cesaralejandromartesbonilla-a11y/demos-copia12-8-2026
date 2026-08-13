extends CanvasLayer

@export_category("Botones Originales")
@onready var resume_button: Button = $ColorRect/CenterContainer/VBoxContainer/ResumeButton
@onready var menu_button: Button = $ColorRect/CenterContainer/VBoxContainer/MenuButton
@onready var exit_button: Button = $ColorRect/CenterContainer/VBoxContainer/ExitButton

@export_category("Contenedor Desplegable")
@onready var toggle_debug_btn: Button = $ColorRect/ToggleDebugButton
@onready var vbox_container2: VBoxContainer = $ColorRect/VBoxContainer2
@onready var master_controls: Control = $ColorRect/MasterControlsContainer
@onready var master_save_btn: Button = $ColorRect/MasterControlsContainer/MasterSaveBtn
@onready var master_check: CheckButton = $ColorRect/MasterControlsContainer/MasterCheck
@onready var master_slider: HSlider = $ColorRect/MasterControlsContainer/MasterSlider
@onready var master_progress: ProgressBar = $ColorRect/MasterControlsContainer/MasterProgress
@onready var master_load_btn: Button = $ColorRect/MasterControlsContainer/MasterLoadBtn
@onready var menu_separator: HSeparator= $ColorRect/MenuSeparator

@export_category("Botones de Depuración Manual")
@onready var save_creature_btn: Button = $ColorRect/VBoxContainer2/SaveCreatureButton
@onready var load_creature_btn: Button = $ColorRect/VBoxContainer2/LoadCreatureButton
@onready var save_crops_btn: Button = $ColorRect/VBoxContainer2/SaveCropsButton
@onready var load_crops_btn: Button = $ColorRect/VBoxContainer2/LoadCropsButton
@onready var save_items_btn: Button = $ColorRect/VBoxContainer2/SaveItemsButton
@onready var load_items_btn: Button = $ColorRect/VBoxContainer2/LoadItemsButton

@export_category("Controles Autoguardado: Criaturas")
@onready var creature_check: CheckButton = $ColorRect/VBoxContainer2/CreatureSection/CreatureCheck
@onready var creature_slider: HSlider = $ColorRect/VBoxContainer2/CreatureSection/CreatureSlider
@onready var creature_progress: ProgressBar = $ColorRect/VBoxContainer2/CreatureSection/CreatureProgress

@export_category("Controles Autoguardado: Cultivos")
@onready var crops_check: CheckButton = $ColorRect/VBoxContainer2/CropsSection/CropsCheck
@onready var crops_slider: HSlider = $ColorRect/VBoxContainer2/CropsSection/CropsSlider
@onready var crops_progress: ProgressBar = $ColorRect/VBoxContainer2/CropsSection/CropsProgress

@export_category("Controles Autoguardado: Objetos")
@onready var items_check: CheckButton = $ColorRect/VBoxContainer2/ItemsSection/ItemsCheck
@onready var items_slider: HSlider = $ColorRect/VBoxContainer2/ItemsSection/ItemsSlider
@onready var items_progress: ProgressBar = $ColorRect/VBoxContainer2/ItemsSection/ItemsProgress

var timer_creature: Timer
var timer_crops: Timer
var timer_items: Timer
var timer_master: Timer

func _ready() -> void:
	visible = false
	
	# Conexiones originales y botones manuales
	resume_button.pressed.connect(_on_resume_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	save_creature_btn.pressed.connect(_on_save_creature_pressed)
	load_creature_btn.pressed.connect(_on_load_creature_pressed)
	save_crops_btn.pressed.connect(_on_save_crops_pressed)
	load_crops_btn.pressed.connect(_on_load_crops_pressed)
	save_items_btn.pressed.connect(_on_save_items_pressed)
	load_items_btn.pressed.connect(_on_load_items_pressed)
	master_save_btn.pressed.connect(_on_master_save_pressed)
	
	# 1. MENÚ DESPLEGABLE: Ocultar por defecto y conectar el botón toggle
	vbox_container2.visible = false
	toggle_debug_btn.text = "Mostrar Opciones Avanzadas"
	toggle_debug_btn.pressed.connect(_on_toggle_debug_pressed)
	
	# 2. INICIALIZACIÓN DE LOS 3 SISTEMAS DE AUTOGUARDADO
	timer_creature = _configurar_sistema("manual_save_creature", creature_check, creature_slider, creature_progress)
	timer_crops = _configurar_sistema("manual_save_crops", crops_check, crops_slider, crops_progress)
	timer_items = _configurar_sistema("manual_save_items", items_check, items_slider, items_progress)
	timer_master = _configurar_sistema("guardado_maestro", master_check, master_slider, master_progress)
	master_load_btn.pressed.connect(_on_master_load_pressed)
	_on_toggle_debug_pressed()

func _process(_delta: float) -> void:
	# Actualización en tiempo real de las 3 barras de progreso en base a sus respectivos temporizadores
	_actualizar_barra_progreso(timer_creature, creature_progress)
	_actualizar_barra_progreso(timer_crops, crops_progress)
	_actualizar_barra_progreso(timer_items, items_progress)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func _generar_copia_respaldo(ruta_original: String, ruta_respaldo: String) -> void:
	if FileAccess.file_exists(ruta_original):
		var error = DirAccess.copy_absolute(ruta_original, ruta_respaldo)
		if error == OK:
			print("[Sistema de Respaldo] Copia extra creada con éxito en: ", ruta_respaldo)
		else:
			printerr("[Sistema de Respaldo] Error al replicar archivo: ", error)

# ==============================================================================
# MOTOR DE CONFIGURACIÓN MODULAR PARA AUTOGUARDADOS
# ==============================================================================
func _configurar_sistema(metodo_guardado: String, check: CheckButton, slider: HSlider, progress: ProgressBar) -> Timer:
	# Creamos el Timer dinámicamente
	var nuevo_timer = Timer.new()
	nuevo_timer.one_shot = false
	nuevo_timer.process_mode = Node.PROCESS_MODE_PAUSABLE # Se congela si pausamos el juego
	add_child(nuevo_timer)
	
	# Configuración inicial de rangos en los Sliders (ej: de 1 a 30 minutos)
	slider.min_value = 1.0
	slider.max_value = 30.0
	slider.step = 0.5 # Permite saltos de medio minuto
	if slider.value == 0: slider.value = 5.0 # Valor por defecto si arranca en cero
	
	# Sincronizamos la barra con el rango máximo del slider
	progress.min_value = 0.0
	progress.max_value = slider.value
	progress.value = 0.0
	
	# Conectamos las señales usando expresiones Lambda (funciones anónimas rápidas)
	check.toggled.connect(func(activo: bool): 
		_actualizar_estado_timer(nuevo_timer, activo, slider.value, progress)
	)
	
	slider.value_changed.connect(func(nuevo_valor: float):
		progress.max_value = nuevo_valor
		# Si cambiamos el tiempo mientras está activo, reiniciamos el temporizador con el nuevo ritmo
		if check.button_pressed:
			_actualizar_estado_timer(nuevo_timer, true, nuevo_valor, progress)
	)
	
	nuevo_timer.timeout.connect(func():
		var mundo = get_tree().current_scene
		if mundo and mundo.has_method(metodo_guardado):
			print("[Autosave] Disparando guardado automático: ", metodo_guardado)
			mundo.call(metodo_guardado)
		progress.value = 0.0
	)
	
	# Arrancamos según el estado inicial de la UI
	_actualizar_estado_timer(nuevo_timer, check.button_pressed, slider.value, progress)
	return nuevo_timer

func _actualizar_estado_timer(timer: Timer, activo: bool, minutos: float, progress: ProgressBar) -> void:
	if activo:
		timer.start(minutos * 60.0)
	else:
		timer.stop()
		progress.value = 0.0

func _actualizar_barra_progreso(timer: Timer, progress: ProgressBar) -> void:
	if timer and not timer.is_stopped():
		var transcurrido = timer.wait_time - timer.time_left
		progress.value = transcurrido / 60.0

# ==============================================================================
# CONTROLES GENERALES DE LA INTERFAZ
# ==============================================================================
func toggle_pause() -> void:
	var new_pause_state = !get_tree().paused
	get_tree().paused = new_pause_state
	visible = new_pause_state
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED

func _on_resume_pressed() -> void: toggle_pause()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ecenas/main_menu.tscn")

func _on_exit_pressed() -> void: get_tree().quit()

func _on_toggle_debug_pressed() -> void:
	vbox_container2.visible = !vbox_container2.visible
	master_controls.visible = !vbox_container2.visible
	
	if menu_separator:
		menu_separator.visible = false
		menu_separator.visible = true 
	
	toggle_debug_btn.text = "Configuración Avanzada" if !vbox_container2.visible else "Volver al Maestro"

func _on_master_save_pressed() -> void:
	# Ejecuta todos los guardados a la vez
	_on_save_creature_pressed()
	_on_save_crops_pressed()
	_on_save_items_pressed()
	_generar_copia_respaldo("user://world_items_data.dat", "user://world_items_data.bak")

func _on_master_load_pressed() -> void:
	print("[HUD] Iniciando CARGA MAESTRA de todos los sistemas...")
	get_tree().paused = false # Despausamos preventivamente
	
	# Llamamos uno a uno a tus métodos de carga individual ya existentes
	_on_load_creature_pressed()
	_on_load_crops_pressed()
	_on_load_items_pressed()
	
	toggle_pause()

# ==============================================================================
# ENLACES DIRECTOS A LOS MÉTODOS MANUALES DEL MUNDO
# ==============================================================================
func _on_save_creature_pressed() -> void:
	if get_tree().current_scene.has_method("manual_save_creature"): get_tree().current_scene.manual_save_creature()

func _on_load_creature_pressed() -> void:
	if get_tree().current_scene.has_method("manual_load_creature"):
		get_tree().paused = false
		get_tree().current_scene.manual_load_creature()
		toggle_pause()

func _on_save_crops_pressed() -> void:
	if get_tree().current_scene.has_method("manual_save_crops"): get_tree().current_scene.manual_save_crops()

func _on_load_crops_pressed() -> void:
	if get_tree().current_scene.has_method("manual_load_crops"):
		get_tree().paused = false
		get_tree().current_scene.manual_load_crops()
		toggle_pause()

func _on_save_items_pressed() -> void:
	if get_tree().current_scene.has_method("manual_save_items"): get_tree().current_scene.manual_save_items()

func _on_load_items_pressed() -> void:
	if get_tree().current_scene.has_method("manual_load_items"):
		get_tree().paused = false
		get_tree().current_scene.manual_load_items()
		toggle_pause()
