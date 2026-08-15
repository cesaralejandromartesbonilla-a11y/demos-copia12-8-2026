extends Node3D

@export_group("Referencias")
@export var chasis: VehicleBody3D
@export var esqueleto: Skeleton3D

@export_group("Configuración Principal")
@export var configuracion_ejes: Array[DatosEje] = []

@export_group("Ajustes de Torsión (Frame Flex)")
@export var huesos_torsion_chasis: Array[String]
@export_enum("X", "Y", "Z") var eje_torsion: int = 2 
@export var multiplicador_torsion: float = 1.0
@export var suavizado_torsion: float = 5.0

# Almacenamiento Interno (Solo lo necesario para la torsión)
var ruedas_izq: Array[VehicleWheel3D] = []
var ruedas_der: Array[VehicleWheel3D] = []
var ids_torsion: Array[int] = []
var angulos_torsion_suavizados: Array[float] = []

func _ready() -> void:
	if not esqueleto or not chasis: return
	
	# Extraemos las ruedas para medir sus puntos de contacto
	for eje in configuracion_ejes:
		if not eje: continue
		
		var r_izq = get_node_or_null(eje.ruta_rueda_izq) as VehicleWheel3D
		if not r_izq: r_izq = chasis.get_node(String(eje.ruta_rueda_izq)) as VehicleWheel3D
			
		var r_der = get_node_or_null(eje.ruta_rueda_der) as VehicleWheel3D
		if not r_der: r_der = chasis.get_node(String(eje.ruta_rueda_der)) as VehicleWheel3D
		
		ruedas_izq.append(r_izq)
		ruedas_der.append(r_der)

	# Inicializar IDs para los huesos del chasis
	for nombre in huesos_torsion_chasis:
		ids_torsion.append(esqueleto.find_bone(nombre))
		angulos_torsion_suavizados.append(0.0)

func _physics_process(delta: float) -> void:
	if not esqueleto: return
	
	# Única lógica activa: Torsión visual del chasis
	_actualizar_torsion_chasis(delta)

func _actualizar_torsion_chasis(delta: float) -> void:
	var angulos_reales = []
	for i in range(ruedas_izq.size()):
		var angulo_eje = 0.0
		if ruedas_izq[i].is_in_contact() or ruedas_der[i].is_in_contact():
			var local_i = chasis.to_local(ruedas_izq[i].get_contact_point())
			var local_d = chasis.to_local(ruedas_der[i].get_contact_point())
			angulo_eje = atan2(local_i.y - local_d.y, abs(ruedas_izq[i].position.x - ruedas_der[i].position.x))
		
		angulos_torsion_suavizados[i] = lerp(angulos_torsion_suavizados[i], angulo_eje * multiplicador_torsion, suavizado_torsion * delta)
		angulos_reales.append(angulos_torsion_suavizados[i])

	for i in range(ids_torsion.size()):
		var rot_relativa = angulos_reales[i]
		if i > 0: rot_relativa = angulos_reales[i] - angulos_reales[i-1]
		
		var eje_vec = Vector3.ZERO
		if eje_torsion == 0: eje_vec = Vector3.RIGHT
		elif eje_torsion == 1: eje_vec = Vector3.UP
		else: eje_vec = Vector3.FORWARD
		
		esqueleto.set_bone_pose_rotation(ids_torsion[i], Quaternion(eje_vec, rot_relativa))
