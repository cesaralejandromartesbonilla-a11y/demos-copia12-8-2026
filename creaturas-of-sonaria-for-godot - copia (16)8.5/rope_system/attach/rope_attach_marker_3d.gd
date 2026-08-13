class_name RopeAttachMarker3D
extends Marker3D
## Marcador que detecta objetos por proximidad y genera automáticamente
## un extremo de cuerda. Resuelve el otro extremo en este orden:
##   1. Su "generador" explícito (otro RopeAttachMarker3D, si fue seteado).
##   2. El marcador disponible más cercano dentro de search_radius.
##   3. Fallback: se ancla a sí mismo (StaticAnchor en su propia posición).
##
## Nota: esta búsqueda por cercanía es una herramienta de DESCUBRIMIENTO
## de a quién conectarse, no del sistema de colisión de la cuerda contra
## el mundo (eso se resuelve en fases posteriores, por segmento).

@export var detection_radius: float = 0.3
@export var search_radius: float = 3.0
@export var rope_scene: PackedScene # opcional; si es null, crea un Rope3D básico
@export var segment_count: int = 10

var _generator: RopeAttachMarker3D
var _touched_anchor: RopeAnchor
var _paired_with: RopeAttachMarker3D
var _active_rope: Rope3D
var _area: Area3D

func _ready() -> void:
	_setup_detection_area()

func _exit_tree() -> void:
	RopeAttachRegistry.unregister(self)

## Llamar desde código (ej: un generador de puente) ANTES de que el
## marcador toque algo, para declarar quién lo creó.
func set_generator(marker: RopeAttachMarker3D) -> void:
	_generator = marker

func _setup_detection_area() -> void:
	_area = Area3D.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = detection_radius
	shape.shape = sphere
	_area.add_child(shape)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if _touched_anchor != null:
		return # ya generamos nuestro extremo; ignoramos toques nuevos
	_touched_anchor = NodeAnchor.new(body)
	_resolve_other_end()

func _resolve_other_end() -> void:
	var other_anchor: RopeAnchor = null
	var other_marker: RopeAttachMarker3D = null

	if _generator != null and _generator._touched_anchor != null:
		other_anchor = _generator._touched_anchor
		other_marker = _generator
	else:
		var found: Node = RopeAttachRegistry.find_nearest_available(self, search_radius)
		if found != null:
			other_marker = found
			other_anchor = found._touched_anchor

	if other_anchor == null:
		# Nadie con quien conectar todavía: mejor un extremo estático
		# que una cuerda sin segundo punto.
		other_anchor = StaticAnchor.new(global_position)
		# Nos anotamos como disponibles por si alguien nos busca después.
		RopeAttachRegistry.register_available(self)
	elif other_marker != null:
		_paired_with = other_marker
		other_marker._paired_with = self
		RopeAttachRegistry.unregister(other_marker)
		RopeAttachRegistry.unregister(self)

	_spawn_rope(_touched_anchor, other_anchor)

func _spawn_rope(from_anchor: RopeAnchor, to_anchor: RopeAnchor) -> void:
	var rope: Rope3D
	if rope_scene != null:
		rope = rope_scene.instantiate()
	else:
		rope = Rope3D.new()
		rope.segment_count = segment_count
	get_tree().current_scene.add_child(rope)
	rope.set_anchor_start(from_anchor)
	rope.set_anchor_end(to_anchor)
	_active_rope = rope
