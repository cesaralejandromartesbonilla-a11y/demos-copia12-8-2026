extends RigidBody3D
class_name PiezaMecanica

## Base de toda pieza rotativa (Motor, Engranaje, Rueda). El HingeJoint3D
## que la une al larguero lo crea y configura SIEMPRE EnsambladorMecanico,
## nunca la pieza misma — así el ensamblador es el único lugar del proyecto
## que necesita saber cómo se conectan las piezas entre sí.

var joint_montaje: HingeJoint3D = null

@export var impulso_maximo: float = 800.0

func _ready() -> void:
	can_sleep = false  # si se duerme, cambiarle el target_velocity al joint desde afuera no lo despierta solo — queda "bien configurado" pero inerte

## Velocidad de giro alrededor de SU PROPIO eje Z local — mismo criterio que
## ya usás en ModuloSuspension.gd (angular_velocity.dot(eje_bisagra)). Es lo
## que lee cualquier PiezaTransmision montada aguas abajo.
func get_velocidad_angular() -> float:
	return angular_velocity.dot(global_transform.basis.z)

## Hook llamado por EnsambladorMecanico justo después de crear el joint y
## asignarlo a joint_montaje. Todas las piezas rotativas necesitan el motor
## del joint activo (aunque el "motor" del joint lo maneje después el input
## del jugador o el script de transmisión, no la física propia del joint) —
## las subclases que necesiten algo más pueden llamar a super() y agregar
## lo suyo.
func al_ser_montada() -> void:
	if not joint_montaje:
		push_warning("%s: al_ser_montada() llamado sin joint_montaje asignado." % name)
		return
	joint_montaje.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
	joint_montaje.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, impulso_maximo)
