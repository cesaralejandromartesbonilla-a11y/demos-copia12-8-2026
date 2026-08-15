extends Node

# ==========================================
# 📦 ALMACENAMIENTO DE CUERPOS
# ==========================================
# Congela por completo un cuerpo inactivo — ni física, ni proceso, nada
# corriendo — y lo despierta cuando vuelve a ser el activo. El cuerpo que
# no controlas queda genuinamente guardado, no solo con el input apagado,
# así no hay riesgo de que dos cuerpos "vivan" a la vez sin querer.

func park(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	body.set_physics_process(false)
	body.set_process(false)
	if body.has_method("deactivate_control"):
		body.deactivate_control()

func unpark(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	body.set_physics_process(true)
	body.set_process(true)
	if body.has_method("activate_control"):
		body.activate_control()
