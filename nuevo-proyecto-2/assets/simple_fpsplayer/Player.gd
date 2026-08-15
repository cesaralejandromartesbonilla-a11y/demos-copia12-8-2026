extends CharacterBody3D

const ACCEL = 10
const DEACCEL = 30

const SPEED = 5.0
const SPRINT_MULT = 2
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.06

# Get the gravity from the project settings to be synced with RigidDynamicBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var camera
var rotation_helper
var dir = Vector3.ZERO
var flashlight

@onready var voxel_lod_terrain: VoxelLodTerrain = $"../VoxelLodTerrain"
@onready var voxel_tool := voxel_lod_terrain.get_voxel_tool()
@onready var ray_cast_3d: RayCast3D = $rotation_helper/Camera3D/RayCast3D

func _ready():
	camera = $rotation_helper/Camera3D
	rotation_helper = $rotation_helper
	flashlight = $rotation_helper/Camera3D/flashlight_player

	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	# This section controls your player camera. Sensitivity can be changed.
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_helper.rotate_x(deg_to_rad(event.relative.y * MOUSE_SENSITIVITY * -5))
		self.rotate_y(deg_to_rad(event.relative.x * MOUSE_SENSITIVITY * -5))

		var camera_rot = rotation_helper.rotation
		camera_rot.x = clampf(camera_rot.x, -1.4, 1.4)
		rotation_helper.rotation = camera_rot

	# Release/Grab Mouse for debugging. You can change or replace this.
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Flashlight toggle. Defaults to F on Keyboard.
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_F:
			if flashlight.is_visible_in_tree() and not event.echo:
				flashlight.hide()
			elif not event.echo:
				flashlight.show()



func _physics_process(delta):
	# Detectar si estamos dentro de algo sólido (VoxelTerrain)
	if voxel_tool.get_voxel(global_position) < 0: # En SDF, valores negativos son sólidos
		global_position.y += 0.5 # Teletransporte suave hacia arriba hasta salir
	
	var _moving = false
	# Add the gravity. Pulls value from project settings.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("press_space") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# This just controls acceleration. Don't touch it.
	var accel
	if dir.dot(velocity) > 0:
		accel = ACCEL
		_moving = true
	else:
		accel = DEACCEL
		_moving = false


	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with a custom keymap depending on your control scheme. These strings default to the arrow keys layout.
	var input_dir = Input.get_vector("press_a", "press_d", "press_w", "press_s")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized() * accel * delta
	if Input.is_key_pressed(KEY_SHIFT):
		direction = direction * SPRINT_MULT
	else:
		pass

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	var target_pos = ray_cast_3d.get_collision_point()
	if not ray_cast_3d.is_colliding():
		target_pos = ray_cast_3d.global_position-ray_cast_3d.global_basis.z*5


	# EXCAVAR (Obtener tierra)
	if Input.is_action_just_pressed("click_left"):
		if ray_cast_3d.is_colliding():
			if tierra_acumulada < CAPACIDAD_MAX:
				tierra_acumulada += 1.0
				excavar(target_pos)
			else:
				print("¡Pala llena!")

# En Player.gd, dentro de _physics_process
	if Input.is_action_just_pressed("click_right"): # Mejor "just_pressed" para lanzar una por una
		if tierra_acumulada > 0:
			soltar_tierra_fisica()
			tierra_acumulada -= 1.0
		else:
			print("Sin tierra en la pala")
			
		voxel_tool.mode = VoxelTool.MODE_TEXTURE_PAINT
		voxel_tool.do_sphere(target_pos, 2.5)

	if Input.is_action_just_pressed("null"):
		voxel_tool.texture_index = posmod(voxel_tool.texture_index+1,3)

#generar tierra suelta =============================================================================
# --- VARIABLES NUEVAS ---
var tierra_acumulada: float = 0.0 # Cantidad de tierra en la pala/inventario
const CAPACIDAD_MAX = 50.0
@export var terreno_path : NodePath
@export var tierra_escena : PackedScene # Aquí arrastras tu TierraFisica.tscn en el inspector
@onready var raycast = $rotation_helper/Camera3D/RayCast3D # Asegúrate de tener un RayCast3D mirando al frente

# --- FUNCIÓN EXCAVAR ACTUALIZADA ---
func excavar(pos: Vector3):
	# Leer el tipo de textura antes de borrar (Canal TYPE o INDICES)
	var material_id = voxel_tool.get_voxel(pos) 
	
	voxel_tool.do_sphere(pos, 1.5) # Borrar
	
	var piedra = tierra_escena.instantiate()
	get_tree().root.add_child(piedra)
	piedra.global_position = pos
	piedra.configurar_material(material_id) # Le pasamos el color

	
	
	voxel_tool.channel = VoxelBuffer.CHANNEL_SDF 
	voxel_tool.mode = VoxelTool.MODE_REMOVE
	voxel_tool.value = 1.0
	
	#if tierra_escena:
		#var nueva_tierra = tierra_escena.instantiate()
		#get_tree().root.add_child(nueva_tierra)
		#nueva_tierra.global_position = pos + Vector3(0, 0.5, 0)
		
		# IMPORTANTE: Para que la tierra física no genere más tierra
		# Asegúrate de que el RayCast3D ignore los objetos de "TierraFisica"
		# poniéndolos en una Collision Layer diferente (ej. Capa 3).


# En Player.gd, dentro de _physics_process
	if Input.is_action_just_pressed("click_right"): # Mejor "just_pressed" para lanzar una por una
		if tierra_acumulada > 0:
			soltar_tierra_fisica()
			tierra_acumulada -= 1.0
		else:
			print("Sin tierra en la pala")

func soltar_tierra_fisica():
	if tierra_escena:
		var piedra = tierra_escena.instantiate()
		get_tree().root.add_child(piedra)
		
		# Aparece frente al jugador (a la altura de la cámara/pala)
		var spawn_pos = $rotation_helper/Camera3D.global_position - $rotation_helper/Camera3D.global_basis.z * 1.5
		piedra.global_position = spawn_pos
		
		# Le damos un pequeño impulso hacia adelante para que no caiga en nuestros pies
		if piedra is RigidBody3D:
			var direccion = -$rotation_helper/Camera3D.global_basis.z
			piedra.apply_central_impulse((direccion + Vector3(0, 0.5, 0)) * 5.0)
