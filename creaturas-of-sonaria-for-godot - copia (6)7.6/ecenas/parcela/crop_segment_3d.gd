extends Node3D
class_name CropSegment3D

enum SegmentType { TRUNK, BRANCH, LEAF, FLOWER, FRUIT }

@export var type: SegmentType = SegmentType.BRANCH
@export var base_max_ramas: int = 2
@export var base_max_hojas: int = 4
@export var variant_index: int = 0
@export var puntos_de_crecimiento: Array[Marker3D] = []
@export var current_stage: int = 0
@export var item_recompensa_especifico: ItemData
@export var max_vida: float = 100.0

var vida_actual: float = 100.0
var ramas_actuales: int = 0
var hojas_actuales: int = 0
var current_depth: int = 1
var energia_almacenada: float = 0.0
var max_ramas_hijas: int = 2
var max_hojas_hijas: int = 4
var proximo_tick_ms: float = 0.0
var biologia_activa_este_frame: bool = false
var contenedor_visual: Node3D = null
var es_eje_guia: bool = false
var item_base_scene = preload("res://items/pickable_item.tscn")

func _ready() -> void:
	vida_actual = max_vida # Inicializar batería al máximo
	
	if not has_node("VisualModel"):
		contenedor_visual = Node3D.new()
		contenedor_visual.name = "VisualModel"
		add_child(contenedor_visual)
	else: contenedor_visual = get_node("VisualModel") as Node3D

func _obtener_lista_variantes(p_vis: ProceduralVisualData) -> Array[CropVariantData]:
	match type:
		SegmentType.TRUNK: return p_vis.trunk_variants
		SegmentType.BRANCH: return p_vis.branch_variants
		SegmentType.LEAF: return p_vis.leaf_variants
		SegmentType.FLOWER: return p_vis.flower_variants
		SegmentType.FRUIT: return p_vis.fruit_variants
	return []

func _obtener_tronco_principal() -> CropSegment3D:
	var nodo_actual = self
	var root_trunk: CropSegment3D = null
	while nodo_actual:
		if nodo_actual is CropSegment3D and nodo_actual.type == SegmentType.TRUNK: root_trunk = nodo_actual
		nodo_actual = nodo_actual.get_parent()
	return root_trunk

func intentar_mejorar_segmento(p_vis: ProceduralVisualData, energia_disponible: float) -> bool:
	var lista = _obtener_lista_variantes(p_vis)
	if variant_index >= lista.size() - 1: return false 
	var costo_mejora = lista[variant_index + 1].costo_evolucion
	if energia_disponible >= costo_mejora:
		variant_index += 1
		_actualizar_estadisticas_y_visuales(p_vis)
		return true
	return false

func _actualizar_estadisticas_y_visuales(p_vis: ProceduralVisualData) -> void:
	recalcular_conteos_reales()
	var lista = _obtener_lista_variantes(p_vis)
	if variant_index >= lista.size() or lista[variant_index] == null: return
	
	var datos_mutacion = lista[variant_index]
	max_ramas_hijas = int(base_max_ramas * datos_mutacion.multiplicador_capacidad_hijos)
	max_hojas_hijas = int(base_max_hojas * datos_mutacion.multiplicador_capacidad_hijos)
	
	if not has_node("VisualModel"):
		contenedor_visual = Node3D.new()
		contenedor_visual.name = "VisualModel"
		add_child(contenedor_visual)
	else: contenedor_visual = get_node("VisualModel") as Node3D
		
	var mesh_instance: MeshInstance3D = contenedor_visual.get_node("MeshEtapa") if contenedor_visual.has_node("MeshEtapa") else MeshInstance3D.new()
	if not mesh_instance.is_inside_tree() and not contenedor_visual.has_node("MeshEtapa"):
		mesh_instance.name = "MeshEtapa"
		contenedor_visual.add_child(mesh_instance)
		
	if not datos_mutacion.etapas_desarrollo.is_empty():
		mesh_instance.mesh = datos_mutacion.etapas_desarrollo[clamp(current_stage, 0, datos_mutacion.etapas_desarrollo.size() - 1)]

