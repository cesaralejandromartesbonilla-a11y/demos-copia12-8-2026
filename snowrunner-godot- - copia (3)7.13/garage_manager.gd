extends Node3D

@onready var camara = $CamaraGaraje
@onready var posiciones_vehiculos = $PosicionesVehiculos.get_children()
@onready var posiciones_camara = $PosicionesCamara.get_children()
@export var mapa_destino: PackedScene

# Referencias UI - Botones Principales
@onready var btn_customizar = $UI_Garaje/PanelBotones/BtnCustomizar
@onready var btn_tienda = $UI_Garaje/PanelBotones/BtnTienda
@onready var btn_mapas = $UI_Garaje/PanelBotones/BtnMapas
@onready var btn_almacen = $UI_Garaje/PanelBotones/BtnAlmacen
@onready var btn_salir = $UI_Garaje/PanelBotones/BtnSalir

# Referencias UI - Navegación
@onready var btn_anterior = $UI_Garaje/NavegacionSlots/BtnAnterior
@onready var btn_siguiente = $UI_Garaje/NavegacionSlots/BtnSiguiente



var vehiculos_instanciados: Array = [null, null, null, null, null]
var slot_actual: int = 0
var animando_camara: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # <--- AÑADE ESTA LÍNEA AQUÍ
	_conectar_botones()
	_cargar_vehiculos_del_global()
	
	# Sincronizar con el slot activo que dicta el GlobalData
	slot_actual = GlobalData.slot_activo
	_mover_camara_inmediato(slot_actual)
	_actualizar_estado_botones()

func _conectar_botones() -> void:
	btn_anterior.pressed.connect(_on_btn_anterior_pressed)
	btn_siguiente.pressed.connect(_on_btn_siguiente_pressed)
	
	btn_customizar.pressed.connect(_on_btn_customizar_pressed)
	btn_tienda.pressed.connect(_on_btn_tienda_pressed)
	btn_mapas.pressed.connect(_on_btn_mapas_pressed)
	btn_almacen.pressed.connect(_on_btn_almacen_pressed)
	btn_salir.pressed.connect(_on_btn_salir_pressed)

func _cargar_vehiculos_del_global() -> void:
	for i in range(5):
		var datos = GlobalData.garaje_slots[i]
		if datos["ocupado"] and datos["ruta_escena"] != "":
			var escena_vehiculo = load(datos["ruta_escena"]) as PackedScene
			if escena_vehiculo:
				var vehiculo = escena_vehiculo.instantiate()
				
				# 1. Apagamos el vehículo ANTES de agregarlo
				vehiculo.process_mode = Node.PROCESS_MODE_DISABLED
				
				# 2. Lo posicionamos ANTES de agregarlo (evita que la suspensión explote aquí también)
				vehiculo.global_transform = posiciones_vehiculos[i].global_transform
				
				# 3. Ahora sí, lo traemos al mundo
				add_child(vehiculo)
				
				vehiculos_instanciados[i] = vehiculo
				
	# RED DE SEGURIDAD: Después de cargar todos los camiones, obligamos al mouse a liberarse
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# --- LÓGICA DE CÁMARA ---

func _mover_camara_inmediato(indice: int) -> void:
	var target = posiciones_camara[indice]
	camara.global_transform = target.global_transform

func _mover_camara_animada(indice: int) -> void:
	if animando_camara: return
	animando_camara = true
	
	var target = posiciones_camara[indice]
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(camara, "global_position", target.global_position, 0.6)
	tween.tween_property(camara, "global_rotation", target.global_rotation, 0.6)
	
	tween.chain().tween_callback(func(): animando_camara = false)
	
	# Guardamos en el AutoLoad en qué slot nos quedamos
	GlobalData.slot_activo = indice
	_actualizar_estado_botones()

func _actualizar_estado_botones() -> void:
	var ocupado = GlobalData.garaje_slots[slot_actual]["ocupado"]
	btn_customizar.disabled = !ocupado
	btn_salir.disabled = !ocupado

# --- EVENTOS DE BOTONES ---

func _on_btn_anterior_pressed() -> void:
	if slot_actual > 0 and not animando_camara:
		slot_actual -= 1
		_mover_camara_animada(slot_actual)

func _on_btn_siguiente_pressed() -> void:
	if slot_actual < 4 and not animando_camara:
		slot_actual += 1
		_mover_camara_animada(slot_actual)

func _on_btn_customizar_pressed() -> void:
	$UI_Garaje/MenuCustomizacion.abrir_menu(GlobalData.obtener_datos_vehiculo_activo())
	print("Abriendo menú de customización para el slot ", slot_actual)
	# Aquí abriremos la UI de piezas en el siguiente paso

func _on_btn_tienda_pressed() -> void:
	print("Abriendo tienda de vehículos")

func _on_btn_mapas_pressed() -> void:
	if mapa_destino:
		get_tree().change_scene_to_packed(mapa_destino)
	else:
		print("ERROR: No le asignaste un mapa destino a este botón en el Inspector.")
	
	print("Abriendo menú de mapas")

func _on_btn_almacen_pressed() -> void:
	print("Abriendo el almacén 2D")

func _on_btn_salir_pressed() -> void:
	# Por ahora, cargamos directamente el de terrenos. 
	# Más adelante podemos hacer un sub-menú igual al de customización.
	get_tree().change_scene_to_file("res://mapas/mapa_demo1.tscn")
	# Ejemplo: get_tree().change_scene_to_file("res://Mapas/MapaA.tscn")
