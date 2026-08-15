extends Node
class_name WorldCreatureSpawner

## Colgalo de cualquier nodo de tu escena del Mundo (ej. hijo directo de la
## raíz). En _ready() revisa si el Taller dejó una criatura esperando en
## PendingSpawnData y, si es así, la materializa acá.

@export var spawned_creature_scene: PackedScene = preload("res://slime_test/test/spawned_creature.tscn")  ## Ya precargada con tu ruta — cambiala acá si mueves el archivo
@export var spawn_point: Node3D  ## Dónde aparece — asignalo a un Marker3D del Mundo


func _ready() -> void:
	if not PendingSpawnData.has_pending_creature:
		return

	var dna: CreatureDNA = PendingSpawnData.consume()
	# call_deferred sobre TODA la función, no solo sobre add_child: si solo
	# el add_child se difiere, la línea siguiente (global_position) igual
	# se ejecuta antes de que el nodo termine de entrar al árbol y revienta
	# igual. Diferida entera, para cuando corre ya no hay ningún bloqueo.
	_spawn_creature.call_deferred(dna)


func _spawn_creature(dna: CreatureDNA) -> void:
	if not spawned_creature_scene:
		push_error("WorldCreatureSpawner: falta asignar 'Spawned Creature Scene' en el Inspector.")
		return

	var creature := spawned_creature_scene.instantiate()

	# El bootstrapper corre ANTES de add_child, a propósito: @onready
	# resuelve $SimpleLocomotion en el mismo instante en que el nodo entra
	# al árbol (add_child dispara _ready() ahí mismo). Si el hijo todavía
	# no existe en ESE instante, @onready nunca lo encuentra por más que lo
	# agreguemos un momento después — por eso esto tiene que pasar mientras
	# 'creature' todavía es un nodo huérfano, sin dueño.
	var bootstrapper := RequirementsBootstrapper.new()
	bootstrapper.ensure_structure_only(creature)

	get_tree().current_scene.add_child(creature)

	if spawn_point:
		creature.global_position = spawn_point.global_position
	else:
		push_warning("WorldCreatureSpawner: 'Spawn Point' no asignado — la criatura nace en (0,0,0). Si algo más del mundo también vive cerca del origen, van a superponerse.")

	# Reutiliza AssemblerModule tal cual — sin reescribir nada de la lógica
	# de ensamblaje ya probada en el Taller. No hace falta add_child(): sus
	# funciones solo tocan 'creature', no necesitan estar en el árbol.
	var assembler := AssemblerModule.new()
	assembler.active_dna = dna

	# Etapa 1b activa: visual + stats reales (velocidad, salto, hitbox).
	assembler.assemble_visuals(creature)
	assembler.apply_stat_contract(creature)
