extends Node
class_name CropArchitecture
 
var crop: ProceduralFreeCrop
 
func _ready() -> void:
	crop = get_parent() as ProceduralFreeCrop
 
#region LÓGICA DE PALMERA Y CORONA (SOLO CON EJE GUIA UNICO)
func verificar_y_transformar_palmera() -> void:
	if not crop: return
	var p_vis = crop.seed_data.visual_data as ProceduralVisualData
	if not p_vis or not p_vis.eje_guia_unico: return
	
	var copa_actual = obtener_rama_copa_existente(crop.root_segment)
	if copa_actual != null: return 
	transformar_punta_en_copa()
 
func actualizar_posicion_copa(p_vis: ProceduralVisualData) -> void:
	if not crop or not p_vis or not p_vis.eje_guia_unico: return
	var copa_vieja = obtener_rama_copa_existente(crop.root_segment)
	var nueva_punta = _obtener_punta_eje_guia()
 
	if nueva_punta and nueva_punta != copa_vieja:
		if copa_vieja:
			copa_vieja.type = CropSegment3D.SegmentType.TRUNK
			copa_vieja._actualizar_estadisticas_y_visuales(p_vis)
 
		nueva_punta.type = CropSegment3D.SegmentType.BRANCH
		nueva_punta.es_eje_guia = true
		nueva_punta._actualizar_estadisticas_y_visuales(p_vis)
 
	var copa_actual = obtener_rama_copa_existente(crop.root_segment)
	if copa_actual:
		_ejecutar_limpieza_retroactiva(copa_actual, p_vis)
 
func _ejecutar_limpieza_retroactiva(copa_real: CropSegment3D, p_vis: ProceduralVisualData) -> void:
	if not crop: return
	var polizones: Array[CropSegment3D] = []
	_recolectar_follaje_fuera_de_copa(crop.root_segment, copa_real, polizones)
 
	for nodo_follaje in polizones:
		var padre_actual = nodo_follaje.get_parent()
		if padre_actual: padre_actual.remove_child(nodo_follaje)
		if not copa_real.puntos_de_crecimiento.is_empty():
			var marcador_destino = copa_real.puntos_de_crecimiento.pick_random()
			marcador_destino.add_child(nodo_follaje)
			_aplicar_fisicas_y_rotacion_nodo(nodo_follaje, p_vis)
 
func _recolectar_follaje_fuera_de_copa(nodo: Node, copa_real: CropSegment3D, lista_resultado: Array[CropSegment3D]) -> void:
	if not nodo: return
	if nodo is CropSegment3D and (nodo.type == CropSegment3D.SegmentType.LEAF or nodo.type == CropSegment3D.SegmentType.FRUIT):
		if not _es_descendiente_de(nodo, copa_real): lista_resultado.append(nodo)
	for hijo in nodo.get_children(): _recolectar_follaje_fuera_de_copa(hijo, copa_real, lista_resultado)
 
func _es_descendiente_de(nodo: Node, ancestro_objetivo: Node) -> bool:
	var p = nodo.get_parent()
	while p:
		if p == ancestro_objetivo: return true
		p = p.get_parent()
	return false
 
func obtener_rama_copa_existente(nodo: Node) -> CropSegment3D:
	if not nodo: return null
	if nodo is CropSegment3D and nodo.type == CropSegment3D.SegmentType.BRANCH and nodo.es_eje_guia: return nodo
	for hijo in nodo.get_children():
		var encontrado = obtener_rama_copa_existente(hijo)
		if encontrado != null: return encontrado
	return null
 
func _obtener_punta_eje_guia() -> CropSegment3D:
	if not crop: return null
	var actual = crop.root_segment
	if actual: actual.es_eje_guia = true
	while actual:
		if actual.puntos_de_crecimiento.is_empty(): break
		var marker_vertical = actual.puntos_de_crecimiento[0]
		if marker_vertical.get_child_count() > 0:
			var siguiente = marker_vertical.get_child(0)
			if siguiente is CropSegment3D and (siguiente.type == CropSegment3D.SegmentType.TRUNK or siguiente.es_eje_guia):
				siguiente.es_eje_guia = true
				actual = siguiente
				continue
		break
	return actual
 
