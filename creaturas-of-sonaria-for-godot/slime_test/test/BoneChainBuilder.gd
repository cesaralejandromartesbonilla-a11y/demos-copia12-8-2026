extends Node
class_name BoneChainBuilder

## Sistema de creación de huesos — Parte 1 de 3.
## (1: esto — huesos. 2: capa visual, cilindros/cápsulas. 3: crecer segmentos
## nuevos a partir de los anteriores, usando 1 y 2 juntos.)
##
## Envuelve un Skeleton3D y agrega huesos en cadena, cada uno naciendo en la
## PUNTA del anterior. Todavía sin nada visual a propósito — eso es la Parte 2.
##
## Nota técnica: Skeleton3D tiene un bug conocido (godotengine/godot#103623)
## donde set_bone_rest() por código no actualiza get_bone_global_rest()
## correctamente. Por eso acá NUNCA se lee el rest global — todo se calcula
## en espacio local del padre, llevando la cuenta de longitudes nosotros
## mismos. Si en algún momento hace falta la posición global de verdad, hay
## que confirmar primero si ese bug sigue vivo en tu versión de Godot.

@export var skeleton: Skeleton3D

## bone_name -> longitud. Skeleton3D no tiene un campo nativo de "longitud
## de hueso" (es más bien convención de Blender/Maya) — lo llevamos acá
## para que cada hueso nuevo sepa dónde nace: en la punta de su padre.
var _bone_lengths: Dictionary = {}


## Agrega un hueso nuevo de 'length' unidades, extendiéndose a lo largo del
## eje +Y local (misma convención que ya usamos en los esqueletos de piezas).
## 'parent_bone_name' vacío = hueso raíz de la cadena.
## Devuelve el nombre del hueso creado, o "" si falló.
func add_segment(bone_name: String, length: float, parent_bone_name: String = "") -> String:
	if not skeleton:
		push_error("BoneChainBuilder: no hay Skeleton3D asignado.")
		return ""
	if skeleton.find_bone(bone_name) != -1:
		push_error("BoneChainBuilder: ya existe un hueso llamado '%s'." % bone_name)
		return ""

	var parent_idx := -1
	if parent_bone_name != "":
		parent_idx = skeleton.find_bone(parent_bone_name)
		if parent_idx == -1:
			push_error("BoneChainBuilder: no existe el hueso padre '%s'." % parent_bone_name)
			return ""

	skeleton.add_bone(bone_name)
	# No confío en que add_bone() devuelva el índice — lo busco por nombre,
	# así funciona sin importar la versión exacta de Godot.
	var new_idx := skeleton.find_bone(bone_name)
	if new_idx == -1:
		push_error("BoneChainBuilder: add_bone() no generó el hueso esperado.")
		return ""

	skeleton.set_bone_parent(new_idx, parent_idx)

	# Origen local: (0,0,0) si es raíz, o la punta del padre si tiene uno —
	# calculado a mano, nunca leído de get_bone_global_rest() (ver nota del bug arriba).
	var local_origin := Vector3.ZERO
	if parent_bone_name != "":
		var parent_length: float = _bone_lengths.get(parent_bone_name, 0.0)
		local_origin = Vector3(0, parent_length, 0)

	skeleton.set_bone_rest(new_idx, Transform3D(Basis.IDENTITY, local_origin))
	_bone_lengths[bone_name] = length

	return bone_name


## Longitud guardada de un hueso ya creado (0.0 si no existe).
func get_bone_length(bone_name: String) -> float:
	return _bone_lengths.get(bone_name, 0.0)


## Nombres de huesos en orden de creación (equivale al orden de la cadena
## si cada uno se agregó con el anterior como padre).
func get_chain() -> Array[String]:
	var names: Array[String] = []
	for bone_name in _bone_lengths:
		names.append(bone_name)
	return names


func _ready() -> void:
	add_segment("Brazo", 0.3)                  # raíz
	add_segment("Antebrazo", 0.25, "Brazo")    # nace en la punta de Brazo
	add_segment("Mano", 0.12, "Antebrazo")     # nace en la punta de Antebrazo
