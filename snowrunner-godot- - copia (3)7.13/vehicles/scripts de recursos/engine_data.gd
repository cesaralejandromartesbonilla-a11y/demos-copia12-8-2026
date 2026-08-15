class_name EngineData
extends Resource

@export var requisitos_etiquetas: Array[String] = [] # Ej: ["camion"], ["suspension_alta", "camion"]
@export var id_nombre: String = "Motor Base"
@export var max_torque_nm: float = 600.0
@export var max_rpm: float = 3000.0
@export var consumo_base: float = 0.5
@export var curva_torque: Curve
