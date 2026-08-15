extends Area3D

@onready var slot: Marker3D = $Marker3D # Un punto donde se acomodará el mineral

func _ready():
	body_entered.connect(_on_body_entered)

# En Mineral.gd
var puede_acoplarse: bool = true

func desacoplar_de_vehiculo():
	# ... (todo tu código anterior de reparent y físicas) ...
	
	# Impedir que se vuelva a acoplar inmediatamente
	puede_acoplarse = false
	await get_tree().create_timer(1.0).timeout
	puede_acoplarse = true

# En el script del Gancho (Area3D)
@onready var slot_visual = $Marker3D # Tu marcador visual

func _on_body_entered(body: Node3D):
	# Solo acoplar si la grúa está activa y no llevamos nada ya
	var grua = get_owner() # Esto obtiene la raíz de la escena de la grúa
	
	if body.has_method("acoplar_a_vehiculo") and body.puede_acoplarse:
		if grua.objeto_sujetado == null:
			# Pasamos el propio GANCHO como padre para que se mueva con él
			body.acoplar_a_vehiculo(self, slot)
			grua.objeto_sujetado = body # Registramos en la grúa