# =================================================================
# TÓMBOLA ESTRUCTURAL ADAPTATIVA DE SUPERVIVENCIA
# =================================================================
func determinar_siguiente_segmento(p_vis: ProceduralVisualData, _stats: Dictionary) -> PackedScene:
	recalcular_conteos_reales()
	var cant_hojas = hojas_actuales
	
	if cant_hojas < 3 and not p_vis.leaf_variants.is_empty():
		return p_vis.leaf_variants[0].scene
		
	var peso_rama = p_vis.branch_chance if p_vis.permitir_ramas_en_tronco else 0.0
	
	if p_vis.eje_guia_unico:
		peso_rama = 0.0
	
	var permite_hojas = p_vis.permitir_hojas_en_tronco
	if p_vis.eje_guia_unico and type == SegmentType.TRUNK:
		permite_hojas = true 
		
	var peso_hoja = p_vis.leaf_chance if permite_hojas else 0.0
	var peso_flor = p_vis.flower_chance if cant_hojas >= 4 else 0.0
	
	var total = peso_rama + peso_hoja + peso_flor
	if total <= 0.0:
		return p_vis.leaf_variants[0].scene if not p_vis.leaf_variants.is_empty() else null
		
	var r = randf() * total
	if r <= peso_rama and not p_vis.branch_variants.is_empty():
		return p_vis.branch_variants[0].scene
	elif r <= peso_rama + peso_hoja and not p_vis.leaf_variants.is_empty():
		return p_vis.leaf_variants[0].scene
	else:
		return p_vis.flower_variants[0].scene if not p_vis.flower_variants.is_empty() else null

func _calcular_distancia_al_tronco_local() -> int:
	var dist = 1
	var actual = get_parent()
	while actual:
		if actual is Node3D:
			var segmento = actual.get_parent()
			if segmento is CropSegment3D:
				if segmento.type == SegmentType.TRUNK: break
				if segmento.type == SegmentType.BRANCH: dist += 1
		actual = actual.get_parent()
	return dist

func _calcular_y_preparar_flor(lista_flores: Array[CropVariantData], energia_total: float) -> PackedScene:
	var idx_elegido = 0
	for i in range(lista_flores.size() - 1, -1, -1):
		if energia_total >= lista_flores[i].costo_evolucion * 1.3:
			idx_elegido = i
			break
	set_meta("idx_variante_pendiente", idx_elegido)
	return lista_flores[0].scene

# =================================================================
# ⚙️ PROCESADOR BIOLÓGICO CENTRAL + GESTIÓN DE BATERÍA
# =================================================================
func procesar_biologia_segmento(_clima: float, p_vis: ProceduralVisualData) -> void:
	var nucleo = _obtener_tronco_principal()
	if not nucleo: return

	if self == nucleo:
		var tiempo_actual = Time.get_ticks_msec()
		if tiempo_actual >= nucleo.proximo_tick_ms:
			nucleo.biologia_activa_este_frame = true 
			nucleo.proximo_tick_ms = tiempo_actual + 10000 
		else: nucleo.biologia_activa_este_frame = false 

	if not nucleo.biologia_activa_este_frame: return
	
	# 🚨 CONTROL DE INANICIÓN POR BATERÍA CRÍTICA
	if nucleo.energia_almacenada <= 0.0:
		# Si la raíz se seca por completo, los segmentos consumen su propia batería usando tu canal unificado de daño
		take_damage(20.0)
	else:
		# Si hay energía de sobra, los segmentos autoreparan sus tejidos lentamente
		vida_actual = min(max_vida, vida_actual + 10.0)

	# Si este segmento colapsó en este ciclo, detenemos su procesamiento metabólico
	if vida_actual <= 0.0: return

	var lista_propia = _obtener_lista_variantes(p_vis)
	if variant_index >= lista_propia.size(): return
	var datos_actuales = lista_propia[variant_index]
	var mod_produccion = datos_actuales.multiplicador_produccion if datos_actuales else 1.0

	match type:
		SegmentType.TRUNK:
			if self == nucleo:
				energia_almacenada = max(0.0, energia_almacenada - 0.05)

		SegmentType.LEAF:
			nucleo.energia_almacenada += 8.5 * mod_produccion

		SegmentType.BRANCH:
			nucleo.energia_almacenada += 0.1 * mod_produccion

		SegmentType.FLOWER:
			if current_stage < datos_actuales.etapas_desarrollo.size() - 1:
				var costo = datos_actuales.costo_evolucion * 0.25
				if nucleo.energia_almacenada >= costo:
					nucleo.energia_almacenada -= costo
					current_stage += 1
					_actualizar_estadisticas_y_visuales(p_vis)
				return 

			var lista_frutas = p_vis.fruit_variants
			if lista_frutas.is_empty(): return
			var costo_nacimiento = datos_actuales.costo_evolucion
			
			if nucleo.energia_almacenada >= costo_nacimiento:
				for marker in puntos_de_crecimiento:
					if is_instance_valid(marker) and marker.get_child_count() == 0:
						if randf() < 0.3:
							nucleo.energia_almacenada -= costo_nacimiento
							var new_fruit = lista_frutas[0].scene.instantiate() as CropSegment3D
							new_fruit.type = SegmentType.FRUIT
							marker.add_child(new_fruit)
							new_fruit._actualizar_estadisticas_y_visuales(p_vis)
							new_fruit.rotation.y = randf_range(0.0, TAU)
							break

		SegmentType.FRUIT:
			if current_stage < datos_actuales.etapas_desarrollo.size() - 1:
				var costo_nutricional = datos_actuales.costo_evolucion * 0.2
				if nucleo.energia_almacenada >= costo_nutricional:
					nucleo.energia_almacenada -= costo_nutricional
					current_stage += 1
					_actualizar_estadisticas_y_visuales(p_vis)

