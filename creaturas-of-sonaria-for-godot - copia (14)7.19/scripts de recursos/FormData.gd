class_name FormData extends Resource

# ==========================================
# 📚 DATOS DE UNA FORMA ASIMILADA
# ==========================================
# Asimilar = clonar la forma visual. Nada de anatomía ni habilidades
# todavía — eso llega con Comprender, cuando exista.

@export var id: String = ""            # identificador único, ej. "roca", "taza"
@export var display_name: String = ""  # lo que ve el jugador en el HUD
@export var mesh: Mesh                 # la malla original del objeto asimilado
@export var material: Material         # opcional — se aplica 20ms después del mesh (ver FormController)
