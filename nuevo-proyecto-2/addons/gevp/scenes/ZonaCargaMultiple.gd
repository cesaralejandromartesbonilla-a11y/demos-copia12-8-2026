extends Area3D

# 1. Definir los slots (puedes arrastrarlos al inspector o se buscan en _ready)
@export var slots: Array[Marker3D] = []

func _ready():
	body_entered.connect(_on_body_entered)
	
	# Si la lista está vacía, intentamos llenar los slots automáticamente
	# asumiendo que tienes un nodo llamado "Slots" con Marker3Ds dentro.
	if slots.is_empty():
		var nodos_slots = get_node_or_null("Slots")
		if nodos_slots:
			for hijo in nodos_slots.get_children():
				if hijo is Marker3D:
					slots.append(hijo)

# 2. Función que detecta la entrada de la caja
# En ZonaCargaMultiple.gd
func _on_body_entered(body: Node3D):
	if body.has_method("acoplar_a_vehiculo") and body.get("puede_acoplarse"):
		var slot_libre = buscar_slot_disponible()
		if slot_libre:
			slot_libre.set_meta("ocupado", true)
			# Llamamos a la función corregida
			body.acoplar_a_vehiculo(get_parent(), slot_libre)
			
			# Conectar para liberar el slot cuando la caja se suelte o borre
			if not body.tree_exited.is_connected(func(): slot_libre.set_meta("ocupado", false)):
				body.tree_exited.connect(func(): slot_libre.set_meta("ocupado", false))
		else:
			print("Remolque lleno")

# 3. LA FUNCIÓN QUE FALTABA (Asegúrate que esté alineada a la izquierda)
func buscar_slot_disponible() -> Marker3D:
	for s in slots:
		# Si no tiene el meta o es falso, está libre
		if not s.has_meta("ocupado") or s.get_meta("ocupado") == false:
			return s
	return null # Si todos están ocupados devuelve null

# 4. Función extra para limpiar todo manualmente
func liberar_todos_los_slots():
	for s in slots:
		s.set_meta("ocupado", false)