# =================================================================
# 🪓 INTERFAZ DE DAÑO UNIFICADA Y MOTOR DE FÍSICAS DE CAÍDA
# =================================================================
func take_damage(amount: float) -> void:
	vida_actual = max(0.0, vida_actual - amount)
	if vida_actual <= 0.0:
		caer_segmento()

func caer_segmento(separar_todo_individual: bool = false) -> void:
	if not contenedor_visual or not is_instance_valid(contenedor_visual): 
		_limpiar_logica_segmento()
		return

	if separar_todo_individual:
		# Forzamos a todos los hijos a soltarse de forma independiente primero
		_desmoronar_hijos_recursivo()
		
	# Instanciamos tu objeto recolectable real en lugar de un RigidBody genérico
	var nuevo_item = item_base_scene.instantiate() as PickableItem
	
	var mundo = get_tree().current_scene
	if mundo:
		mundo.add_child(nuevo_item)
	
	nuevo_item.global_transform = contenedor_visual.global_transform

	# Asignamos o generamos la información del ítem para que el inventario la reconozca
	if item_recompensa_especifico:
		nuevo_item.data = item_recompensa_especifico
	else:
		_generar_item_data_fallback(nuevo_item)

	# Iniciamos la transferencia geométrica y de colisiones al nuevo PickableItem
	_recolectar_subarbol_recursivo(self, nuevo_item, separar_todo_individual)
	
	# Inicializamos manualmente las propiedades internas de tu script PickableItem
	nuevo_item.inicializar_objeto()

	# Aplicamos impulsos físicos iniciales dinámicos para simular la caída realista
	nuevo_item.angular_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(-1.0, 1.0), randf_range(-2.0, 2.0))
	nuevo_item.linear_velocity = Vector3(randf_range(-0.5, 0.5), 1.0, randf_range(-0.5, 0.5))
	
	_limpiar_logica_segmento()

func _desmoronar_hijos_recursivo() -> void:
	for marker in puntos_de_crecimiento:
		if is_instance_valid(marker) and marker.get_child_count() > 0:
			var hijo = marker.get_child(0)
			if hijo is CropSegment3D:
				hijo.caer_segmento(true)

