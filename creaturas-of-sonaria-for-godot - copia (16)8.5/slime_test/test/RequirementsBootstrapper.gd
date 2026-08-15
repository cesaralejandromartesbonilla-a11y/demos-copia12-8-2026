extends Node
class_name RequirementsBootstrapper

## Bootstrapper de Estado Cero para el Ensamblador de Quimeras.
##
## Se ejecuta ANTES de que el HUD evalúe su estado (_evaluate_zero_state)
## y garantiza que el entorno mínimo de construcción exista:
##   1. Estructura del player_dummy (nodo "Visuals", CollisionShape3D,
##      nodo "SimpleLocomotion")
##   2. CreatureDNA activo en el AssemblerModule
##   3. Al menos UNA pieza disponible por cada categoría (Pies, Manos,
##      Chasis, Torsos, Caderas, Cabezas, Decoraciones, Extensiones)
##   4. player_dummy sincronizado en BuildingSocketsManager (ese script
##      tiene su propio export separado del HUD — ver _ensure_sockets_manager_wiring)
##
## Lo estructural (nodo 1) se autogenera siempre por código, ya que es
## infraestructura pura y no afecta al gameplay/diseño.
## Las piezas (nodo 3) NUNCA se inventan por código: si faltan, se cargan
## desde recursos .tres preparados por el diseñador en disco.

## Una pieza fallback por CADA categoría (Pies, Manos, Chasis, etc.).
## Cada CreaturePartData ya trae su propio 'slot_type', así que el bootstrapper
## las indexa solo automáticamente. No hace falta que estén todas: la que
## falte simplemente no tendrá reparación automática y se reportará por consola.
## Arrástralas aquí en el Inspector.
@export var default_fallback_parts: Array[CreaturePartData] = []

## Carpeta alternativa de carga automática si el array de arriba está vacío
## (útil si este nodo se instancia por código / autoload). Debe contener
## archivos .tres de CreaturePartData, uno por categoría, nombre libre.
@export var default_fallback_parts_dir: String = "res://data/parts/defaults/"

## Radio/altura de la cápsula de colisión generada como fallback estructural.
@export var fallback_capsule_radius: float = 0.4
@export var fallback_capsule_height: float = 1.8

signal requirement_missing(requirement_name: String)
signal requirement_generated(requirement_name: String)
signal bootstrap_completed(used_fallback: bool)


## Punto de entrada único. Llamar desde HUD._ready() ANTES de _evaluate_zero_state().
## 'sockets_manager' es opcional (Node genérico: BuildingSocketsManager no declara
## class_name en el script original — si le agregas uno, puedo tipar esto mejor).
## Devuelve true si tuvo que generar/reparar algo (útil para loguear o avisar al diseñador).
func bootstrap(player: CharacterBody3D, assembler: AssemblerModule, sockets_manager: Node = null) -> bool:
	var used_fallback := false

	used_fallback = _ensure_player_structure(player) or used_fallback
	used_fallback = _ensure_dna(assembler) or used_fallback
	used_fallback = _ensure_default_parts(assembler) or used_fallback
	used_fallback = _ensure_sockets_manager_wiring(player, sockets_manager) or used_fallback

	bootstrap_completed.emit(used_fallback)
	return used_fallback


## Versión acotada de bootstrap(): SOLO valida/genera la estructura física
## mínima (Visuals, CollisionShape3D, DefaultHoldParent). No toca ADN,
## InventoryManager ni BuildingSocketsManager — pensada para reutilizar en
## criaturas ya terminadas (ej. CreatureSpawner), donde esas otras tres cosas
## no aplican (no hay UI de construcción sobre una criatura ya nacida).
func ensure_structure_only(player: CharacterBody3D) -> bool:
	return _ensure_player_structure(player)


