extends MeshInstance3D
class_name MachineStatusLight

@export var processor: ProcessorComponent
@export var surface_index: int = 0 # El índice del material que va a brillar

@export_group("Materiales de Estado")
@onready var mat_error_off = preload("res://materiales/luces/luz_roja.tres")
@onready var mat_working = preload("res://materiales/luces/luz_verde.tres")
@onready var mat_waiting = preload("res://materiales/luces/luz_amarilla.tres")

func _ready() -> void:
	# Si se te olvidó asignar el procesador en el inspector, intenta buscarlo automáticamente en la máquina
	if processor == null:
		# owner suele ser la raíz de la escena guardada (ej. la CraftingTable)
		if owner != null:
			processor = owner.get_node_or_null("ProcessorComponent")
			
	if processor != null:
		# Nos conectamos a la señal del procesador
		processor.machine_state_changed.connect(_on_state_changed)
		# Sincronizamos la luz nada más nacer para que no empiece gris
		_on_state_changed(processor.current_state)
	else:
		print("Advertencia: MachineStatusLight no encontró un ProcessorComponent.")

func _on_state_changed(state: String) -> void:
	match state:
		"WORKING":
			set_surface_override_material(surface_index, mat_working)
		"IDLE", "JAMMED":
			set_surface_override_material(surface_index, mat_waiting)
		"OFF", "NO_FUEL", "NO_POWER", "NO_FLUID":
			set_surface_override_material(surface_index, mat_error_off)
		_:
			# Por si acaso hay un estado raro, luz roja
			set_surface_override_material(surface_index, mat_error_off)
