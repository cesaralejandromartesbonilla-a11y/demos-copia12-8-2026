extends Node
class_name CropMetabolism
 
var crop: ProceduralFreeCrop
 
func _ready() -> void:
	crop = get_parent() as ProceduralFreeCrop
	if not crop: return
	WeatherManager.tick_30m.connect(_on_global_time_tick)
 
#region LOGICA BIOLÓGICA E INICIALIZACIÓN
func start_metabolic_life(data: SeedData, original_item: ItemData) -> void:
	if not crop: return
	crop.seed_data = data
	crop.seed_item_data = original_item
	crop.current_state = crop.State.GROWING
	crop.growth_progress = 0.0
	crop.is_fertilized = false
	crop.is_checking_environment = true
	get_tree().create_timer(4.0).timeout.connect(_validate_environment_requirements)
 
func _validate_environment_requirements() -> void:
	if not crop: return
	_scan_environment()
	
	if crop.seed_data:
		if crop.seed_data.requires_submerged and not crop.is_submerged:
			_abort_and_refund_seed()
			return
		if not crop.seed_data.requires_submerged and crop.is_submerged:
			_abort_and_refund_seed()
			return
			
	crop.is_checking_environment = false
	_spawn_root_trunk()
 
func _spawn_root_trunk() -> void:
	if not crop or not crop.seed_data: return
	var p_vis = crop.seed_data.visual_data as ProceduralVisualData
	if not p_vis or p_vis.trunk_variants.is_empty(): return
 
	var primera_variante = p_vis.trunk_variants[0]
	if primera_variante and not primera_variante.etapas_desarrollo.is_empty():
		crop.root_segment = primera_variante.scene.instantiate() as CropSegment3D
		crop.root_segment.type = CropSegment3D.SegmentType.TRUNK
		crop.root_segment.variant_index = 0
		crop.root_segment.current_depth = 1
		crop.root_segment.energia_almacenada = crop.seed_data.energia_inicial
		
		crop.add_child(crop.root_segment)
		crop.root_segment._actualizar_estadisticas_y_visuales(p_vis)
 
func _scan_environment() -> void:
	if not crop: return
	var overlapping = crop.get_overlapping_areas()
	var found_water = false
	for area in overlapping: 
		if area.is_in_group("agua") or area.is_in_group("water"): found_water = true
	crop.is_submerged = found_water
 
func _on_root_area_entered(area: Area3D) -> void:
	if not crop: return
	if area.is_in_group("agua"): crop.is_submerged = true
 
func _on_root_area_exited(_area: Area3D) -> void:
	_scan_environment()
 
func _abort_and_refund_seed() -> void:
	if not crop: return
	if crop.seed_item_data and crop.item_base_scene: _spawn_item(crop.seed_item_data)
	crop.queue_free()
 
func _spawn_item(data: ItemData) -> void:
	if not crop: return
	var drop = crop.item_base_scene.instantiate()
	drop.data = data 
	crop.get_tree().current_scene.add_child(drop)
	drop.global_position = crop.global_position + Vector3(randf_range(-0.3, 0.3), 1.5, randf_range(-0.3, 0.3))
#endregion
 
#region RELOJ GLOBAL Y TICKS DE CRECIMIENTO
func _on_global_time_tick(_current_time: float) -> void:
	if not crop or crop.seed_data == null or crop.is_checking_environment: return
	if crop.current_state == crop.State.PEST_INFESTED: return
	if not crop.root_segment: return
 
	_actualizar_ciclo_frutos_recursivo(crop.root_segment)
 
	var p_vis = crop.seed_data.visual_data as ProceduralVisualData
	if not p_vis: return
 
	var costo_expansion = 15.0
	if crop.root_segment.energia_almacenada >= costo_expansion:
		# 🌴 El metabolismo le pide a la arquitectura que ejecute la expansión
		if crop.architecture:
			crop.architecture.expand_procedural_tree(p_vis, crop.nivel_estructural_arbol)
 
func evolucionar_y_subir_de_nivel() -> void:
	if not crop: return
	crop.nivel_estructural_arbol += 1
	if crop.root_segment: 
		_recalcular_profundidades_hijos(crop.root_segment)
	crop.growth_progress = 0.0
	crop.last_expansion_milestone = 0.0
 
func _recalcular_profundidades_hijos(parent_node: CropSegment3D) -> void:
	for marker in parent_node.puntos_de_crecimiento:
		if is_instance_valid(marker):
			for child in marker.get_children():
				if child is CropSegment3D:
					child.current_depth = parent_node.current_depth + 1
					_recalcular_profundidades_hijos(child)
 
func _actualizar_ciclo_frutos_recursivo(node: Node) -> void:
	if not crop or not node: return
	var p_vis = crop.seed_data.visual_data as ProceduralVisualData
	if node is CropSegment3D and node.has_method("procesar_biologia_segmento"):
		node.procesar_biologia_segmento(1.0, p_vis)
	for child in node.get_children(): _actualizar_ciclo_frutos_recursivo(child)
#endregion
