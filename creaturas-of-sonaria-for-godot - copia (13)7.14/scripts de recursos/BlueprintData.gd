extends Resource
class_name BlueprintData

@export var building_name: String = "Estructura"
@export var unlocked: bool = true           # Para tu menú de casillas
@export var hologram_mesh: Mesh             # La forma visual (ej. un cubo de pared)

@export_group("Requisitos")
@export var required_items: Array[Resource] # Arrastra aquí los items (ej. Madera, Piedra)
@export var required_amounts: Array[int]    # Arrastra aquí la cantidad de cada uno (ej. 5, 3)
@export var build_instantly: bool = false   # Si es true, ignora los viajes si tienes el recurso

@export_group("Resultado")
@export var final_scene: PackedScene        # La escena final de la pared/suelo
