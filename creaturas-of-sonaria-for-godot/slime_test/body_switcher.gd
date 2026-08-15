extends Node

# ==========================================
# 🔀 CAMBIO DE CUERPO
# ==========================================
# Distinto de Asimilar: esto no es visual, es literal — apaga el control
# del cuerpo viejo, mueve los datos relevantes al nuevo (ver
# BodyTransferData), y enciende el control del nuevo. Cualquier cuerpo
# que quiera ser "cambiable" expone activate_control()/deactivate_control()
# — ver la nota al final sobre qué necesita slime_base.gd para cumplir
# ese contrato.
#
# La cámara (PlayerCamera) ya NO vive dentro de ningún cuerpo — es su
# propio autoload de escena, así que ningún slime/clon/cuerpo nuevo
# depende de tenerla como hijo. Por eso ya no hace falta registrarla acá.

# El cuerpo ORIGINAL — se registra una sola vez y nunca se pisa, sin
# importar cuántos cuerpos distintos pruebes después (un vaso de agua,
# un carro, y de vuelta). Evita perder la referencia al slime de verdad
# entre tantos cambios.
var home_body: Node = null
var current_body: Node = null

func register_home(body: Node) -> void:
	# Llamar UNA sola vez, desde el _ready() del slime ORIGINAL — nunca
	# desde un clon ni desde otro cuerpo.
	if home_body != null:
		return
	home_body = body
	current_body = body
	PlayerCamera.retarget(body) # necesario: PlayerCamera ya no puede inferir su target de get_parent()

func return_to_home() -> void:
	if home_body == null or not is_instance_valid(home_body):
		push_warning("BodySwitcher: no hay cuerpo original registrado, o ya no es válido")
		return
	switch_to(home_body)

func switch_to(new_body: Node) -> void:
	if new_body == current_body:
		return

	var old_body = current_body

	if old_body != null:
		BodyTransferData.transfer(old_body, new_body)

	if old_body != null:
		BodyStorage.park(old_body)
	BodyStorage.unpark(new_body)

	# Algunos cuerpos (ej. RollingRock) no quieren que la cámara siga su
	# rotación física directa — exponen get_camera_target() para señalar
	# a qué seguir en su lugar. Si no lo tienen, se sigue al cuerpo mismo.
	var camera_target = new_body
	if new_body.has_method("get_camera_target"):
		camera_target = new_body.get_camera_target()
	PlayerCamera.retarget(camera_target)

	current_body = new_body

## Fuerza control + cámara sobre 'body' sin tocar nada del cuerpo anterior.
## Pensada como red de seguridad para cuando algo queda desincronizado
## (ej. la cámara mirando a un cuerpo que ya no es el controlado).
func refresh_control(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body.has_method("activate_control"):
		body.activate_control()
	PlayerCamera.retarget(body)


# ==========================================
# 📋 CONTRATO — lo que slime_base.gd (y cualquier cuerpo futuro) necesita
# ==========================================
# func activate_control() -> void:
#     is_player_controlled = true
#
# func deactivate_control() -> void:
#     is_player_controlled = false
