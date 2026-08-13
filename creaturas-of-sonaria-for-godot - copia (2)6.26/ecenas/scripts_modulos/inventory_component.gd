extends Node
class_name InventoryComponent

signal inventory_changed

@export_group("Control de Almacén")
@export var max_capacity: int = 5
@export var allowed_categories: Array[String] = [] 

@export_group("Reglas de Interacción")
@export var player_can_insert: bool = true
@export var player_can_extract: bool = true 

var stored_items: Array[ItemData] = []

func can_accept(item: ItemData) -> bool:
	if stored_items.size() >= max_capacity: return false
	if allowed_categories.is_empty(): return true
	return allowed_categories.has(item.item_category)

func add_item(item: ItemData) -> bool:
	if can_accept(item):
		stored_items.append(item)
		inventory_changed.emit()
		return true
	return false

func remove_item(item: ItemData) -> void:
	if stored_items.has(item):
		stored_items.erase(item)
		inventory_changed.emit()

func extract_item_by_name(target_name: String) -> ItemData:
	for i in range(stored_items.size()):
		if stored_items[i].item_name == target_name:
			var item_found = stored_items[i]
			stored_items.remove_at(i)
			inventory_changed.emit()
			return item_found
			
	return null
