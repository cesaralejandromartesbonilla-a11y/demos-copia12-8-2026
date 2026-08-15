extends CharacterBody3D
class_name PlayerCharacter

## Script "dueño" del maniquí/jugador. Responsabilidad EXCLUSIVA: cuerpo físico,
## movimiento y punto de sujeción de objetos.
##
## Nunca lleva lógica de sockets ni de chasis — eso vive en CreatureChassis.gd,
## dentro de Visuals/ActiveChassis, no acá (ver el diagrama de jerarquía).
##
## Este es el contrato mínimo que HUD / AssemblerModule / BuildingSocketsManager
## ya asumen que existe en player_dummy. No le agregues nada de sockets/chasis:
## si algo de eso te hace falta acá, es señal de que en realidad pertenece a
## CreatureChassis.gd.

@export var collision_shape: CollisionShape3D
@export var default_hold_parent: Node3D  ## Marker3D bajo Visuals — lo genera RequirementsBootstrapper si falta

var speed: float = 10.0
var jump_velocity: float = 4.5
var active_limbs: Array = []
var current_hold_parent: Node3D


## Llamado por AssemblerModule cada vez que una pieza con 'update_limb()' se acopla.
func register_limb(limb: Node) -> void:
	if limb and not active_limbs.has(limb):
		active_limbs.append(limb)


## Llamado por AssemblerModule para mover el "punto de sujeción" (ej. a una mano
## recién acoplada, o de vuelta a default_hold_parent cuando se limpia el chasis).
func move_hold_position_to(marker: Node3D) -> void:
	if not marker:
		push_warning("PlayerCharacter: move_hold_position_to() recibió un marker nulo.")
		return
	current_hold_parent = marker
	# TODO: si ya tienes un objeto "en mano" (arma/herramienta), reparéntalo acá
	# a 'current_hold_parent'. Este método por ahora solo guarda la referencia;
	# es el punto de enganche correcto para esa lógica cuando la armes.


# -----------------------------------------------------------------------------
# Movimiento básico OPCIONAL — si ya tienes tu propio script de movimiento/input,
# borra todo lo de abajo de esta línea y quédate solo con lo de arriba (eso es
# el contrato real que necesitan los demás módulos). Esto es solo para que el
# dummy no quede totalmente inerte mientras arman el resto.
# -----------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()
