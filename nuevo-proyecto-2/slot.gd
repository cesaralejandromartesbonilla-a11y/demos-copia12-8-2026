extends Area3D

signal slot_clicked(slot_ref)

# ¿Qué objeto tengo guardado? (Por ahora usaremos Node3D, luego Recursos)
var stored_item: Node3D = null
@onready var item_point: Marker3D = $ItemPoint
@onready var visual_mesh: MeshInstance3D = $MeshInstance3D

# Colores para feedback visual
var color_idle = Color(0.2, 0.2, 0.2)
var color_hover = Color(1.0, 0.6, 0.0) # Naranja Astroneer

func _ready() -> void:
	# Conectamos las señales del mouse (propias del Area3D)
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Inicializar material para cambiar color (asegúrate de que el mesh tenga material)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color_idle
	visual_mesh.material_override = mat

func _on_mouse_entered():
	visual_mesh.material_override.albedo_color = color_hover

func _on_mouse_exited():
	visual_mesh.material_override.albedo_color = color_idle

func _on_input_event(_camera, _event, _position, _normal, _shape_idx):
	# Detectar Click Izquierdo
	if _event is InputEventMouseButton and _event.pressed and _event.button_index == MOUSE_BUTTON_LEFT:
		print("Slot clickeado: ", name)
		slot_clicked.emit(self)

# Función para "Guardar" un objeto aquí visualmente
func equip_item(item: Node3D):
	if stored_item: return # Ya está lleno
	
	stored_item = item
	# Lo hacemos hijo del slot para que se mueva con él
	item.get_parent().remove_child(item)
	item_point.add_child(item) 
	item.position = Vector3.ZERO
	item.rotation = Vector3.ZERO
