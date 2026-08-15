extends PiezaMecanica
class_name PiezaTransmision

## Base de Engranaje y Rueda: ambas escuchan a una 'fuente' (otra
## PiezaMecanica montada aguas arriba) y cada physics frame replican su
## velocidad angular multiplicada por 'ratio'. Esto es la transmisión
## "a lo Trailmakers" que definieron como enfoque del MVP: un valor que
## viaja por código, no dientes físicos chocando entre sí.
##
## 'fuente' la asigna EnsambladorMecanico al montar la pieza (ver
## _registrar_y_conectar) — nunca la asignes a mano salvo que estés
## probando la pieza sola y aislada.

var fuente: PiezaMecanica = null

@export var ratio: float = 1.0

func _physics_process(_delta: float) -> void:
	if not fuente or not joint_montaje:
		return
	var velocidad_objetivo := fuente.get_velocidad_angular() * ratio
	joint_montaje.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, velocidad_objetivo)
