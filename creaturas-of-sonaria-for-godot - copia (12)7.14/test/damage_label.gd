extends Label3D

func display(amount: float, color: Color = Color.WHITE):
	text = str(snapped(amount, 0.1))
	modulate = color
	
	# Animación con Tween (Subir y desvanecer)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "global_position:y", global_position.y + 1.5, 0.8)
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.chain().kill() # Se destruye al terminar
	
	# Esperar a que termine la animación para borrar el nodo
	await get_tree().create_timer(0.8).timeout
	queue_free()
