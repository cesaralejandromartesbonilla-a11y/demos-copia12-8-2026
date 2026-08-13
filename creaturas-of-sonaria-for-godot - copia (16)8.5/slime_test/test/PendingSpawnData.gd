extends Node

## Autoload — registralo en Project Settings > Autoload como "PendingSpawnData".
## Es el único lugar seguro para pasar el ADN del Taller (una escena) al
## Mundo (otra escena completamente distinta): los autoloads son los únicos
## nodos que Godot garantiza que sobreviven un change_scene_to_file().

var has_pending_creature: bool = false
var pending_dna: CreatureDNA = null


## Llamado por AssemblerModule.finalize_creature() justo antes de cambiar de escena.
func stage_creature(dna: CreatureDNA) -> void:
	pending_dna = _duplicate_dna(dna)
	has_pending_creature = true


## Llamado por WorldCreatureSpawner al entrar a la escena del Mundo.
## Se "consume": una vez leído, se limpia solo — así un reload accidental
## del Mundo no vuelve a spawnear la misma criatura de nuevo.
func consume() -> CreatureDNA:
	var dna: CreatureDNA = pending_dna
	pending_dna = null
	has_pending_creature = false
	return dna


func _duplicate_dna(source: CreatureDNA) -> CreatureDNA:
	var copy := CreatureDNA.new()
	copy.species_name = source.species_name
	copy.skin_color = source.skin_color
	copy.baked_texture = source.baked_texture
	copy.morphology = source.morphology.duplicate()
	copy.chassis_scene = source.chassis_scene
	copy.is_humanoid = source.is_humanoid
	copy.base_capacity = source.base_capacity
	copy.has_internal_inventory = source.has_internal_inventory
	copy.base_jump_velocity = source.base_jump_velocity
	# duplicate(true): copia el Array y sus Dictionaries internos — así el
	# Taller puede seguir editando su propio active_dna.attached_parts sin
	# afectar a la copia que ya cruzó. Los CreaturePartData de adentro NO se
	# duplican (quedan como referencia compartida): son catálogo, no datos
	# por-criatura — duplicarlos sería trabajo de más sin ningún beneficio.
	copy.attached_parts = source.attached_parts.duplicate(true)
	return copy
