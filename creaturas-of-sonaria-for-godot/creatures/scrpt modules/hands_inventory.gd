extends Node
class_name HandsInventory

signal inventory_changed(left_text: String, right_text: String)

@export var max_weight_capacity: float = 50.0
@export var left_hand_marker: Marker3D
@export var right_hand_marker: Marker3D

var item_in_left: PickableItem = null
var item_in_right: PickableItem = null

func _ready() -> void:
	_update_ui()

func try_pick_up(item: PickableItem) -> bool:
	var data = item.data
	if data == null: return false
	
	var current_weight = _get_current_weight()
	if current_weight + data.weight_kg > max_weight_capacity:
		return false
	
	if data.slot_cost == 2:
		if item_in_left == null and item_in_right == null:
			_attach_to_hand(item, left_hand_marker, "both")
			return true
	else:
		if item_in_right == null:
			_attach_to_hand(item, right_hand_marker, "right")
			return true
		elif item_in_left == null:
			_attach_to_hand(item, left_hand_marker, "left")
			return true
			
	return false

func _attach_to_hand(item: PickableItem, marker: Marker3D, hand: String) -> void:
	# 1. Congelar fisicas.
	if item.has_method("set_picked_up"):
		item.set_picked_up(true)
		
	# 2. Posicionar en marcador.
	item.get_parent().remove_child(item)
	marker.add_child(item)
	item.position = Vector3.ZERO
	item.rotation = Vector3.ZERO
			
	# 3. Actualizar estado de manos.
	if hand == "right": item_in_right = item
	elif hand == "left": item_in_left = item
	elif hand == "both":
		item_in_left = item
		item_in_right = item
		
	_update_ui()

func drop_items() -> void:
	# 4. Soltar objetos en orden.
	if item_in_right != null:
		_drop_specific_item(item_in_right)
	elif item_in_left != null:
		_drop_specific_item(item_in_left)

func _drop_specific_item(item: PickableItem) -> void:
	if item == null: return
	
	# 5. Transferir al mundo.
	item.get_parent().remove_child(item)
	get_tree().current_scene.add_child(item)
	
	# 6. Posicionar frente al jugador.
	item.global_position = get_parent().global_position + (get_parent().global_basis.z * 1.5) + Vector3(0, 1, 0)
	
	# 7. Restaurar fisicas.
	if item.has_method("set_picked_up"):
		item.set_picked_up(false)
			
	# 8. Limpiar referencias.
	if item_in_right == item: item_in_right = null
	if item_in_left == item: item_in_left = null
	
	_update_ui()

func get_seed_in_hands() -> PickableItem:
	if item_in_right != null and item_in_right.data.is_seed: return item_in_right
	if item_in_left != null and item_in_left.data.is_seed: return item_in_left
	return null

func consume_item(item: PickableItem) -> void:
	if item_in_right == item: item_in_right = null
	if item_in_left == item: item_in_left = null
	if is_instance_valid(item):
		item.queue_free()
	_update_ui()

func _get_current_weight() -> float:
	var total = 0.0
	if item_in_right and item_in_right.data: total += item_in_right.data.weight_kg
	if item_in_left and item_in_left != item_in_right and item_in_left.data: 
		total += item_in_left.data.weight_kg
	return total

func _update_ui() -> void:
	# 9. Validar integridad de instancias.
	if item_in_left and not is_instance_valid(item_in_left): item_in_left = null
	if item_in_right and not is_instance_valid(item_in_right): item_in_right = null
	
	# 10. Limpiar residuos visuales.
	_clear_ghost_items()
	
	var left_txt = "Vacío"
	var right_txt = "Vacío"
	if item_in_left: left_txt = item_in_left.data.item_name
	if item_in_right: right_txt = item_in_right.data.item_name
	
	if item_in_left != null and item_in_left == item_in_right:
		left_txt = item_in_left.data.item_name + " (2 Manos)"
		right_txt = item_in_right.data.item_name + " (2 Manos)"
		
	inventory_changed.emit(left_txt, right_txt)

func set_farming_mode_active(active: bool) -> void:
	var seed_item = get_seed_in_hands()
	if not active and seed_item != null:
		if seed_item.has_method("remove_ghost"):
			seed_item.remove_ghost()

func _clear_ghost_items() -> void:
	# 11. Limpieza de mano izquierda.
	if left_hand_marker:
		for child in left_hand_marker.get_children():
			if child != item_in_left:
				child.queue_free()
				
	# 12. Limpieza de mano derecha.
	if right_hand_marker:
		for child in right_hand_marker.get_children():
			if child != item_in_right:
				child.queue_free()
