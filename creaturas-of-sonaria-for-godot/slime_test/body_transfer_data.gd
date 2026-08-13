class_name BodyTransferData

# ==========================================
# 📦 TRANSFERENCIA DE DATOS ENTRE CUERPOS
# ==========================================
# A propósito hardcodeado, no genérico — con 3 prototipos como mucho
# (slime, CreatureRig con brazos, CreatureRig sin brazos) no vale la pena
# construir una tabla de despacho ni una interfaz abstracta todavía. Cada
# combinación que de verdad se use se agrega como su propio caso; el resto
# cae al aviso de abajo en vez de fallar en silencio.
#
# Reposicionar (copiar global_transform del viejo al nuevo) está
# desactivado a propósito: causó que SimpleBody apareciera enterrado en
# el piso, probablemente por una diferencia de forma/tamaño de colisión
# entre cuerpos. Por ahora cambiar de cuerpo NO mueve a nadie — cada
# cuerpo se queda físicamente donde ya estaba, el cambio solo mueve el
# control. Si más adelante quieren reposición segura, esto es el lugar
# para agregar algo como un raycast hacia abajo antes de teletransportar.

static func transfer(from_body: Node, to_body: Node) -> void:
	if from_body is CharacterBody3D and to_body is CharacterBody3D:
		_transfer_slime_to_slime(from_body, to_body)
		return

	if from_body is CharacterBody3D and to_body is CreatureRig:
		_transfer_slime_to_creature_rig(from_body, to_body)
		return

	push_warning("BodyTransferData: combinación sin manejar todavía (%s -> %s)" % [from_body.get_class(), to_body.get_class()])


# Caso de prueba actual: cuerpos IGUALES, slime a slime-clon.
static func _transfer_slime_to_slime(from_body: CharacterBody3D, to_body: CharacterBody3D) -> void:
	pass # sin reposicionar por ahora — ver nota arriba


# Preparado para cuando toque probar cuerpos DISTINTOS.
static func _transfer_slime_to_creature_rig(from_body: CharacterBody3D, to_body: CreatureRig) -> void:
	pass # sin reposicionar por ahora — ver nota arriba
