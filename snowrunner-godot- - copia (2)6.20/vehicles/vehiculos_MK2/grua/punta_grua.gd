extends Node3D

@export var gancho_rigidbody: RigidBody3D
@export var cable_mesh: MeshInstance3D # Tu cilindro
@export var velocidad_subir_bajar: float = 2.0
@export var longitud_cable: float = 2.0 # Empieza corto
@export var max_longitud: float = 15.0
@export var min_longitud: float = 1.0

@export var fuerza_tension: float = 200.0 # Fuerza para mantener el gancho en su límite

func _physics_process(delta: float) -> void:
	# 1. CONTROLES PARA SUBIR/BAJAR EL CABLE
	if Input.is_action_pressed("press_g"): # Bajar gancho
		longitud_cable = min(longitud_cable + (velocidad_subir_bajar * delta), max_longitud)
	elif Input.is_action_pressed("press_t"): # Subir gancho
		longitud_cable = max(longitud_cable - (velocidad_subir_bajar * delta), min_longitud)
		
	# 2. LÓGICA FÍSICA (Mantener la distancia)
	var distancia_actual = global_position.distance_to(gancho_rigidbody.global_position)
	var direccion_hacia_punta = (global_position - gancho_rigidbody.global_position).normalized()
	
	# Si el gancho cae más abajo de la longitud del cable, tiramos de él hacia arriba
	if distancia_actual > longitud_cable:
		# Aplicamos una fuerza hacia arriba para simular la tensión del cable que lo sujeta
		var diferencia = distancia_actual - longitud_cable
		gancho_rigidbody.apply_central_force(direccion_hacia_punta * fuerza_tension * diferencia)
		
		# Amortiguación opcional para que no rebote como un yo-yo
		gancho_rigidbody.linear_velocity *= 0.95 
		
	# 3. LÓGICA VISUAL (Tu código adaptado)
	_actualizar_cable_visual()

func _actualizar_cable_visual() -> void:
	# Posición de inicio (punta de la grúa) y fin (gancho físico)
	var source_pos = global_position
	var target_pos = gancho_rigidbody.global_position
	var distance = source_pos.distance_to(target_pos)
	
	# NUEVO: Si están demasiado cerca, ocultamos el cable y evitamos el error de look_at()
	if distance < 0.01:
		cable_mesh.visible = false
		return
		
	cable_mesh.visible = true
	cable_mesh.global_position = source_pos.lerp(target_pos, 0.5)
	
	# NUEVO: Lógica para evitar la advertencia de colinealidad (Vectores paralelos)
	var direccion = (target_pos - cable_mesh.global_position).normalized()
	var vector_arriba = Vector3.UP
	
	# Si el cable apunta casi perfectamente hacia abajo o hacia arriba (valor Y muy cercano a 1 o -1)
	if abs(direccion.y) > 0.999:
		vector_arriba = Vector3.FORWARD # Cambiamos la referencia al eje Z para que Godot no se confunda
		
	# Aplicamos el look_at con el vector seguro
	cable_mesh.look_at(target_pos, vector_arriba)
	cable_mesh.rotation_degrees.x += 90 
	
	# Escalamos el cilindro
	cable_mesh.scale.y = distance / 2.0
