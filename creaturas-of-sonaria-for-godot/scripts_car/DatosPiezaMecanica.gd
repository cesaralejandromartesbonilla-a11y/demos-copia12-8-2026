extends Resource
class_name DatosPiezaMecanica

## Catálogo de una pieza acoplable. Equivalente a CreaturePartData del
## proyecto de criaturas, pero sin nada de slots/stats de criatura — solo
## lo que EnsambladorMecanico necesita para instanciar y clasificar la pieza.
## No incluye LARGUERO a propósito: el larguero no se acopla a un socket,
## es la base sobre la que se para todo lo demás.

enum PartType { MOTOR, ENGRANAJE, RUEDA }

@export var display_name: String = ""
@export var part_type: PartType = PartType.MOTOR
@export var part_scene: PackedScene
