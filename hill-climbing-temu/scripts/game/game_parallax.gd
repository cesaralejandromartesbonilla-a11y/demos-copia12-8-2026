class_name GameParallax
extends ParallaxBackground

const SEGMENT_WIDTH := 3200.0

@onready var _sky_layer: ParallaxLayer = $SkyLayer
@onready var _hills_far_layer: ParallaxLayer = $HillsFarLayer
@onready var _hills_near_layer: ParallaxLayer = $HillsNearLayer
@onready var _sky: ColorRect = $SkyLayer/Sky
@onready var _hills_far: Polygon2D = $HillsFarLayer/HillsFar
@onready var _hills_near: Polygon2D = $HillsNearLayer/HillsNear


func _ready() -> void:
	scroll_ignore_camera_zoom = true

	for layer: ParallaxLayer in [_sky_layer, _hills_far_layer, _hills_near_layer]:
		layer.motion_mirroring = Vector2(SEGMENT_WIDTH, 0.0)


func apply_map(map_def: MapDef) -> void:
	if map_def == null:
		return

	_sky.color = map_def.sky_color
	_hills_far.color = map_def.hills_far_color
	_hills_near.color = map_def.hills_near_color


func _process(_delta: float) -> void:
	var viewport_camera := get_viewport().get_camera_2d()
	if viewport_camera == null:
		return

	scroll_offset = viewport_camera.global_position
