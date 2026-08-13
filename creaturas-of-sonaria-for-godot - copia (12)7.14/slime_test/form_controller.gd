class_name FormController extends Node

# --- Definiciones ---
enum Form { SLIME, STONE, FIRE, SKELETON, DEVOURER }

signal form_changed(new_form: Form)

@export var unlocked_forms: Array[Form] = [Form.SLIME]
var current_form_index: int = 0

# --- Lógica de Gestión ---

func cycle_form(direction: int) -> Form:
	"""Rota entre las formas disponibles y devuelve la nueva forma."""
	if unlocked_forms.size() <= 1:
		return unlocked_forms[0]
		
	current_form_index += direction
	
	# Loop infinito
	if current_form_index >= unlocked_forms.size():
		current_form_index = 0
	elif current_form_index < 0:
		current_form_index = unlocked_forms.size() - 1
		
	var new_form = unlocked_forms[current_form_index]
	form_changed.emit(new_form)
	return new_form

func unlock_form(new_form: Form):
	"""Añade una forma al inventario si no existe."""
	if not unlocked_forms.has(new_form):
		unlocked_forms.append(new_form)
		print("FormController: ¡Nueva forma desbloqueada! ", Form.keys()[new_form])

func get_current_form() -> Form:
	return unlocked_forms[current_form_index]

func get_form_name(form: Form) -> String:
	match form:
		Form.SLIME: return "SLIME"
		Form.STONE: return "PIEDRA"
		Form.FIRE: return "FUEGO"
		Form.SKELETON: return "ESQUELETO"
		Form.DEVOURER: return "DEVORADOR MASIVO"
	return "DESCONOCIDO"
