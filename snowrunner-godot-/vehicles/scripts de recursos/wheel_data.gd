class_name WheelData
extends Resource

@export var requisitos_etiquetas: Array[String] = [] # Ej: ["camion"], ["suspension_alta", "camion"]
@export var id_nombre: String = "Llantas Estándar"
@export var radio: float = 0.5
@export var friccion_base: float = 2.0
@export var friccion_barro: float = 0.8 # Cuánto patinan en el lodo
@export var rigidez_suspension: float = 30.0
@export var recorrido_suspension: float = 0.2