func _actualizar_datos_toda_la_planta(nodo: Node, p_vis: ProceduralVisualData) -> void:
	if not nodo: return
	if nodo is CropSegment3D: nodo._actualizar_estadisticas_y_visuales(p_vis)
	for child in nodo.get_children(): _actualizar_datos_toda_la_planta(child, p_vis)
 
func transformar_punta_en_copa() -> void:
	if not crop: return
	var punta_copa = _obtener_punta_eje_guia()
	if not punta_copa: return
	punta_copa.type = CropSegment3D.SegmentType.BRANCH
	punta_copa.es_eje_guia = true
	var p_vis = crop.seed_data.visual_data as ProceduralVisualData
	punta_copa._actualizar_estadisticas_y_visuales(p_vis)
#endregion
 
#region MOTOR DE INTERCALACIÓN Y DESARROLLO ORGÁNICO POLIMÓRFICO con INSTINTO DE SUPERVIVENCIA
func expand_procedural_tree(p_vis: ProceduralVisualData, nivel_planta: int) -> void:
	if not crop or not crop.root_segment: return
 
	var cant_troncos = _contar_segmentos_tipo(crop.root_segment, CropSegment3D.SegmentType.TRUNK)
	var cant_hojas = _contar_segmentos_tipo(crop.root_segment, CropSegment3D.SegmentType.LEAF)
	var energia_actual = crop.root_segment.energia_almacenada
 
	# 🚨 DETECCIÓN DE MODO SUPERVIVENCIA CRÍTICO
	var sin_hojas: bool = (cant_hojas == 0)
	var energia_critica: bool = (energia_actual < 35.0)
	var modo_supervivencia: bool = sin_hojas or (energia_critica and cant_hojas < 3)
 
	var desea_tronco: bool = false
 
	# Si la planta está muriendo o no tiene hojas, se prohíbe gastar energía en madera estructural
	if modo_supervivencia:
		desea_tronco = false
	else:
		if p_vis.eje_guia_unico:
			if cant_hojas == 0: desea_tronco = false
			elif cant_troncos < 3: desea_tronco = true
			elif cant_hojas < 4: desea_tronco = false
			elif cant_troncos < p_vis.altura_objetivo_tronco: desea_tronco = (randf() < 0.65)
			else: desea_tronco = false
		else:
			if cant_troncos < p_vis.altura_objetivo_tronco:
				desea_tronco = (cant_troncos < 2) or (randf() < 0.45)
			else:
				desea_tronco = false
 
	if desea_tronco:
		if p_vis.eje_guia_unico:
			if _intentar_insercion_intercalaria(p_vis):
				crop.root_segment.energia_almacenada -= 20.0 # Costo estructural normal
				_verificar_subida_nivel(cant_troncos)
		else:
			if _intentar_crecimiento_apical_tronco(p_vis):
				crop.root_segment.energia_almacenada -= 20.0
				_verificar_subida_nivel(cant_troncos)
	else:
		_desarrollar_elemento_en_marcador(p_vis, nivel_planta, cant_troncos, cant_hojas, modo_supervivencia)
 
func _verificar_subida_nivel(cant_troncos: int) -> void:
	if cant_troncos >= 5 and crop.nivel_estructural_arbol < crop.max_niveles_estructurales:
		if crop.metabolism: crop.metabolism.evolucionar_y_subir_de_nivel()

func _intentar_crecimiento_apical_tronco(p_vis: ProceduralVisualData) -> bool:
	var ultimo_tronco = _obtener_tronco_mas_alto(crop.root_segment)
	if not ultimo_tronco or p_vis.trunk_variants.is_empty(): return false
	if ultimo_tronco.puntos_de_crecimiento.is_empty(): return false
	
	var marker_apical = ultimo_tronco.puntos_de_crecimiento[0]
	if marker_apical.get_child_count() > 0: return false 
	
	var nuevo_tronco = p_vis.trunk_variants[0].scene.instantiate() as CropSegment3D
	nuevo_tronco.type = CropSegment3D.SegmentType.TRUNK
	nuevo_tronco.variant_index = 0
	nuevo_tronco.current_depth = ultimo_tronco.current_depth + 1
	
	marker_apical.add_child(nuevo_tronco)
	nuevo_tronco._actualizar_estadisticas_y_visuales(p_vis)
	_aplicar_fisicas_y_rotacion_nodo(nuevo_tronco, p_vis)
	
	nuevo_tronco.scale = Vector3.ZERO
	var tween = crop.create_tween()
	tween.tween_property(nuevo_tronco, "scale", Vector3.ONE, 1.5).set_trans(Tween.TRANS_BACK)
	return true

