extends Node3D
class_name ProceduralLimb

enum LimbType { LEG, ARM, HEAD, WEAPON, EXTRA }
@export var limb_type: LimbType = LimbType.ARM

@export var ik_node: IKModifier3D
@export var target_marker: ArmTracker 
@export var local_grip_point: Marker3D 

@export_category("Comportamiento Quimera")
@export var follow_camera: bool = true
@export var manual_override_target: Marker3D

var brain_reference: CharacterBody3D = null 

var visual_dummy: MeshInstance3D = null

func equip_visual(mesh: Mesh):
	if local_grip_point == null: return
	
	# 1. Crear un nuevo MeshInstance3D de la nada
	visual_dummy = MeshInstance3D.new()
	visual_dummy.mesh = mesh
	
	# 2. Pegarlo al marcador de la mano
	local_grip_point.add_child(visual_dummy)
	visual_dummy.position = Vector3.ZERO
	visual_dummy.rotation = Vector3.ZERO

func drop_current_item():
	# 3. Destruir el fantasma visual al soltar
	if is_instance_valid(visual_dummy):
		visual_dummy.queue_free()
		visual_dummy = null

func _ready():
	var current_parent = get_parent()
	while current_parent != null:
		if current_parent is CharacterBody3D and current_parent.has_method("register_limb"):
			brain_reference = current_parent
			break
		current_parent = current_parent.get_parent()
	
	if brain_reference:
		brain_reference.register_limb(self)

	if ik_node and ik_node.has_method("start"):
		ik_node.start()

func _exit_tree():
	if brain_reference and brain_reference.has_method("unregister_limb"):
		brain_reference.unregister_limb(self)

func update_limb(delta: float, brain_data: Dictionary):
	if not ik_node or not target_marker: 
		return

	match limb_type:
		LimbType.LEG:
			_process_leg_ik(delta, brain_data)
		LimbType.ARM, LimbType.WEAPON:
			_process_aim_ik(delta, brain_data)
		LimbType.HEAD:
			pass # Lógica de cabeza aquí

func _process_aim_ik(_delta: float, data: Dictionary):
	# PRIORIDAD 1: Ancla Manual
	if is_instance_valid(manual_override_target):
		target_marker.set_target(manual_override_target.global_position)
		
	# PRIORIDAD 2: Objeto (GrabPoint)
	elif data.has("grab_target") and data["grab_target"] != null:
		target_marker.set_target(data["grab_target"])
		
	# PRIORIDAD 3: Cámara
	elif follow_camera and data.has("aim_target") and data["aim_target"] != null:
		target_marker.set_target(data["aim_target"])
		
	# PRIORIDAD 4: Reposo
	else:
		target_marker.clear_target()

func _process_leg_ik(_delta: float, _data: Dictionary):
	pass



# Variable interna para saber qué sostiene este brazo actualmente
var held_object: Node3D = null

# Función que el Orquestador llamará para darle un objeto a este brazo
func equip_item(item: Node3D):
	if local_grip_point == null:
		push_warning("El brazo " + name + " no tiene un local_grip_point asignado en el Inspector.")
		return
		
	held_object = item
	# Lo emparentamos físicamente a la mano del brazo
	var current_parent = item.get_parent()
	if current_parent:
		current_parent.remove_child(item)
		
	local_grip_point.add_child(item)
	item.position = Vector3.ZERO
	item.rotation = Vector3.ZERO
