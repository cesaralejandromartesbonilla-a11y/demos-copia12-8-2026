# Recurso reutilizable: creá un .tres por tipo de rueda (ej. "config_delantera.tres",
# "config_trasera_camion.tres") y arrastralo al mismo slot "config" en BrazoSuspension
# y en RuedaFisica de cada esquina que lo comparta. Así configurás N ruedas creando
# 1-2 archivos, no repitiendo los mismos números N veces.
extends Resource
class_name ConfiguracionRueda

@export_group("Suspensión")
@export var masa_soportada_kg: float = 375.0
@export var angulo_hundimiento_grados: float = 6.0
@export var multiplicador_amortiguacion: float = 0.3
@export var factor_seguridad_torque: float = 4.0
@export var longitud_brazo: float = 0.4
@export var recorrido_maximo_grados: float = 15.0  # cuánto puede viajar el brazo antes de un tope físico duro

@export_group("Neumático")
@export var radio_rueda: float = 0.35
@export var curva_agarre: Curve
@export var deslizamiento_referencia: float = 2.0
@export var mu_superficie_default: float = 1.0
