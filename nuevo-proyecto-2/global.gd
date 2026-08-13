# Global.gd
extends Node

var estado = 1  # 1 = a pie, 0 = en auto

@export var player_pos: Vector3
@export var player_rot: Vector3
@export var dinero: int
# Esta es la lista para los objetos RigidBody instanciados (camiones, items, etc.)
@export var dynamic_objects: Array[Dictionary] = [] 


func cambia_estado():
	if estado == 0:
		estado = 1
	else:
		estado = 0
