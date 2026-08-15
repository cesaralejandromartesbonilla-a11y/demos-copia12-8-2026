extends Resource
class_name savegame

# Datos del Jugador
@export var player_pos: Vector3
@export var player_rot: Vector3
@export var dinero: int
@export var inventory : int

# Lista para objetos instanciados (Camiones, cajas, etc.)
@export var dynamic_objects: Array[Dictionary] = []
