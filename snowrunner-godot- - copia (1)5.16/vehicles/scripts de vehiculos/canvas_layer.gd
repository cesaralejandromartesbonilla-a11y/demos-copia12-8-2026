extends CanvasLayer

# --- CONFIGURACIÓN ---
@export var nodo_camioneta: NodePath # Arrastra tu Vehiculo aquí en el inspector
var vehiculo: Node = null

# --- REFERENCIAS VISUALES (Ajusta las rutas a tus nodos reales del HUD) ---
# Si te da error "null instance", verifica que estas rutas sean correctas en tu escena
@onready var label_velocidad = $PanelInstrumentos/VBoxContainer/Velocimetro      # Ejemplo: Label texto "0 km/h"
@onready var label_marcha = $PanelInstrumentos/VBoxContainer/MarchaLabel         # Ejemplo: Label texto "D" / "N"
@onready var barra_rpm = $PanelInstrumentos/VBoxContainer/RPMProgress            # Ejemplo: TextureProgressBar o ProgressBar
@onready var barra_combustible = $PanelInstrumentos/VBoxContainer/CombustibleBar # Ejemplo: TextureProgressBar
@onready var icono_4x4 = $PanelInstrumentos/VBoxContainer/Indicador4x4           # Un TextureRect o Label
@onready var icono_diff = $PanelInstrumentos/VBoxContainer/IconoDiff             # Un TextureRect o Label

# Colores para estados (Verde encendido, Rojo/Gris apagado)
var color_activo = Color(0, 1, 0, 1) # Verde
var color_inactivo = Color(0.5, 0.5, 0.5, 0.5) # Gris oscuro

func _ready() -> void:
	# Intentar obtener la camioneta
	if nodo_camioneta:
		vehiculo = get_node(nodo_camioneta)
	
	if vehiculo:
		# Conectar las señales que creamos en Camioneta.gd
		# La sintaxis de Godot 4 para conectar señales es limpia:
		if vehiculo.has_signal("datos_actualizados"):
			vehiculo.datos_actualizados.connect(_actualizar_relojes)
		
		if vehiculo.has_signal("traccion_cambiada"):
			vehiculo.traccion_cambiada.connect(_actualizar_icono_4x4)
		
		if vehiculo.has_signal("dif_cambiado"):
			vehiculo.dif_cambiado.connect(_actualizar_icono_diff)
			
		# Inicializar estados visuales
		_actualizar_icono_4x4(vehiculo.es_4x4)
		_actualizar_icono_diff(vehiculo.dif_bloqueado)
	else:
		print("ERROR HUD: No has asignado el nodo Camioneta en el Inspector del HUD")

# --- ACTUALIZACIÓN CONTINUA ---
func _actualizar_relojes(combustible: float, velocidad: float, rpm: float) -> void:
	# 1. Velocidad (Texto)
	if label_velocidad:
		label_velocidad.text = str(int(velocidad)) + " km/h"
	
	# 2. RPM (Barra o Aguja)
	if barra_rpm:
		# Asumimos que la barra va de 0 a 3000 (o el max_rpm que pusiste en el coche)
		barra_rpm.value = rpm
		
	# 3. Combustible
	if barra_combustible:
		barra_combustible.value = combustible
		# Opcional: cambiar color si es bajo
		if combustible < 20:
			barra_combustible.modulate = Color(1, 0, 0) # Rojo alerta
		else:
			barra_combustible.modulate = Color(1, 1, 1)

	# 4. Simulación Visual de Marcha (D/N/R)
	# Como el script es caja automática simplificada, "adivinamos" la marcha visualmente
	if label_marcha:
		if vehiculo.motor_encendido:
			var direccion_input = Input.get_axis("press_s", "press_w")
			
			if velocidad < 2.0 and direccion_input == 0:
				label_marcha.text = "N" # Neutral / Parado
			elif direccion_input < 0: # Input S (frenar/atras)
				label_marcha.text = "R" # Retroceso
			else:
				label_marcha.text = "A" # Automática/Avance
		else:
			label_marcha.text = "OFF"

# --- ICONOS DE ESTADO ---
func _actualizar_icono_4x4(activo: bool) -> void:
	if icono_4x4:
		if activo:
			icono_4x4.modulate = color_activo
			# Si es un Label, podrías poner texto
			if icono_4x4 is Label: icono_4x4.text = "AWD: ON"
		else:
			icono_4x4.modulate = color_inactivo
			if icono_4x4 is Label: icono_4x4.text = "AWD: OFF"

func _actualizar_icono_diff(activo: bool) -> void:
	if icono_diff:
		if activo:
			icono_diff.modulate = color_activo
			if icono_diff is Label: icono_diff.text = "DIFF: LOCK"
		else:
			icono_diff.modulate = color_inactivo
			if icono_diff is Label: icono_diff.text = "DIFF: OPEN"
