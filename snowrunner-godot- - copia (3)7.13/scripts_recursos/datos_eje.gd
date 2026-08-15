extends Resource
class_name DatosEje

@export_group("Rutas de Nodos (Llantas)")
@export var ruta_rueda_izq: NodePath
@export var ruta_rueda_der: NodePath

@export_group("Nombres de Huesos")
@export var hueso_brazo_izq: String
@export var hueso_brazo_der: String
@export var hueso_llanta_izq: String
@export var hueso_llanta_der: String

@export_group("Personalización del Eje")
@export var multiplicador_suspension: float = 2.0
@export var invertir_giro_izq: bool = false
@export var invertir_giro_der: bool = true
@export var es_eje_rigido: bool = false
