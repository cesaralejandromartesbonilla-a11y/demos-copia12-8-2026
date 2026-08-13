class_name GearboxData
extends Resource

@export var requisitos_etiquetas: Array[String] = [] # Ej: ["camion"], ["suspension_alta", "camion"]
@export var id_nombre: String = "Caja Estándar"
@export var tiene_awd_conectable: bool = true
@export var tiene_dif_bloqueable: bool = true
@export var multiplicador_consumo_awd: float = 1.2
@export var multiplicador_consumo_dif: float = 1.1
