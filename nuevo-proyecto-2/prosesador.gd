extends Area3D

# Rutas de las escenas por las que se puede transformar
const MINERAL_HIERRO = "res://ecenas/Minerales/twosphere.tscn"
const MINERAL_COBRE = "res://ecenas/Minerales/cilinder.tscn"
const MINERAL_ORO = "res://ecenas/Minerales/sphere.tscn"

func _ready():
	# Conectamos la señal de que algo entró al área
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D):
	# Verificamos si el objeto que entró es "Tierra"
	# Puedes verificarlo por nombre o porque pertenece a un grupo
	if body.is_in_group("tierra"):
		transformar_con_suerte(body)

func transformar_con_suerte(objeto_viejo: Node3D):
	var prob = randf() # Genera un número entre 0.0 y 1.0
	var ruta_nueva: String = ""

	# --- SISTEMA DE PROBABILIDADES ---
	if prob < 0.10:    # 10% de probabilidad
		ruta_nueva = MINERAL_ORO
	elif prob < 0.40:  # 30% de probabilidad (0.40 - 0.10)
		ruta_nueva = MINERAL_COBRE
	else:              # 60% restante
		ruta_nueva = MINERAL_HIERRO

	ejecutar_reemplazo(objeto_viejo, ruta_nueva)

func ejecutar_reemplazo(objeto_viejo: Node3D, ruta_escena: String):
	# 1. Cargar e instanciar
	var nueva_escena = load(ruta_escena)
	var instancia = nueva_escena.instantiate()
	
	# 2. Guardar ubicación y físicas actuales
	var transform_original = objeto_viejo.global_transform
	var vel_lineal = Vector3.ZERO
	var vel_angular = Vector3.ZERO
	
	if objeto_viejo is RigidBody3D:
		vel_lineal = objeto_viejo.linear_velocity
		vel_angular = objeto_viejo.angular_velocity

	# 3. Añadir al mundo ANTES de borrar el viejo
	# Lo añadimos al mismo padre para mantener la jerarquía
	objeto_viejo.get_parent().add_child(instancia)
	
	# 4. Aplicar datos al nuevo
	instancia.global_transform = transform_original
	if instancia is RigidBody3D:
		instancia.linear_velocity = vel_lineal
		instancia.angular_velocity = vel_angular
	
	# 5. IMPORTANTE: Registrar en el sistema de guardado
	instancia.add_to_group("save_transform")
	
	# 6. Borrar el objeto viejo
	objeto_viejo.queue_free()
	print("Objeto transformado en: ", ruta_escena)
