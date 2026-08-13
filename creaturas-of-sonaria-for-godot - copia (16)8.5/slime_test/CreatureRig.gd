class_name CreatureRig
extends Node3D

# ==========================================
# 🧍 MANIQUÍ DE PRUEBA — torso + extremidades opcionales
# ==========================================
# Arma una criatura simple usando varios Limb como hijos, cada uno con
# su propia posición/rotación. Cada Limb se construye y se anima solo
# (tiene su propio _ready()/_physics_process()) — este script solo los
# crea y los posiciona, no hace falta ningún bucle central llamándolos.
#
# El torso (columna) es lo único obligatorio — conceptualmente es el
# núcleo/cuerpo real del slime, todo lo demás cuelga de ahí. Los brazos
# son opcionales; desactívalos para el "Cuerpo B" (solo torso+piernas)
# y compáralo contra el "Cuerpo A" (con brazos) desde el mismo nodo.
#
# El origen de este nodo (0,0,0) es la cadera / base de la columna. Las
# piernas crecen HACIA ABAJO desde ahí — si quieres que el maniquí quede
# parado sobre un piso, sube este nodo a la altura que corresponda.

@export var include_arms: bool = true # false = "Cuerpo B": solo torso + piernas
@export var spine_segments: int = 4
@export var arm_segments: int = 3
@export var leg_segments: int = 3
@export var shoulder_height: float = 2.0

var limbs: Array[Limb] = []

func _ready() -> void:
	_build_limb("Columna", Vector3.ZERO, Vector3.ZERO, spine_segments)
	if include_arms:
		_build_limb("BrazoIzq", Vector3(-0.35, shoulder_height, 0), Vector3(0, 0, -90), arm_segments)
		_build_limb("BrazoDer", Vector3(0.35, shoulder_height, 0), Vector3(0, 0, 90), arm_segments)
	_build_limb("PiernaIzq", Vector3(-0.2, 0, 0), Vector3(180, 0, 0), leg_segments)
	_build_limb("PiernaDer", Vector3(0.2, 0, 0), Vector3(180, 0, 0), leg_segments)

func _build_limb(limb_name: String, local_pos: Vector3, rot_degrees: Vector3, count: int) -> void:
	var limb = Limb.new()
	limb.name = limb_name
	limb.segment_count = count
	# Posición/rotación ANTES de add_child — son propiedades locales, así
	# que quedan correctas sin importar cuándo se una al árbol (a
	# diferencia de global_transform, que si se asigna antes de add_child
	# termina aplicándose dos veces — el bug que ya cazamos en Limb).
	limb.position = local_pos
	limb.rotation_degrees = rot_degrees
	add_child(limb)
	limbs.append(limb)

func destroy_creature() -> void:
	for limb in limbs:
		if is_instance_valid(limb):
			limb.destroy()
	limbs.clear()
