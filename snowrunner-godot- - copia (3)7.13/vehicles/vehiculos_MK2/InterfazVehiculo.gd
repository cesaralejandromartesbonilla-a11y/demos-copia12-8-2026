extends CanvasLayer

@export var vehiculo: Node3D 

@onready var btn_traccion = $PanelPrincipal/VBoxContainer/PanelTraccion/VBoxContainer/BtnTraccion
@onready var btn_normal = $PanelPrincipal/VBoxContainer/PanelDireccion/VBoxContainer/BtnNormal
@onready var btn_opuesta = $PanelPrincipal/VBoxContainer/PanelDireccion/VBoxContainer/BtnOpuesta
@onready var btn_cangrejo = $PanelPrincipal/VBoxContainer/PanelDireccion/VBoxContainer/BtnCangrejo
@onready var btn_eje = $PanelPrincipal/VBoxContainer/PanelDireccion/VBoxContainer/BtnEje
@onready var btn_diferencial = $PanelPrincipal/VBoxContainer/PanelDireccion/VBoxContainer/BtnDiferencial

func _ready() -> void:
	if not vehiculo:
		print("Error: No se ha asignado el vehículo a la interfaz.")
		return
		
	# Lee las variables booleanas del vehículo y oculta los botones si no están permitidos
	btn_normal.visible = vehiculo.permitir_modo_normal
	btn_opuesta.visible = vehiculo.permitir_modo_opuesta
	btn_cangrejo.visible = vehiculo.permitir_modo_cangrejo
	btn_eje.visible = vehiculo.permitir_modo_eje
	
	_actualizar_texto_traccion()
	
	# Conectar las señales de "pressed" de los botones mediante funciones anónimas (lambdas)
	btn_traccion.pressed.connect(_on_btn_traccion_pressed)
	btn_diferencial.pressed.connect(_on_btn_diferencial_pressed)
	btn_normal.pressed.connect(func(): vehiculo.modo_direccion_actual = vehiculo.ModoDireccion.NORMAL)
	btn_opuesta.pressed.connect(func(): vehiculo.modo_direccion_actual = vehiculo.ModoDireccion.OPUESTA)
	btn_cangrejo.pressed.connect(func(): vehiculo.modo_direccion_actual = vehiculo.ModoDireccion.CANGREJO)
	btn_eje.pressed.connect(func(): vehiculo.modo_direccion_actual = vehiculo.ModoDireccion.EJE)

func _on_btn_traccion_pressed() -> void:
	# Invierte la tracción actual del vehículo
	vehiculo.traccion_total_activada = !vehiculo.traccion_total_activada
	_actualizar_texto_traccion()

func _on_btn_diferencial_pressed():
	vehiculo.diferencial_bloqueado = !vehiculo.diferencial_bloqueado

func _actualizar_texto_traccion() -> void:
	if vehiculo.traccion_total_activada:
		btn_traccion.text = "Tracción: TOTAL (AWD)"
	else:
		btn_traccion.text = "Tracción: PRIMARIA (2WD)"
