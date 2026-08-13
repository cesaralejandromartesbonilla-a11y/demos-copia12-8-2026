extends CropVisualData
class_name ProceduralVisualData

@export_group("Variantes Genéticas del Árbol (Listas de Mutation)")
@export var trunk_variants: Array[CropVariantData] = []
@export var branch_variants: Array[CropVariantData] = []
@export var leaf_variants: Array[CropVariantData] = []
@export var fruit_variants: Array[CropVariantData] = []
@export var flower_variants: Array[CropVariantData] = []

@export_group("Pesos de Probabilidad de Crecimiento")# odsoletas. solo existe por retrocompatibilidad
@export_range(0.0, 1.0) var branch_chance: float = 0.3
@export_range(0.0, 1.0) var leaf_chance: float = 0.5
@export_range(0.0, 1.0) var fruit_chance: float = 0.2
@export_range(0.0, 1.0) var flower_chance: float = 0.2

@export_group("Configuración Procedural")
@export var ticks_between_generations: float = 15.0 
@export var max_depth_limit: int = 4

@export_group("ADN y Perfil de Crecimiento")
## Cuántos segmentos de tronco apilará en total usando el sistema de empuje intercalario.
@export var altura_objetivo_tronco: int = 4
## Si está activo (Cocotero), la copa se desplazará íntegra hacia arriba al insertar troncos.
@export var tipo_crecimiento_copa: bool = true 
## ¿Pueden brotar ramas laterales de los segmentos del tronco?
@export var permitir_ramas_en_tronco: bool = false
## ¿Pueden brotar hojas directamente pegadas al tronco principal?
@export var permitir_hojas_en_tronco: bool = true
## Cuántos segmentos de distancia máxima puede extenderse una rama desde el tronco.
@export var max_profundidad_ramas: int = 2
## Si está activo, el árbol actuará como palmera: un solo eje central desnudo con una copa masiva en la cima.
## Si está desactivado, actuará como árbol frondoso, permitiendo ramificaciones en cualquier parte del tronco.
@export var eje_guia_unico: bool = false

@export_group("Física de Hojas (Estilo Cocotero)")
## Inclinación en grados hacia abajo para simular el peso de la palma/hoja (ej: -35).
@export var inclinacion_caida_hojas: float = -30.0
## Desviación aleatoria de la caída para que no todas tengan el mismo ángulo exacto.
@export var desvío_caida_aleatoria: float = 8.0
