extends Node
class_name FormLibrary

# ==========================================
# 📚 BIBLIOTECA DE FORMAS — COLECCIÓN
# ==========================================
# Dueña de QUÉ formas se conocen. No decide cuál está activa
# ahora mismo — eso lo sigue manejando FormController.

signal form_assimilated(form_data: FormData)

var _forms: Dictionary = {} # String (id) -> FormData

func _ready():
	_register_base_slime_form()

func _register_base_slime_form():
	var slime_form := FormData.new()
	slime_form.id = "slime"
	slime_form.display_name = "SLIME"
	slime_form.mesh = null # la forma base usa liquid_mass_mesh directamente, no un mesh propio
	_forms[slime_form.id] = slime_form

func has_form(id: String) -> bool:
	return _forms.has(id)

func get_form(id: String) -> FormData:
	return _forms.get(id, null)

func get_assimilated_forms() -> Array[FormData]:
	var list: Array[FormData] = []
	for key in _forms.keys():
		list.append(_forms[key])
	return list

func assimilate(data: FormData) -> void:
	if data == null or data.id == "":
		return
	if _forms.has(data.id):
		return # ya la conocíamos, no hay nada nuevo que hacer
	_forms[data.id] = data
	form_assimilated.emit(data)
