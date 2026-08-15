extends Node
class_name FormController

# ==========================================
# 🎛️ CONTROLADOR DE FORMA ACTIVA
# ==========================================
# FormLibrary sabe QUÉ formas se conocen. Este nodo sabe CUÁL está
# equipada ahora y se encarga de mostrarla. Fase 1 (Asimilación):
# clona la malla exacta del objeto y oculta todo lo demás que sea
# hijo directo del slime, así no hay forma de que algo se superponga.
# La transición usa un shader de disolución (dissolve_reveal.gdshader):
# la silueta se revela con un patrón de ruido mientras se materializa,
# y al terminar se cambia al material/shader real del objeto.

signal form_changed(new_form: FormData)

@export var form_reveal_delay_ms: float = 150.0 # duración de la disolución, en milisegundos

@onready var slime: Node3D = get_parent()
@onready var form_library: FormLibrary = slime.get_node("FormLibrary")

var current_form_index: int = 0

# true = mostrando una forma asimilada (no la gelatina nativa). Solo se
# escribe desde este script — trátalo como solo-lectura desde afuera.
var is_assimilated_form: bool = false

var _form_mesh_instance: MeshInstance3D
var _hidden_siblings: Array[Node] = []
var _dissolve_material: ShaderMaterial
var _current_reveal_tween: Tween

func _ready():
	_form_mesh_instance = MeshInstance3D.new()
	_form_mesh_instance.name = "AssimilatedFormMesh"
	_form_mesh_instance.visible = false
	# Deferido: en _ready() el slime todavía está ocupado montando SUS
	# propios hijos, y add_child() directo aquí falla con "Parent node
	# is busy setting up children".
	slime.add_child.call_deferred(_form_mesh_instance)
	
	var dissolve_shader = load("res://slime_test/dissolve_reveal.gdshader")
	if dissolve_shader:
		_dissolve_material = ShaderMaterial.new()
		_dissolve_material.shader = dissolve_shader
	else:
		push_error("FormController: no se encontró res://slime_test/dissolve_reveal.gdshader — cópialo ahí (o ajusta la ruta en _ready()) para tener la transición con disolución.")
	
	print("🔵 FormController listo. form_library=", form_library)

func cycle_form(direction: int) -> FormData:
	"""Rota entre las formas ya asimiladas y devuelve la nueva forma."""
	var forms = form_library.get_assimilated_forms()
	print("🔵 cycle_form(", direction, "): formas conocidas=", forms.size())
	if forms.size() <= 1:
		return forms[0] if forms.size() == 1 else null
		
	current_form_index += direction
	
	if current_form_index >= forms.size():
		current_form_index = 0
	elif current_form_index < 0:
		current_form_index = forms.size() - 1
		
	var new_form = forms[current_form_index]
	_apply_visual(new_form)
	form_changed.emit(new_form)
	return new_form

func get_current_form() -> FormData:
	var forms = form_library.get_assimilated_forms()
	if forms.is_empty():
		return null
	if current_form_index >= forms.size():
		current_form_index = 0
	return forms[current_form_index]

func get_current_form_id() -> String:
	var form = get_current_form()
	return form.id if form else "slime"

func set_current_form(id: String) -> void:
	var forms = form_library.get_assimilated_forms()
	print("🔵 set_current_form('", id, "') — disponibles: ", forms.map(func(f): return f.id))
	for i in forms.size():
		if forms[i].id == id:
			current_form_index = i
			_apply_visual(forms[i])
			form_changed.emit(forms[i])
			return
	print("⚠️ set_current_form: no se encontró la forma '", id, "'")

# ==========================================
# 🎨 VISUAL — ASIMILACIÓN (Fase 1: disolución + malla exacta)
# ==========================================
func _apply_visual(form_data: FormData) -> void:
	print("🔵 _apply_visual: form=", form_data.id if form_data else "null")
	if form_data == null:
		return
	if form_data.id == "slime" or form_data.mesh == null:
		_show_native_body()
	else:
		_show_assimilated_mesh(form_data)

func _show_assimilated_mesh(form_data: FormData) -> void:
	print("🔵 _show_assimilated_mesh: '", form_data.id, "' mesh=", form_data.mesh, " _form_mesh_instance.is_inside_tree()=", _form_mesh_instance.is_inside_tree())
	if not is_assimilated_form:
		var exceptions: Array = [_form_mesh_instance]
		var camera_node = slime.get("camera_controller")
		if camera_node != null:
			exceptions.append(camera_node)
		_hide_all_slime_children_except(exceptions)
		is_assimilated_form = true
	
	_form_mesh_instance.mesh = form_data.mesh
	_form_mesh_instance.visible = true
	
	if _current_reveal_tween and _current_reveal_tween.is_valid():
		_current_reveal_tween.kill()
	
	if _dissolve_material == null:
		# El shader de disolución no cargó — se aplica el material final directo, sin transición.
		_form_mesh_instance.material_override = form_data.material
		return
	
	_form_mesh_instance.material_override = _dissolve_material
	_dissolve_material.set_shader_parameter("reveal_progress", 0.0)
	
	_current_reveal_tween = create_tween()
	_current_reveal_tween.tween_method(
		func(v): _dissolve_material.set_shader_parameter("reveal_progress", v),
		0.0, 1.0, form_reveal_delay_ms / 1000.0
	)
	await _current_reveal_tween.finished
	if is_instance_valid(_form_mesh_instance) and _form_mesh_instance.mesh == form_data.mesh:
		_form_mesh_instance.material_override = form_data.material
		print("✅ _show_assimilated_mesh: disolución completa, material final aplicado")

func _show_native_body() -> void:
	print("🔵 _show_native_body: restaurando cuerpo nativo")
	if _current_reveal_tween and _current_reveal_tween.is_valid():
		_current_reveal_tween.kill()
	_form_mesh_instance.visible = false
	if is_assimilated_form:
		_restore_hidden_children()
		is_assimilated_form = false

func _hide_all_slime_children_except(exceptions: Array) -> void:
	_hidden_siblings.clear()
	for child in slime.get_children():
		if child in exceptions:
			continue
		if (child is Node3D or child is CanvasItem) and child.visible:
			_hidden_siblings.append(child)
			child.visible = false
	print("🔵 _hide_all_slime_children_except: ocultados=", _hidden_siblings)

func _restore_hidden_children() -> void:
	for child in _hidden_siblings:
		if is_instance_valid(child):
			child.visible = true
	_hidden_siblings.clear()
