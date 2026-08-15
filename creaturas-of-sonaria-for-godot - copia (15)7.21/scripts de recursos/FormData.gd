class_name FormData extends Resource

# ==========================================
# 📚 DATOS DE UNA FORMA ASIMILADA
# ==========================================
# Asimilar = clonar la forma visual Y la colisión exacta del objeto.
# Nada de anatomía ni habilidades todavía — eso llega con Comprender.

@export var id: String = ""                            # identificador único, ej. "roca", "taza"
@export var display_name: String = ""                  # lo que ve el jugador en el HUD
@export var mesh: Mesh                                 # la malla original del objeto asimilado
@export var material: Material                         # opcional — se aplica al terminar la disolución (ver FormController)
@export var collision_shape: Shape3D                   # la forma de colisión exacta del objeto original
@export var collision_position: Vector3 = Vector3.ZERO # offset local de esa colisión
