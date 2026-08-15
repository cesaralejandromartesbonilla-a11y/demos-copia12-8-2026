extends Control

@onready var lista_categorias = $Margen/ContenedorPrincipal/ListaCategorias
@onready var contenedor_botones = $Margen/ContenedorPrincipal/ScrollContainer/ContenedorBotones
@onready var detalles_pieza = $Margen/ContenedorPrincipal/DetallesPieza
@onready var btn_cerrar = $Margen/ContenedorPrincipal/BtnCerrarMenu

var base_datos = {
	"Motor": [
		{"id": "v8_2.4L", "nombre": "Motor V8 2.4L", "ruta": "res://motores/v8_24l.tres"},
		{"id": "i6_4.0L", "nombre": "Motor I6 4.0L", "ruta": "res://motores/i6_40l.tres"}
	],
	"Caja de Cambios": [
		{"clase": "explorador", "nombre": "Caja OffRoad", "ruta": "res://cajas/offroad_exp.tres"},
		{"clase": "camion_pesado", "nombre": "Caja Arrastre 12 Vel", "ruta": "res://cajas/arrastre_12.tres"}
	],
	"Llantas": [
		{"pulgadas": 28.0, "nombre": "Llantas Barro 28\"", "ruta": "res://llantas/barro_28.tres"},
		{"pulgadas": 30.0, "nombre": "Llantas Todoterreno 30\"", "ruta": "res://llantas/at_30.tres"},
		{"pulgadas": 38.0, "nombre": "Llantas Monstruo 38\"", "ruta": "res://llantas/monster_38.tres"}
	],
	"Añadidos": [
		{"paquete": "paquete_basico", "nombre": "Quinta Rueda", "ruta": "res://addons/quinta_rueda.tres"},
		{"paquete": "paquete_pesos", "nombre": "Peso Muerto (5t)", "ruta": "res://addons/peso_5t.tres"}
	]
}

var vehiculo_actual_datos: Dictionary

func _ready() -> void:
	lista_categorias.item_selected.connect(_filtrar_categoria)
	btn_cerrar.pressed.connect(cerrar_menu)
	
	lista_categorias.add_item("Motor")
	lista_categorias.add_item("Caja de Cambios")
	lista_categorias.add_item("Llantas")
	lista_categorias.add_item("Añadidos")

func abrir_menu(datos_vehiculo: Dictionary) -> void:
	vehiculo_actual_datos = datos_vehiculo
	show()
	lista_categorias.select(0)
	_filtrar_categoria(0)

func cerrar_menu() -> void:
	hide()

func _filtrar_categoria(index: int) -> void:
	for hijo in contenedor_botones.get_children():
		hijo.queue_free()
	
	var categoria = lista_categorias.get_item_text(index)
	var datos_v = GlobalData.obtener_datos_vehiculo_activo()
	var specs = datos_v.get("especificaciones", {})
	
	print("Filtrando: ", categoria) # Debug en consola
	
	for pieza in base_datos[categoria]:
		var mostrar = true # Por defecto mostramos todo para probar
		
		# Solo filtramos si hay un requisito real escrito
		match categoria:
			"Motor":
				var req = specs.get("motor_estricto", "")
				if req != "" and pieza["id"] != req: mostrar = false
			"Llantas":
				var ideal = specs.get("llanta_ideal_pulgadas", 0.0)
				if ideal != 0.0 and abs(pieza["pulgadas"] - ideal) > 10.0: mostrar = false
		
		if mostrar:
			_crear_boton_pieza(categoria, pieza)

# Función mágica que crea botones por código
func _crear_boton_pieza(categoria: String, pieza: Dictionary) -> void:
	var btn = Button.new()
	btn.text = pieza["nombre"]
	btn.custom_minimum_size = Vector2(0, 60) # Altura del botón
	# btn.icon = load(pieza["ruta_imagen"]) # <-- Descomenta esto si agregas imágenes al diccionario
	
	# Conectamos el botón directamente a la función de equipar (bind le pasa los datos)
	btn.pressed.connect(_equipar_pieza.bind(categoria, pieza["ruta"], pieza["nombre"]))
	
	contenedor_botones.add_child(btn)
	
	# CHIVATO DE DEPURACIÓN:
	print("Se ha dibujado en pantalla el botón para: ", pieza["nombre"])

# Función que reemplaza al viejo botón de "Equipar"
func _equipar_pieza(categoria: String, ruta: String, nombre_pieza: String) -> void:
	if categoria == "Motor":
		vehiculo_actual_datos["ruta_motor"] = ruta
	elif categoria == "Llantas":
		vehiculo_actual_datos["ruta_llantas"] = ruta
	elif categoria == "Caja de Cambios":
		vehiculo_actual_datos["ruta_caja"] = ruta
	elif categoria == "Añadidos":
		vehiculo_actual_datos["ruta_addon"] = ruta
		
	detalles_pieza.text = "¡INSTALADO EXitosamente!\n" + nombre_pieza
	print("Se equipó: ", nombre_pieza, " (", ruta, ")")
