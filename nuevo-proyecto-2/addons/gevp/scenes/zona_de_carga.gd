extends Area3D

@onready var slot: Marker3D = $"../Area3D2/Marker3D" # Un punto donde se acomodará el mineral

func _ready():
	body_entered.connect(_on_body_entered)

# En Mineral.gd
var puede_acoplarse: bool = true

func funcion_de_vehiculo():
	# Impedir que se vuelva a acoplar inmediatamente
	puede_acoplarse = false
	await get_tree().create_timer(1.0).timeout
	puede_acoplarse = true

# En el script del Gancho (Area3D)
@onready var slot_visual = $Marker3D # Tu marcador visual

func _on_body_entered(body: Node3D):
	if body.has_method("acoplar_a_vehiculo") and "puede_acoplarse" in body and body.puede_acoplarse:
		# ANTES: body.acoplar_a_vehiculo(get_parent(), slot_posicion.position) <- ERROR
		# AHORA: Pasamos el nodo completo
		body.acoplar_a_vehiculo(get_parent(), slot) 
