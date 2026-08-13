extends Resource
class_name CropVariantData

@export var nombre_variante: String = "Normal"
# La escena base (.tscn) que contiene el script CropSegment3D y sus Marker3D.
@export var scene: PackedScene

@export_group("Economía Individual")
@export var costo_evolucion: float = 5.0
@export var multiplicador_produccion: float = 1.0
@export var multiplicador_capacidad_hijos: float = 1.0

@export_group("Línea de Tiempo Visual")
# Ej. Flor: [0] Capullo, [1] Bulbo Semi-Abierto, [2] Flor Madura
# Ej. Fruta: [0] Brote Verde, [1] Fruta Mediana, [2] Fruta Madura Lista
@export var etapas_desarrollo: Array[Mesh] = []
