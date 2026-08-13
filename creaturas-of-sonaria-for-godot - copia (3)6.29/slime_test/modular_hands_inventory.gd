extends Node
class_name ModularHandsInventory

signal inventory_changed(status_text: String)

@export var max_weight_capacity: float = 50.0

# Diccionarios dinámicos. Clave: ProceduralLimb (el brazo), Valor: ConsumableItem (el objeto)
var active_arms: Array[ProceduralLimb] = []
var arm_contents: Dictionary = {}

# --- GESTIÓN DINÁMICA DE BRAZOS ---

func register_arm(limb: ProceduralLimb):
	if not active_arms.has(limb) and (limb.limb_type == limb.LimbType.ARM or limb.limb_type == limb.LimbType.WEAPON):
		active_arms.append(limb)
		arm_contents[limb] = null
		_update_ui()

func unregister_arm(limb: ProceduralLimb):
	if active_arms.has(limb):
		if arm_contents[limb] != null:
			_drop_specific_item(arm_contents[limb])
		active_arms.erase(limb)
		arm_contents.erase(limb)
		_update_ui()

# --- LÓGICA DE RECOLECCIÓN ---

func try_pick_up(item: ConsumableItem) -> bool:
	var current_weight = _get_current_weight()
	if current_weight + item.item_weight > max_weight_capacity:
		print("Demasiado pesado.")
		return false
	
	# Buscamos brazos libres
	var free_arms: Array[ProceduralLimb] = []
	for arm in active_arms:
		if arm_contents[arm] == null:
			free_arms.append(arm)
			
	# Verificamos si tenemos suficientes brazos para el objeto
	if free_arms.size() >= item.hands_required:
		_attach_to_arms(item, free_arms.slice(0, item.hands_required))
		return true
		
	print("No hay suficientes brazos libres.")
	return false

func _attach_to_arms(item: ConsumableItem, assigned_arms: Array[ProceduralLimb]) -> void:
	# 1. DESVINCULAR Y APAGAR EL OBJETO REAL
	var current_parent = item.get_parent()
	if current_parent:
		current_parent.remove_child(item)
		
	# Lo emparentamos al inventario modular (queda escondido)
	add_child(item)
	item.visible = false
	item.process_mode = Node.PROCESS_MODE_DISABLED # Esto apaga sus físicas y colisiones por completo
	
	# 2. DIBUJAR EL FANTASMA VISUAL EN EL BRAZO
	var primary_arm = assigned_arms[0]
	if item.item_mesh:
		primary_arm.equip_visual(item.item_mesh)
	else:
		push_warning("El item " + item.name + " no tiene un item_mesh asignado en el Inspector.")
	
	for arm in assigned_arms:
		arm_contents[arm] = item
		
	_update_ui()

# --- LÓGICA DE SOLTAR ---

func drop_all_items() -> void:
	# Usamos un array temporal para evitar modificar el diccionario mientras lo iteramos
	var items_to_drop = []
	for arm in active_arms:
		if arm_contents[arm] != null and not items_to_drop.has(arm_contents[arm]):
			items_to_drop.append(arm_contents[arm])
			
	for item in items_to_drop:
		_drop_specific_item(item)

func _drop_specific_item(item: ConsumableItem) -> void:
	if item == null: return
	
	# 1. Liberar los brazos (Esto destruye los fantasmas visuales)
	for arm in active_arms:
		if arm_contents[arm] == item:
			arm_contents[arm] = null
			if arm.has_method("drop_current_item"):
				arm.drop_current_item()
			
	# 2. RESTAURAR EL OBJETO REAL
	var current_parent = item.get_parent()
	if current_parent:
		current_parent.remove_child(item)
		
	get_tree().current_scene.add_child(item)
	
	# 3. Lo reactivamos a la realidad física
	item.visible = true
	item.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Restauramos sus físicas para que caiga
	if item is RigidBody3D:
		item.freeze = false
		item.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC # O el modo por defecto que uses
		for child in item.get_children():
			if child is CollisionShape3D:
				child.set_deferred("disabled", false)
	
	# 4. Lo posicionamos frente al jugador
	var player = get_parent()
	if player and player.camera_pivot:
		item.global_position = player.global_position + (-player.camera_pivot.global_transform.basis.z * 1.5) + Vector3(0, 1, 0)
	
	_update_ui()

# --- UTILIDADES ---

func _get_current_weight() -> float:
	var total = 0.0
	var counted_items = []
	for arm in active_arms:
		var item = arm_contents[arm]
		if item != null and not counted_items.has(item):
			total += item.item_weight
			counted_items.append(item)
	return total

func _update_ui() -> void:
	var status = "Manos:\n"
	if active_arms.size() == 0:
		status += "- Sin brazos acoplados"
	else:
		for i in range(active_arms.size()):
			var arm = active_arms[i]
			var item = arm_contents[arm]
			var item_name = item.item_name if item != null else "Libre"
			status += "- Brazo " + str(i + 1) + ": " + item_name + "\n"
			
	inventory_changed.emit(status)