# ---------------------------------------------------------------------------
# 1. Estructura mínima del player_dummy (100% autogenerada si falta)
# ---------------------------------------------------------------------------
func _ensure_player_structure(player: CharacterBody3D) -> bool:
	if not player:
		push_error("Bootstrapper: player_dummy es null, no se puede verificar la estructura.")
		return true

	var used_fallback := false

	# --- Nodo "Visuals" ---
	if not player.has_node("Visuals"):
		requirement_missing.emit("Visuals")
		var visuals := Node3D.new()
		visuals.name = "Visuals"
		player.add_child(visuals)
		requirement_generated.emit("Visuals")
		used_fallback = true
		print("Bootstrapper: nodo 'Visuals' generado automáticamente en player_dummy.")

	# --- CollisionShape3D referenciado por el script del player ---
	# Asume que player_dummy expone la propiedad exportada `collision_shape`
	# (tal como la usa AssemblerModule.apply_dna_transformation).
	if ("collision_shape" in player) and player.collision_shape == null:
		requirement_missing.emit("CollisionShape3D")

		var shape_node := CollisionShape3D.new()
		shape_node.name = "CollisionShape3D"

		var fallback_shape := CapsuleShape3D.new()
		fallback_shape.radius = fallback_capsule_radius
		fallback_shape.height = fallback_capsule_height
		shape_node.shape = fallback_shape

		player.add_child(shape_node)
		player.collision_shape = shape_node

		requirement_generated.emit("CollisionShape3D")
		used_fallback = true
		print("Bootstrapper: 'CollisionShape3D' generado automáticamente en player_dummy.")
	elif not ("collision_shape" in player):
		push_warning("Bootstrapper: player_dummy no expone la propiedad 'collision_shape'. No se puede verificar/generar la colisión.")

	# --- default_hold_parent: Marker3D bajo Visuals ---
	if ("default_hold_parent" in player) and player.default_hold_parent == null:
		requirement_missing.emit("DefaultHoldParent")

		var visuals_node := player.get_node_or_null("Visuals")
		if visuals_node:
			var hold_marker := Marker3D.new()
			hold_marker.name = "DefaultHold"
			visuals_node.add_child(hold_marker)
			player.default_hold_parent = hold_marker

			requirement_generated.emit("DefaultHoldParent")
			used_fallback = true
			print("Bootstrapper: Marker3D 'DefaultHold' generado automáticamente bajo Visuals.")
		else:
			push_warning("Bootstrapper: no se pudo generar 'default_hold_parent' porque 'Visuals' todavía no existe en este punto.")
	elif not ("default_hold_parent" in player):
		push_warning("Bootstrapper: player_dummy no expone 'default_hold_parent'. ¿Está usando simple_body.gd (o equivalente)?")

	# --- SimpleLocomotion: nodo hijo requerido por simple_body.gd ---
	# @onready var locomotion: SimpleLocomotion = $SimpleLocomotion revienta
	# duro en _ready() si este nodo no existe — a diferencia de collision_shape/
	# default_hold_parent (propiedades que simplemente pueden quedar null).
	if not player.has_node("SimpleLocomotion"):
		requirement_missing.emit("SimpleLocomotion")

		var locomotion_node := SimpleLocomotion.new()
		locomotion_node.name = "SimpleLocomotion"
		player.add_child(locomotion_node)

		requirement_generated.emit("SimpleLocomotion")
		used_fallback = true
		print("Bootstrapper: nodo 'SimpleLocomotion' generado automáticamente en player_dummy.")

	return used_fallback


# ---------------------------------------------------------------------------
# 2. ADN activo (ya existe cobertura parcial en AssemblerModule._ready(),
#    esto es una segunda red de seguridad si el bootstrapper corre antes)
# ---------------------------------------------------------------------------
func _ensure_dna(assembler: AssemblerModule) -> bool:
	if not assembler:
		push_error("Bootstrapper: AssemblerModule es null.")
		return true

	if not assembler.active_dna:
		requirement_missing.emit("CreatureDNA")
		assembler.active_dna = CreatureDNA.new()
		assembler.active_dna.species_name = "Quimera Sin Nombre"
		requirement_generated.emit("CreatureDNA")
		print("Bootstrapper: CreatureDNA generado automáticamente (estado cero real).")
		return true

	return false


