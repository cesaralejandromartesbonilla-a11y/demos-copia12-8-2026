class_name RopeMeshRenderer3D
extends MeshInstance3D
## FASE 2: genera una malla de tubo real a partir de los puntos que produce
## Rope3D. No sabe nada de Verlet, anclas, ni colisión — solo lee `points`
## cada frame y arma geometría. Poné este nodo como HIJO directo del
## Rope3D que querés dibujar (usa su mismo espacio local).
##
## Cuando esto esté andando bien, podés poner debug_draw = false en el
## Rope3D correspondiente: ya no hace falta la línea amarilla de debug.

@export var rope_path: NodePath # opcional; si no se setea, usa el nodo padre
@export var radius: float = 0.03
@export var radial_segments: int = 6
@export var smoothing_subdivisions: int = 3 # puntos intermedios via Catmull-Rom entre cada par simulado
@export var uv_tiling: float = 1.0

var _rope: Rope3D

func _ready() -> void:
	if rope_path != NodePath():
		_rope = get_node(rope_path) as Rope3D
	else:
		_rope = get_parent() as Rope3D
	if _rope == null:
		push_warning("RopeMeshRenderer3D no encontró un Rope3D del cual leer puntos.")
	mesh = ArrayMesh.new()

func _process(_delta: float) -> void:
	if _rope == null or _rope.points.size() < 2:
		return
	_rebuild_mesh(_smooth_points(_rope.points))

## Interpola puntos extra entre cada par de partículas simuladas usando
## Catmull-Rom, para que el tubo se vea curvo aunque el Rope3D tenga
## pocos segmentos de física (barato de simular, suave de mostrar).
func _smooth_points(raw: PackedVector3Array) -> PackedVector3Array:
	if smoothing_subdivisions <= 0 or raw.size() < 3:
		return raw
	var result := PackedVector3Array()
	var n := raw.size()
	for i in range(n - 1):
		var p0 := raw[max(i - 1, 0)]
		var p1 := raw[i]
		var p2 := raw[i + 1]
		var p3 := raw[min(i + 2, n - 1)]
		result.append(p1)
		for s in range(1, smoothing_subdivisions + 1):
			var t := float(s) / float(smoothing_subdivisions + 1)
			result.append(_catmull_rom(p0, p1, p2, p3, t))
	result.append(raw[n - 1])
	return result

func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		(2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)

## Genera anillos de vértices perpendiculares a la curva y los conecta en
## triángulos. Usa transporte paralelo simple para que el tubo no se
## "retuerza" (twisting) entre un segmento y el siguiente.
func _rebuild_mesh(curve_points: PackedVector3Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rings: Array = []
	var prev_normal := Vector3.UP

	for i in range(curve_points.size()):
		var tangent: Vector3
		if i == 0:
			tangent = (curve_points[i + 1] - curve_points[i]).normalized()
		elif i == curve_points.size() - 1:
			tangent = (curve_points[i] - curve_points[i - 1]).normalized()
		else:
			tangent = (curve_points[i + 1] - curve_points[i - 1]).normalized()

		var normal := (prev_normal - tangent * prev_normal.dot(tangent))
		if normal.length() < 0.001:
			normal = tangent.cross(Vector3.RIGHT)
			if normal.length() < 0.001:
				normal = tangent.cross(Vector3.UP)
		normal = normal.normalized()
		var binormal := tangent.cross(normal).normalized()
		prev_normal = normal

		var ring := PackedVector3Array()
		for s in range(radial_segments):
			var angle := TAU * float(s) / float(radial_segments)
			var offset := (normal * cos(angle) + binormal * sin(angle)) * radius
			ring.append(curve_points[i] + offset)
		rings.append(ring)

	for i in range(rings.size() - 1):
		var ring_a: PackedVector3Array = rings[i]
		var ring_b: PackedVector3Array = rings[i + 1]
		var v_a := float(i) / float(rings.size() - 1) * uv_tiling
		var v_b := float(i + 1) / float(rings.size() - 1) * uv_tiling
		for s in range(radial_segments):
			var s_next := (s + 1) % radial_segments
			var u_a := float(s) / float(radial_segments)
			var u_b := float(s_next) / float(radial_segments)

			_add_triangle(st, ring_a[s], ring_b[s], ring_a[s_next],
				Vector2(u_a, v_a), Vector2(u_a, v_b), Vector2(u_b, v_a))
			_add_triangle(st, ring_a[s_next], ring_b[s], ring_b[s_next],
				Vector2(u_b, v_a), Vector2(u_a, v_b), Vector2(u_b, v_b))

	st.generate_normals()
	mesh = st.commit()

func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
	st.set_uv(uv_a)
	st.add_vertex(a)
	st.set_uv(uv_b)
	st.add_vertex(b)
	st.set_uv(uv_c)
	st.add_vertex(c)
