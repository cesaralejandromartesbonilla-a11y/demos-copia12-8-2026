extends Control

@onready var btn_continuar = $VBoxContainer/BtnContinuar
@onready var btn_nueva_partida = $VBoxContainer/BtnNuevaPartida
@onready var btn_salir = $VBoxContainer/BtnSalir

func _ready() -> void:
	btn_continuar.pressed.connect(_on_continuar)
	btn_nueva_partida.pressed.connect(_on_nueva_partida)
	btn_salir.pressed.connect(get_tree().quit)
	
	# La magia: Si NO hay partida, bloqueamos (o escondemos) el botón Continuar
	if GlobalData.hay_partida_activa:
		btn_continuar.disabled = false
		btn_continuar.text = "Continuar Partida"
	else:
		btn_continuar.disabled = true
		btn_continuar.text = "No hay partida guardada"

func _on_continuar() -> void:
	# Si tiene un mapa guardado, lo mandamos ahí. Si no, al garaje.
	if GlobalData.mapa_actual_guardado != "":
		# IMPORTANTE: Usamos change_scene_to_file con un texto (String). 
		# Esto evita la corrupción de mapas.
		get_tree().change_scene_to_file(GlobalData.mapa_actual_guardado)
	else:
		get_tree().change_scene_to_file("res://ecenas/garaje_manager.tscn")

func _on_nueva_partida() -> void:
	# Borramos lo viejo, empezamos de cero y vamos al garaje a construir el camión
	GlobalData.borrar_partida()
	get_tree().change_scene_to_file("res://ecenas/garaje_manager.tscn")
