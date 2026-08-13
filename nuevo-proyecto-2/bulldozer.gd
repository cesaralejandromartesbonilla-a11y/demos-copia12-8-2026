extends "res://addons/gevp/scenes/vehicle_base.gd"

# --- CONFIGURACIÓN ---
@export_group("Componentes")
@export var pala_node: Node3D        # El nodo que rota (la pala)
@export var filo_pala: Node3D        # UN MARKER3D en el borde inferior de la pala (CRÍTICO)
@export var tierra_escena: PackedScene
@export var spawn_tierra: Marker3D

@export_group("RayCasts de Corte")
@export var rc_izq: RayCast3D
@export var rc_central: RayCast3D
@export var rc_der: RayCast3D

@export_group("Parámetros de Trabajo")
@export var capacidad_max = 200.0
@export var fuerza_excavacion = 0.8  # Qué tan rápido come tierra
@export var radio_cuchilla = 1.2     # Radio de acción de cada RayCast

@export_group("Físicas Vehículo")
@export var motor_fuerza = 300.0
@export var direccion_max = 0.4
@export var frenado_fuerza = 20.0

# --- VARIABLES INTERNAS ---
var tierra_acumulada: float = 0.0
var voxel_tool: VoxelTool
@onready var terreno: VoxelLodTerrain = get_tree().root.find_child("VoxelLodTerrain", true, false)

func _ready():
	if terreno:
		voxel_tool = terreno.get_voxel_tool()
		# Usamos SDF para terreno suave
		voxel_tool.channel = VoxelBuffer.CHANNEL_SDF 
	
	# Asegurar que los RayCasts ignoren al propio Bulldozer
	for rc in [rc_izq, rc_central, rc_der]:
		if rc: rc.add_exception(self)

func _physics_process(delta: float) -> void:
	if !is_mounted:
		_aplicar_fuerzas(0, 0, frenado_fuerza)
		return

	_controlar_movimiento()
	_controlar_pala()
	_procesar_trabajo_suelo(delta)

# --- LÓGICA DE MOVIMIENTO ---
func _controlar_movimiento():
	var forward = Input.get_axis("press_s", "press_w")
	var steer = Input.get_axis("press_d", "press_a")
	var brake = frenado_fuerza if Input.is_action_pressed("press_space") else 0.0

	_aplicar_fuerzas(forward * motor_fuerza, steer * direccion_max, brake)

func _aplicar_fuerzas(f, s, b):
	# Ajusta los nombres de tus ruedas según tu escena
	$VehicleWheel3D3.engine_force = f
	$VehicleWheel3D4.engine_force = f
	$VehicleWheel3D.steering = s
	$VehicleWheel3D2.steering = s
	$VehicleWheel3D.brake = b
	$VehicleWheel3D2.brake = b

# --- LÓGICA DE LA PALA ---
func _controlar_pala():
	var input_pala = Input.get_axis("press_r", "press_f")
	if pala_node:
		# Rotación limitada
		pala_node.rotation_degrees.x = clamp(pala_node.rotation_degrees.x + (input_pala * 2.0), -35, 50)

# --- SISTEMA DE EXCAVACIÓN Y NIVELACIÓN ---
func _procesar_trabajo_suelo(_delta):
	if !voxel_tool or !filo_pala: return

	var raycasts = [rc_izq, rc_central, rc_der]
	var altura_cuchilla = filo_pala.global_position.y

	for rc in raycasts:
		if !rc or !rc.is_colliding(): continue

		var punto_colision = rc.get_collision_point()
		var distancia_y = punto_colision.y - altura_cuchilla

		# Solo actuamos si hay una diferencia notable (margen de 0.1)
		if abs(distancia_y) > 0.1:
			_modificar_voxel(punto_colision, distancia_y)

func _modificar_voxel(pos_global: Vector3, diferencia: float):
	# Comprobar si el área es editable para evitar lag/errores
	var box = AABB(pos_global - Vector3(1,1,1), Vector3(2,2,2))
	if !voxel_tool.is_area_editable(box): return

	if diferencia > 0: # EL TERRENO ESTÁ MÁS ALTO QUE LA PALA -> EXCAVAR
		if tierra_acumulada < capacidad_max:
			voxel_tool.mode = VoxelTool.MODE_REMOVE
			voxel_tool.do_sphere(pos_global, radio_cuchilla)
			tierra_acumulada += fuerza_excavacion
			_efecto_visual_tierra(pos_global)
			
	elif diferencia < 0: # EL TERRENO ESTÁ MÁS BAJO QUE LA PALA -> RELLENAR
		if tierra_acumulada > 0:
			voxel_tool.mode = VoxelTool.MODE_ADD
			voxel_tool.do_sphere(pos_global, radio_cuchilla)
			tierra_acumulada -= fuerza_excavacion

func _efecto_visual_tierra(pos: Vector3):
	if Engine.get_frames_drawn() % 15 == 0 and tierra_escena:
		var t = tierra_escena.instantiate()
		get_tree().root.add_child(t)
		t.global_position = pos + Vector3(0, 0.5, 0)
		if t is RigidBody3D:
			t.apply_central_impulse(global_basis.z * 2.0 + Vector3.UP * 2.0)

# --- COMPATIBILIDAD CON SAVE/LOAD ---
func save():
	return {
		"scene": scene_file_path, # IMPORTANTE: Usar 'scene' para tu cargador
		"pos": global_position,
		"rot": global_rotation,
		"tierra": tierra_acumulada
	}
