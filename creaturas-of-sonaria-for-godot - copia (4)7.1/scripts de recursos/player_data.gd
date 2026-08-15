extends Resource
class_name PlayerData

@export var coins: int = 50
# Lista de diccionarios: [{"creature_path": "...", "instance_id": "12345"}, ...]
@export var owned_instances: Array[Dictionary] = []
