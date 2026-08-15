extends Resource
class_name LimbSocketConfig

## El nombre exacto del hueso en el Skeleton3D donde se cortará/pegará la pieza.
@export var bone_name: String = ""

## La escena (.tscn) de la extremidad modular que se va a instanciar en ese hueso.
@export var limb_scene: PackedScene