func _recolectar_subarbol_recursivo(segmento_actual: CropSegment3D, item_master: PickableItem, solo_un_nodo: bool) -> void:
	if not segmento_actual or not is_instance_valid(segmento_actual): return

	if segmento_actual.contenedor_visual and is_instance_valid(segmento_actual.contenedor_visual):
		var trans_global = segmento_actual.contenedor_visual.global_transform
		
		# 1. Instanciamos nuestra nueva clase interactiva
		var area_segmento = CropSegmentArea.new()
		area_segmento.name = "Area_" + str(segmento_actual.name)
		item_master.add_child(area_segmento)
		area_segmento.global_transform = trans_global
		
		# Configuración de capas físicas (Capa 3, por ejemplo, para interactivos)
		area_segmento.collision_layer = 3
		area_segmento.collision_mask = 0
		
		# 2. Generamos su colisionador dedicado
		var collision_shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		
		match segmento_actual.type:
			SegmentType.TRUNK: box.size = Vector3(0.4, 1.1, 0.4)
			SegmentType.BRANCH: box.size = Vector3(0.25, 0.8, 0.25)
			SegmentType.LEAF: box.size = Vector3(0.2, 0.15, 0.2)
			SegmentType.FLOWER: box.size = Vector3(0.15, 0.15, 0.15)
			SegmentType.FRUIT: box.size = Vector3(0.2, 0.2, 0.2)
			
		collision_shape.shape = box
		area_segmento.add_child(collision_shape)
		collision_shape.transform = Transform3D.IDENTITY
		
		# 3. Mudamos la malla visual
		segmento_actual.contenedor_visual.get_parent().remove_child(segmento_actual.contenedor_visual)
		area_segmento.add_child(segmento_actual.contenedor_visual)
		segmento_actual.contenedor_visual.transform = Transform3D.IDENTITY
		
		# 4. Inyectamos los datos directamente en las variables de la clase
		area_segmento.type = segmento_actual.type
		area_segmento.vida_actual = segmento_actual.vida_actual
		area_segmento.max_vida = segmento_actual.max_vida
		area_segmento.item_recompensa = segmento_actual.item_recompensa_especifico
		area_segmento.visual_node = segmento_actual.contenedor_visual
		area_segmento.shape_node = collision_shape
		area_segmento.parent_item = item_master

		# Soporte físico para el cuerpo rígido maestro
		if segmento_actual == self:
			var colision_fisica_global = CollisionShape3D.new()
			colision_fisica_global.shape = box
			item_master.add_child(colision_fisica_global)
			colision_fisica_global.global_transform = trans_global
			item_master.collision = colision_fisica_global

	if not solo_un_nodo:
		for marker in segmento_actual.puntos_de_crecimiento:
			if is_instance_valid(marker) and marker.get_child_count() > 0:
				var hijo = marker.get_child(0)
				if hijo is CropSegment3D:
					_recolectar_subarbol_recursivo(hijo, item_master, false)

func _limpiar_logica_segmento() -> void:
	var marcador_padre = get_parent()
	if marcador_padre:
		marcador_padre.remove_child(self)
	queue_free() # Al borrarse este nodo, se borran en cascada todos sus marcadores e hijos lógicos vacíos de forma limpia

func get_available_grow_points() -> Array[Marker3D]:
	var libres: Array[Marker3D] = []
	for marker in puntos_de_crecimiento:
		if is_instance_valid(marker) and marker.get_child_count() == 0: libres.append(marker)
	return libres

func _contar_troncos_global(node: Node) -> int:
	var count = 0
	if node is CropSegment3D and node.type == SegmentType.TRUNK: 
		count += 1
	for child in node.get_children(): 
		count += _contar_troncos_global(child)
	return count

func recalcular_conteos_reales() -> void:
	hojas_actuales = 0
	ramas_actuales = 0
	for marker in puntos_de_crecimiento:
		if marker.get_child_count() > 0:
			var hijo = marker.get_child(0)
			if hijo is CropSegment3D:
				if hijo.type == SegmentType.LEAF:
					hojas_actuales += 1
				elif hijo.type == SegmentType.BRANCH:
					ramas_actuales += 1

func _generar_item_data_fallback(item_objetivo: PickableItem) -> void:
	# Si no hay un recurso ItemData asignado en el inspector, creamos uno dinámico 
	# para evitar errores de ejecución nulos en tu HandsInventory
	var datos_ficticios = ItemData.new()
	match type:
		SegmentType.TRUNK:
			datos_ficticios.item_name = "Tronco de Madera"
			datos_ficticios.item_category = "planta"
		SegmentType.BRANCH:
			datos_ficticios.item_name = "Rama Procedural"
			datos_ficticios.item_category = "planta"
		SegmentType.LEAF:
			datos_ficticios.item_name = "Follaje"
			datos_ficticios.item_category = "planta"
		_:
			datos_ficticios.item_name = "Residuo Orgánico"
			datos_ficticios.item_category = "planta"
			
	datos_ficticios.is_tool = false
	datos_ficticios.is_edible = false
	item_objetivo.data = datos_ficticios
