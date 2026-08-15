extends VehicleBody3D

# Dentro del script de la grúa, cuando el jugador entra:
var hook_ctrl = player.get_node("HookController")
hook_ctrl.is_enabled = true
hook_ctrl.hook_source = $Brazo/PuntaGrua # Nodo Marker3D en la punta de la grúa

# Script de la Grúa (VehicleBody3D o RigidBody3D)

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Player: # Asegúrate de que el script del player tenga 'class_name Player'
		# Activamos el gancho del jugador al subir/entrar
		body.get_node("HookController").is_enabled = true
		print("Gancho de grúa conectado")

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body is Player:
		# Desactivamos el gancho al bajar/salir
		body.get_node("HookController").is_enabled = false
		print("Gancho de grúa desconectado")
