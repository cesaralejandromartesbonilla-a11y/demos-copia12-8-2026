extends Resource
class_name CropVisualData

enum VisualStyle { COLOR_SHIFT, MULTIPLE_MODELS }

@export var style: VisualStyle = VisualStyle.COLOR_SHIFT
@export var transition_duration: float = 0.5 # Segundos que tarda la animación de tragado

@export_group("Estilo 1: Modelo Único (Trigo)")
@export var single_mesh: Mesh
@export var start_color: Color = Color("5c7a29") # Verde brote
@export var ready_color: Color = Color("d4c33d") # Amarillo trigo

@export_group("Estilo 2: Múltiples Modelos (Algas/Árboles)")
@export var sprout_mesh: Mesh # Brote inicial
@export var growing_mesh: Mesh # Creciendo
@export var ready_mesh: Mesh # Listo para cosechar