func _obtener_tronco_mas_alto(nodo: Node) -> CropSegment3D:
	if not nodo: return null
	var mas_alto: CropSegment3D = null
	if nodo is CropSegment3D and nodo.type == CropSegment3D.SegmentType.TRUNK:
		mas_alto = nodo
	for hijo in nodo.get_children():
		var candidato = _obtener_tronco_mas_alto(hijo)
		if candidato:
			if not mas_alto or candidato.current_depth > mas_alto.current_depth:
				mas_alto = candidato
	return mas_alto
 
func _intentar_insercion_intercalaria(p_vis: ProceduralVisualData) -> bool:
	var punta_apex = _obtener_punta_eje_guia()
	if not punta_apex or p_vis.trunk_variants.is_empty(): return false
	var nuevo_tronco = p_vis.trunk_variants[0].scene.instantiate() as CropSegment3D
	nuevo_tronco.type = CropSegment3D.SegmentType.TRUNK
	nuevo_tronco.variant_index = 0
	nuevo_tronco.es_eje_guia = true
 
	if p_vis.eje_guia_unico and punta_apex != crop.root_segment:
		var marker_padre = punta_apex.get_parent() as Marker3D
		if marker_padre:
			marker_padre.remove_child(punta_apex)
			marker_padre.add_child(nuevo_tronco)
			nuevo_tronco._actualizar_estadisticas_y_visuales(p_vis)
			nuevo_tronco.puntos_de_crecimiento[0].add_child(punta_apex)
	else:
		if punta_apex.puntos_de_crecimiento.is_empty(): return false
		var marker_vertical = punta_apex.puntos_de_crecimiento[0]
		if marker_vertical.get_child_count() > 0:
			var nodo_copa_existente = marker_vertical.get_child(0)
			marker_vertical.remove_child(nodo_copa_existente)
			marker_vertical.add_child(nuevo_tronco)
			nuevo_tronco._actualizar_estadisticas_y_visuales(p_vis)
			if not nuevo_tronco.puntos_de_crecimiento.is_empty():
				nuevo_tronco.puntos_de_crecimiento[0].add_child(nodo_copa_existente)
		else:
			marker_vertical.add_child(nuevo_tronco)
			nuevo_tronco._actualizar_estadisticas_y_visuales(p_vis)
 
	actualizar_posicion_copa(p_vis)
	_actualizar_datos_toda_la_planta(crop.root_segment, p_vis)
	if crop.metabolism: crop.metabolism._recalcular_profundidades_hijos(crop.root_segment)
 
	nuevo_tronco.scale = Vector3(1, 0, 1)
	var tween = crop.create_tween()
	tween.tween_property(nuevo_tronco, "scale", Vector3.ONE, 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return true
 
func _desarrollar_elemento_en_marcador(p_vis: ProceduralVisualData, nivel_planta: int, cant_troncos: int, cant_hojas: int, modo_supervivencia: bool) -> void:
	var libres = _collect_all_free_markers(crop.root_segment, p_vis, modo_supervivencia)
	if libres.is_empty(): return
 
	var random_marker = libres.pick_random()
	var parent_segment = random_marker.get_parent() as CropSegment3D
	var marker_idx = parent_segment.puntos_de_crecimiento.find(random_marker)
	
	var stats = {
		"trunk_count": cant_troncos, 
		"leaf_count": cant_hojas, 
		"energy": crop.root_segment.energia_almacenada,
		"modo_supervivencia": modo_supervivencia
	}
 
	# El ADN procesará si tiene permitido mutar o si se le obliga a spawnear hojas por supervivencia
	var scene_to_instantiate = _determinar_escena_por_adn(parent_segment, marker_idx, p_vis, stats)
	if not scene_to_instantiate: return
 
	var new_segment = scene_to_instantiate.instantiate() as CropSegment3D
	
	if scene_to_instantiate in _obtener_scenes_de_variantes(p_vis.branch_variants):
		new_segment.type = CropSegment3D.SegmentType.BRANCH
	elif scene_to_instantiate in _obtener_scenes_de_variantes(p_vis.leaf_variants):
		new_segment.type = CropSegment3D.SegmentType.LEAF
	elif scene_to_instantiate in _obtener_scenes_de_variantes(p_vis.fruit_variants):
		new_segment.type = CropSegment3D.SegmentType.FRUIT
	elif scene_to_instantiate in _obtener_scenes_de_variantes(p_vis.flower_variants):
		new_segment.type = CropSegment3D.SegmentType.FLOWER
 
	new_segment.variant_index = parent_segment.get_meta("idx_variante_pendiente") if parent_segment.has_meta("idx_variante_pendiente") else 0
	if parent_segment.has_meta("idx_variante_pendiente"): parent_segment.remove_meta("idx_variante_pendiente")
	
	new_segment.current_stage = clampi(nivel_planta - 1, 0, 2)
	new_segment.current_depth = parent_segment.current_depth + 1
	
	random_marker.add_child(new_segment)
	new_segment._actualizar_estadisticas_y_visuales(p_vis)
	_aplicar_fisicas_y_rotacion_nodo(new_segment, p_vis)
 
	new_segment.scale = Vector3.ZERO
	var tween = crop.create_tween()
	tween.tween_property(new_segment, "scale", Vector3.ONE, 1.5).set_trans(Tween.TRANS_BACK)
	
	# 🔋 RE-COMPENSACIÓN ENERGÉTICA BALANCEADA
	var costo_final = 15.0
	if new_segment.type == CropSegment3D.SegmentType.LEAF:
		costo_final = 5.0 if modo_supervivencia else 10.0 # Una hoja de emergencia es muy económica para salvar a la planta
	elif new_segment.type == CropSegment3D.SegmentType.BRANCH:
		costo_final = 15.0
	elif new_segment.type == CropSegment3D.SegmentType.FRUIT or new_segment.type == CropSegment3D.SegmentType.FLOWER:
		costo_final = 25.0
		
	crop.root_segment.energia_almacenada -= costo_final

func _determinar_escena_por_adn(parent_segment: CropSegment3D, marker_idx: int, p_vis: ProceduralVisualData, stats: Dictionary) -> PackedScene:
	# 🚨 DICTADURA BIOLÓGICA: Si no hay hojas o la energía peligra, obligamos a entregar una Hoja
	if stats.get("modo_supervivencia", false):
		if not p_vis.leaf_variants.is_empty():
			return p_vis.leaf_variants.pick_random().scene

	# Case 1: Marcadores en el TRONCO
	if parent_segment.type == CropSegment3D.SegmentType.TRUNK:
		if marker_idx == 0:
			var pool_apical = []
			if not p_vis.branch_variants.is_empty(): pool_apical.append(p_vis.branch_variants.pick_random().scene)
			if not p_vis.leaf_variants.is_empty(): pool_apical.append(p_vis.leaf_variants.pick_random().scene)
			return pool_apical.pick_random() if not pool_apical.is_empty() else null
		else:
			var pool_lateral = []
			if p_vis.permitir_ramas_en_tronco and not p_vis.branch_variants.is_empty():
				pool_lateral.append(p_vis.branch_variants.pick_random().scene)
			if p_vis.permitir_hojas_en_tronco and not p_vis.leaf_variants.is_empty():
				pool_lateral.append(p_vis.leaf_variants.pick_random().scene)
			
			if not pool_lateral.is_empty():
				return pool_lateral.pick_random()
			return null

	# Case 2: Marcadores en las RAMAS
	elif parent_segment.type == CropSegment3D.SegmentType.BRANCH:
		var prof_actual = _calcular_distancia_al_tronco(parent_segment)
		var pool_rama = []
		
		if prof_actual < p_vis.max_profundidad_ramas and not p_vis.branch_variants.is_empty():
			if randf() < p_vis.branch_chance:
				return p_vis.branch_variants.pick_random().scene
				
		if not p_vis.leaf_variants.is_empty():
			pool_rama.append(p_vis.leaf_variants.pick_random().scene)
		if stats["leaf_count"] > 2:
			if not p_vis.fruit_variants.is_empty() and randf() < p_vis.fruit_chance:
				return p_vis.fruit_variants.pick_random().scene
			if not p_vis.flower_variants.is_empty() and randf() < p_vis.flower_chance:
				return p_vis.flower_variants.pick_random().scene
				
		return pool_rama.pick_random() if not pool_rama.is_empty() else null
		
	return parent_segment.determinar_siguiente_segmento(p_vis, stats)

func _obtener_scenes_de_variantes(variants: Array[CropVariantData]) -> Array:
	var scenes = []
	for v in variants:
		if v and v.scene: scenes.append(v.scene)
	return scenes
 
func _aplicar_fisicas_y_rotacion_nodo(nodo: CropSegment3D, p_vis: ProceduralVisualData) -> void:
	nodo.rotation.y = randf_range(0.0, TAU)
	if nodo.type == CropSegment3D.SegmentType.LEAF:
		var caida_grados = p_vis.inclinacion_caida_hojas + randf_range(-p_vis.desvío_caida_aleatoria, p_vis.desvío_caida_aleatoria)
		nodo.rotation.x = deg_to_rad(caida_grados)
	else:
		nodo.rotation.x += randf_range(-0.08, 0.08)
		nodo.rotation.z += randf_range(-0.08, 0.08)
 
func _collect_all_free_markers(nodo: Node, p_vis: ProceduralVisualData, desesperado: bool) -> Array[Marker3D]:
	var list: Array[Marker3D] = []
	if not nodo: return list
	
	if nodo is CropSegment3D:
		if nodo.type == CropSegment3D.SegmentType.TRUNK:
			# 1. Marcador Apical
			if nodo.puntos_de_crecimiento.size() > 0:
				var m_apical = nodo.puntos_de_crecimiento[0]
				if m_apical.get_child_count() == 0:
					if p_vis.eje_guia_unico:
						if nodo == _obtener_punta_eje_guia(): list.append(m_apical)
					else:
						var cant_troncos = _contar_segmentos_tipo(crop.root_segment, CropSegment3D.SegmentType.TRUNK)
						if cant_troncos >= p_vis.altura_objetivo_tronco or nodo == _obtener_tronco_mas_alto(crop.root_segment):
							list.append(m_apical)
			
			# 2. Marcadores Laterales
			for i in range(1, nodo.puntos_de_crecimiento.size()):
				var m_lateral = nodo.puntos_de_crecimiento[i]
				if m_lateral.get_child_count() == 0:
					# 🌟 BROTE EPICÓRMICO: Si está desesperado, ignora el ADN y ofrece el marcador lateral para salvarse
					if desesperado or p_vis.permitir_ramas_en_tronco or p_vis.permitir_hojas_en_tronco:
						list.append(m_lateral)
						
		elif nodo.type == CropSegment3D.SegmentType.BRANCH:
			var dist = _calcular_distancia_al_tronco(nodo)
			if dist <= p_vis.max_profundidad_ramas:
				for marker in nodo.puntos_de_crecimiento:
					if marker.get_child_count() == 0: list.append(marker)
					
	for child in nodo.get_children(): 
		list.append_array(_collect_all_free_markers(child, p_vis, desesperado))
	return list
 
func _contar_segmentos_tipo(node: Node, tipo: CropSegment3D.SegmentType) -> int:
	var count = 0
	if node is CropSegment3D and node.type == tipo: count += 1
	for child in node.get_children(): count += _contar_segmentos_tipo(child, tipo)
	return count
 
func _calcular_distancia_al_tronco(node: CropSegment3D) -> int:
	var dist = 0
	var actual = node.get_parent()
	while actual:
		if actual is CropSegment3D:
			if actual.type == CropSegment3D.SegmentType.TRUNK: break
			if actual.type == CropSegment3D.SegmentType.BRANCH: dist += 1
		actual = actual.get_parent()
	return dist
#endregion
