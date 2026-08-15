extends Node
class_name MassInteractor

# Extraído de slime_base.gd para no seguir sumando ahí: la LÓGICA de
# interactuar con charcos/red de masa (drenar, dejar un charco al lanzarse
# con la resortera) vive acá. Los chequeos de input (press_f, el momento
# exacto del disparo de resortera) se quedan en slime_base.gd a propósito
# — este módulo no sabe nada de teclas, solo hace lo que le piden.
# No toca locomoción, forma, andamio, cámara ni ningún otro sistema.

var slime: CharacterBody3D

func setup(owner_slime: CharacterBody3D):
	slime = owner_slime

# Llamado directo desde el "if Input.is_action_pressed("press_f")" que ya
# existía en slime_base.gd — el chequeo de input se queda ahí a propósito,
# acá solo vive la lógica.
func drain_puddles(delta: float):
	if not slime.mass_manager or not slime.mass_manager.absorption_area:
		return

	# Obtenemos todas las áreas que está tocando el núcleo del slime
	var overlapping_areas = slime.mass_manager.absorption_area.get_overlapping_areas()

	for area in overlapping_areas:
		if area is SplatNode:
			# Solo necesitamos activar la red desde UN nodo de contacto
			area.process_network_drain(slime, delta)
			# Rompemos el ciclo para no drenar doble si tocamos dos charcos a la vez
			break

# Espejo de drain_puddles: el jugador mete masa propia a la red en vez de
# sacarla. Misma detección (un charco cercano alcanza para activar la red
# entera), llamado desde un "if Input.is_action_pressed(...)" nuevo en
# slime_base.gd — mismo patrón, input allá, lógica acá.
func feed_puddles(delta: float):
	if not slime.mass_manager or not slime.mass_manager.absorption_area:
		return

	var overlapping_areas = slime.mass_manager.absorption_area.get_overlapping_areas()

	for area in overlapping_areas:
		if area is SplatNode:
			area.process_network_feed(slime, delta)
			break

# Llamado desde slime_base.gd en el momento exacto del disparo de resortera
# (mismo punto de la lógica de la resortera que antes, solo que ahora
# delega el CUERPO de la función acá).
func leave_puddle_under_feet(mass_to_lose: float):
	if slime.projectile_manager == null or slime.mass_manager == null: return

	if slime.mass_manager.current_mass_level - mass_to_lose < 1.0:
		print("No hay masa suficiente para dejar charco. Núcleo en riesgo.")
		return

	print("💦 ¡Fuerza máxima! Dejando charco de resortera...")

	# Llamamos al ProjectileManager, que es el verdadero dueño de esta función
	slime.projectile_manager._consume_mass(mass_to_lose)

	# Raycast hacia abajo
	var space_state = slime.get_world_3d().direct_space_state
	var start = slime.global_position + Vector3(0, 0.5, 0)
	var end = start + (Vector3.DOWN * 2.0)

	var query = PhysicsRayQueryParameters3D.create(start, end)
	query.exclude = [slime.get_rid()]
	var result = space_state.intersect_ray(query)

	if result:
		var splat = SplatNode.new()
		splat.add_to_group("slime_projectiles")

		splat.stored_mass = mass_to_lose
		if slime.matter_controller and "current_element" in slime.matter_controller:
			splat.stored_element = slime.matter_controller.current_element

		var paint_color = Color(0.2, 0.8, 0.2)
		var custom_mat = slime.matter_controller.current_custom_material if slime.matter_controller and "current_custom_material" in slime.matter_controller else null
		var base_mat = slime.matter_controller.cached_base_liquid_mat if slime.matter_controller and "cached_base_liquid_mat" in slime.matter_controller else null

		if custom_mat != null and custom_mat is StandardMaterial3D:
			paint_color = custom_mat.albedo_color
		elif base_mat is StandardMaterial3D:
			paint_color = base_mat.albedo_color

		get_tree().current_scene.add_child(splat)
		splat.setup(result.position, result.normal, paint_color)
