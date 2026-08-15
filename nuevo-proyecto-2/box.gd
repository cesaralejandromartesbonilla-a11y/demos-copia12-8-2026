extends RigidBody3D

# Dentro del script de tu máquina o herramienta:
const ESCENA_HIERRO = "res://ecenas/Minerales/sphere.tscn"
var puede_acoplarse: bool = true 

func _on_proceso_terminado(objeto_tierra):
	# Llamamos a la función de transformación
	transformar_objeto(objeto_tierra, ESCENA_HIERRO)

# Esta función reemplaza un objeto por otro manteniendo posición y física=======================

func transformar_objeto(objeto_viejo: Node3D, ruta_escena_nueva: String):
	# 1. Cargar la nueva escena (ej: Hierro o Cobre)
	var nueva_escena = load(ruta_escena_nueva)
	var instancia_nueva = nueva_escena.instantiate()
	
	# 2. Copiar la ubicación y rotación exacta
	var transformacion_original = objeto_viejo.global_transform
	
	# 3. Si el objeto viejo es un RigidBody, podemos heredar su inercia
	if objeto_viejo is RigidBody3D and instancia_nueva is RigidBody3D:
		instancia_nueva.linear_velocity = objeto_viejo.linear_velocity
		instancia_nueva.angular_velocity = objeto_viejo.angular_velocity

	# 4. Añadir el nuevo al mundo (en el mismo padre que el anterior)
	objeto_viejo.get_parent().add_child(instancia_nueva)
	instancia_nueva.global_transform = transformacion_original
	
	# 5. ¡Importante! Asegurar que el nuevo objeto esté en el grupo de guardado
	instancia_nueva.add_to_group("save_transform")
	
	# 6. Eliminar el objeto viejo (Tierra)
	objeto_viejo.queue_free()
	
	print("Transformación completada con éxito.")


# Función para "congelar" el mineral al camión==================================================

@export var peso_real: float = 20.0

# En box.gd / mineral.gd
func acoplar_a_vehiculo(nuevo_padre: Node3D, marcador: Marker3D):
	if marcador == null: return
	
	# 1. Desactivar físicas inmediatamente
	freeze = true
	collision_layer = 0
	collision_mask = 0
	
	# 2. CAMBIO DE PADRE INMEDIATO
	# En Godot 4.5, reparent() es seguro si no estamos en medio de un cálculo de colisión
	reparent(nuevo_padre)
	
	# 3. SINCRONIZACIÓN FORZADA
	# Forzamos a que el objeto use coordenadas locales del nuevo padre
	global_transform = marcador.global_transform
	
	# 4. AVISAR AL MOTOR DE FÍSICA
	# Esto es lo que falta para que no necesites reiniciar el juego
	PhysicsServer3D.body_set_state(
		get_rid(), 
		PhysicsServer3D.BODY_STATE_TRANSFORM, 
		global_transform
	)
	
	# 5. Asegurar que se renderice en el lugar correcto
	if is_inside_tree():
		force_update_transform()

	print("Acoplado instantáneamente al slot: ", marcador.name)

func desacoplar_de_vehiculo():
	var mundo = get_tree().current_scene
	reparent(mundo) 
	
	# BUSCAR SI ESTÁBAMOS EN UN SLOT Y LIBERARLO
	var _padre_actual = get_parent()
	# Si el padre es el remolque, buscamos el marcador que nos contenía
	# (O más simple, el script del Area3D ya limpia el meta con tree_exited)
	
	reparent(get_tree().current_scene)
	
	# RESTAURAR FÍSICAS CORRECTAMENTE
	collision_layer = 1 # Capa del objeto
	collision_mask = 1  # Capa con la que choca (suelo)
	
	freeze = false
	sleeping = false 
	mass = peso_real
	
	# Bloquear el acople inmediato
	puede_acoplarse = false
	
	# Esperar a que la física se despierte
	await get_tree().physics_frame
	
	# Aplicar impulso
	var impulso_final = (global_transform.basis.z * 2.0) + (Vector3.UP * 4.0)
	apply_central_impulse(impulso_final)
	
	# Esperar para permitir acoplarse de nuevo
	await get_tree().create_timer(1.5).timeout
	puede_acoplarse = true
