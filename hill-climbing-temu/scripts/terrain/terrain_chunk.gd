class_name TerrainChunk
extends StaticBody2D

const GROUND_DEPTH := 450.0

@onready var _visual: Polygon2D = $TerrainVisual
@onready var _collision: CollisionPolygon2D = $CollisionPolygon2D

var ground_color: Color = Color(0.35, 0.55, 0.22)


func setup(surface_points: PackedVector2Array) -> void:
	if surface_points.size() < 2:
		return

	_visual.color = ground_color

	var polygon := PackedVector2Array()
	polygon.append_array(surface_points)

	var last_point := surface_points[surface_points.size() - 1]
	var first_point := surface_points[0]
	polygon.append(Vector2(last_point.x, last_point.y + GROUND_DEPTH))
	polygon.append(Vector2(first_point.x, first_point.y + GROUND_DEPTH))

	_visual.polygon = polygon
	_collision.polygon = polygon
