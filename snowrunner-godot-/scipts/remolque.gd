extends VehicleBody3D

# En lugar de @onready, usamos una variable normal para comprobar si existe
var patas_visuales: Node3D = null
var tipos_de_barro: Dictionary = {
	"barro_ligero": 2.0,
	"barro_estandar": 4.5,
	"barro_profundo": 9.0,
	"barro_extremo": 18.0
}
var inmersiones_ruedas: Dictionary = {}

func _ready() -> void:
	# Intentamos buscar el nodo por si existe
	if has_node("PatasApoyo"):
		patas_visuales = get_node("PatasApoyo")
	else:
		print("AVISO: No se encontró el nodo 'PatasApoyo' en el remolque. Se omitirá la animación de patas.")

	# Frenar al inicio
	_frenar(true)

func set_conectado(conectado: bool) -> void:
	if conectado:
		print("Remolque conectado -> Frenos LIBERADOS")
		_frenar(false)
		if patas_visuales: patas_visuales.visible = false
	else:
		print("Remolque desconectado -> Frenos ACTIVADOS")
		_frenar(true)
		if patas_visuales: patas_visuales.visible = true

func _frenar(activo: bool) -> void:
	for w in get_children():
		if w is VehicleWheel3D:
			w.brake = 100.0 if activo else 0.0
			w.engine_force = 0.0

# En el script del Remolque
func _procesar_fisicas_remolque(delta: float) -> void:
	for wheel in get_children():
		if wheel is VehicleWheel3D:
			var viscosidad_objetivo = 0.0
			var toca_barro = false
			
			if wheel.is_in_contact():
				var collider = wheel.get_contact_body()
				if collider:
					for grupo in tipos_de_barro.keys():
						if collider.is_in_group(grupo):
							viscosidad_objetivo = tipos_de_barro[grupo]
							toca_barro = true
							break

			# Hundimiento progresivo (2 segundos)
			var vel_h = viscosidad_objetivo / 2.0
			inmersiones_ruedas[wheel] = move_toward(inmersiones_ruedas[wheel], viscosidad_objetivo, vel_h * delta)
			
			# Fricción lateral instantánea (para que el remolque "colee" en el barro)
			wheel.wheel_friction_slip = clamp(2.0 - (viscosidad_objetivo * 0.1), 0.5, 1.0) if toca_barro else 2.0

			# Resistencia de arrastre (lo que frena al camión)
			var v_h = inmersiones_ruedas[wheel]
			if v_h > 0.1 and linear_velocity.length() > 0.1:
				var drag = -linear_velocity.normalized() * (linear_velocity.length_squared() * v_h * (mass * 0.05))
				apply_force(drag, wheel.global_position - global_position)
