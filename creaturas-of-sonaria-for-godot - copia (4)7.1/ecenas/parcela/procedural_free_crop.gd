extends Area3D
class_name ProceduralFreeCrop
 
enum State { GROWING, READY, PEST_INFESTED }
 
@export var max_niveles_estructurales: int = 4
@export var seed_data: SeedData = null
 
# 🔋 SISTEMA DE BATERÍA / VIDA DE LA BASE
@export_group("Sistema de Supervivencia")
@export var max_vida: float = 150.0 # Las bases suelen resistir un poco más que las ramas
var vida_actual: float = 150.0

var seed_item_data: ItemData = null
var growth_progress: float = 0.0
var current_water: float = 30.0 
var is_submerged: bool = false
var is_fertilized: bool = false
var is_checking_environment: bool = true
var last_expansion_milestone: float = 0.0
var root_segment: CropSegment3D = null
var current_state: State = State.GROWING
var nivel_estructural_arbol: int = 1
 
@onready var item_base_scene = preload("res://items/pickable_item.tscn")

# 🛠️ Referencias a los sub-componentes obreros
@onready var metabolism: CropMetabolism = $CropMetabolism
@onready var architecture: CropArchitecture = $CropArchitecture
 
func _ready() -> void:
	vida_actual = max_vida # Inicializar salud de la raíz
	add_to_group("crop_plot")
	area_entered.connect(func(area): if metabolism: metabolism._on_root_area_entered(area))
	area_exited.connect(func(area): if metabolism: metabolism._on_root_area_exited(area))

func initialize_crop(data: SeedData, original_item: ItemData) -> void:
	if metabolism:
		metabolism.start_metabolic_life(data, original_item)
 
#region MODULO: INTERACCIÓN Y COSECHA
func interact(_player: Node3D) -> void:
	if current_state == State.PEST_INFESTED: return
	_harvest_ripe_fruits()
 
func intentar_cosechar_frutos() -> bool:
	if not root_segment or not seed_data or not seed_data.result_item_data: return false
	var wrapper = [0]
	_extract_fruit_nodes(root_segment, wrapper)
	if wrapper[0] > 0:
		_ejecutar_efecto_sacudida()
		return true 
	return false
 
func _ejecutar_efecto_sacudida() -> void:
	var tween = create_tween()
	var rot_original = rotation
	tween.tween_property(self, "rotation:x", rot_original.x + 0.05, 0.05)
	tween.tween_property(self, "rotation:x", rot_original.x - 0.05, 0.08)
	tween.tween_property(self, "rotation", rot_original, 0.1)
 
func _harvest_ripe_fruits() -> void:
	if not seed_data or not seed_data.result_item_data: return
	var wrapper = [0]
	_extract_fruit_nodes(root_segment, wrapper)
 
func _extract_fruit_nodes(node: Node, counter: Array) -> void:
	if not node: return
	for child in node.get_children():
		if child is CropSegment3D and child.type == CropSegment3D.SegmentType.FRUIT:
			_spawn_item_en_posicion(seed_data.result_item_data, child.global_position)
			child.queue_free()
			counter[0] += 1
		else: _extract_fruit_nodes(child, counter)
 
func _spawn_item_en_posicion(item_data: ItemData, posicion_mundo: Vector3) -> void:
	if item_base_scene:
		var nuevo_item = item_base_scene.instantiate()
		nuevo_item.data = item_data
		get_tree().current_scene.add_child(nuevo_item)
		nuevo_item.global_position = posicion_mundo
		if nuevo_item is RigidBody3D:
			nuevo_item.apply_central_impulse(Vector3(randf_range(-1, 1), randf_range(1, 2), randf_range(-1, 1)))
#endregion

# =================================================================
# 🪓 INTERFAZ UNIFICADA DE DAÑO PARA LA BASE (TALA DIRECTA)
# =================================================================
func take_damage(amount: float) -> void:
	if vida_actual <= 0.0: return # Ya está en proceso de colapso
	
	vida_actual = max(0.0, vida_actual - amount)
	
	# Satisface visualmente el impacto haciendo temblar todo el árbol
	_ejecutar_efecto_sacudida()
	
	if vida_actual <= 0.0:
		_morir_y_desmoronar_arbol()

func _morir_y_desmoronar_arbol() -> void:
	# Si la base muere, le ordena al segmento raíz desmoronarse por completo
	if is_instance_valid(root_segment):
		root_segment.caer_segmento() # Esto detonará la física física en cascada de todo el árbol
		
	# Eliminamos la base lógica del suelo, ya que el árbol ha sido talado con éxito
	queue_free()
