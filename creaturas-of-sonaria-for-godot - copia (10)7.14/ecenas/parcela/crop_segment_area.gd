extends Area3D
class_name CropSegmentArea

# Variables que almacenarán las propiedades del segmento de forma nativa
var type: int
var vida_actual: float
var max_vida: float
var item_recompensa: Resource # Tu ItemData
var visual_node: Node3D
var shape_node: CollisionShape3D
var parent_item: RigidBody3D # Referencia al PickableItem contenedor

# 🎯 EL MÉTODO ESTÁNDAR UNIVERSAL
func take_damage(amount: float) -> void:
	vida_actual -= amount
	
	# Efecto visual de impacto (escala elástica)
	if is_instance_valid(visual_node):
		var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		tween.tween_property(visual_node, "scale", Vector3.ONE * 0.7, 0.05)
		tween.tween_property(visual_node, "scale", Vector3.ONE, 0.1)
		
	# Si se agota la vida, le pide al contenedor que lo desprenda físicamente
	if vida_actual <= 0.0:
		if is_instance_valid(parent_item) and parent_item.has_method("desprender_segmento"):
			parent_item.desprender_segmento(self)