# ---------------------------------------------------------------------------
# 3. Al menos UNA pieza disponible por cada categoría (Pies, Manos, Chasis...)
#    Fallback SIEMPRE desde disco, nunca geometría inventada por código.
# ---------------------------------------------------------------------------
func _ensure_default_parts(assembler: AssemblerModule) -> bool:
	var used_fallback := false
	var fallback_index := _index_fallback_parts_by_slot()
	var slot_count := CreaturePartData.SlotType.size()

	for slot_type in slot_count:
		# El chasis ya elegido en el ADN cubre esa categoría sin necesidad
		# de que exista en el InventoryManager (caso normal de juego ya avanzado).
		if slot_type == CreaturePartData.SlotType.CHASIS and assembler.active_dna.chassis_scene:
			continue

		var existing_parts: Array = []
		if InventoryManager and InventoryManager.has_method("get_parts_by_category"):
			existing_parts = InventoryManager.get_parts_by_category(slot_type)

		if not existing_parts.is_empty():
			continue  # Esta categoría ya tiene al menos una pieza real.

		var category_name := "Categoria_%d" % slot_type
		requirement_missing.emit(category_name)

		var fallback_part: CreaturePartData = fallback_index.get(slot_type, null)
		if not fallback_part:
			# No es un error fatal: esa categoría queda vacía hasta que el
			# diseñador cargue una pieza real o un fallback para ella.
			push_warning("Bootstrapper: la categoría %d no tiene piezas ni fallback disponible." % slot_type)
			continue

		if InventoryManager and InventoryManager.has_method("register_part"):
			InventoryManager.register_part(fallback_part)
			print("Bootstrapper: pieza por defecto registrada para la categoría %d." % slot_type)
		elif slot_type == CreaturePartData.SlotType.CHASIS:
			# Red de seguridad solo aplica al Chasis: es la única categoría
			# que puede "nacer" sin pasar por el InventoryManager.
			assembler.active_dna.chassis_scene = fallback_part.part_scene
			push_warning("Bootstrapper: InventoryManager no tiene 'register_part'. Chasis fallback asignado directo al ADN.")

		requirement_generated.emit(category_name)
		used_fallback = true

	return used_fallback


func _index_fallback_parts_by_slot() -> Dictionary:
	var index := {}

	var source_parts: Array[CreaturePartData] = default_fallback_parts
	if source_parts.is_empty():
		source_parts = _load_fallback_parts_from_dir()

	for part in source_parts:
		if part and not index.has(part.slot_type):
			index[part.slot_type] = part

	return index


func _load_fallback_parts_from_dir() -> Array[CreaturePartData]:
	var result: Array[CreaturePartData] = []

	if not DirAccess.dir_exists_absolute(default_fallback_parts_dir):
		return result

	var dir := DirAccess.open(default_fallback_parts_dir)
	if not dir:
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load(default_fallback_parts_dir.path_join(file_name))
			if res is CreaturePartData:
				result.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()

	return result


# ---------------------------------------------------------------------------
# 4. Sincronizar player_dummy en BuildingSocketsManager.
#    Ese script tiene su PROPIO export 'player_dummy', separado del que
#    asignas en el HUD — si quedan desincronizados, _build_part() falla
#    en silencio (marca el socket ocupado pero nunca acopla la pieza).
# ---------------------------------------------------------------------------
func _ensure_sockets_manager_wiring(player: CharacterBody3D, sockets_manager: Node) -> bool:
	if not sockets_manager:
		return false

	if not ("player_dummy" in sockets_manager):
		push_warning("Bootstrapper: el nodo de sockets no expone 'player_dummy'. ¿Es realmente tu BuildingSocketsManager?")
		return false

	if sockets_manager.player_dummy == null:
		requirement_missing.emit("SocketsManagerPlayerDummy")
		sockets_manager.player_dummy = player
		requirement_generated.emit("SocketsManagerPlayerDummy")
		print("Bootstrapper: 'player_dummy' sincronizado automáticamente en BuildingSocketsManager.")
		return true

	return false
