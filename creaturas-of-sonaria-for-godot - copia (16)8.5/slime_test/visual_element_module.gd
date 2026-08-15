extends Node
class_name VisualElementModule

@export var transition_duration: float = 0.5
@onready var slime: CharacterBody3D = get_parent()

var active_tween: Tween

# ==========================================
# 🧬 DICCIONARIO DE ELEMENTOS (IMPUREZAS Y RESTOS)
# ==========================================
var element_profiles: Dictionary = {
	"BASE": {
		"element_blend": 0.0,
		"ink_density": 0.0,
		"orb_size": 0.0
	},
	"FIRE": {
		"element_color": Color(1.0, 0.2, 0.0, 0.9),
		"element_blend": 0.8, # <--- CRUCIAL: mezcla el color con la base
		"ink_color": Color(1.0, 0.7, 0.0, 1.0),
		"ink_density": 0.4,
		"orb_size": 0.05,
		"orb_color": Color(1.0, 0.9, 0.2, 1.0)
	},
	"STONE": {
		"element_color": Color(0.3, 0.3, 0.3, 0.95),
		"element_blend": 0.9,
		"ink_density": 0.0,
		"orb_size": 0.22, # Muestra trozos sólidos en el cuerpo
		"orb_color": Color(0.15, 0.15, 0.15, 1.0)
	},
	"POISON": {
		"element_color": Color(0.2, 0.8, 0.2, 0.8),
		"element_blend": 0.7,
		"ink_color": Color(0.4, 1.0, 0.1, 1.0),
		"ink_density": 0.65,
		"orb_size": 0.1,
		"orb_color": Color(0.6, 1.0, 0.3, 0.6)
	}
}

# ==========================================
# 🔄 TRANSICIÓN E INYECCIÓN
# ==========================================
func transition_to_element(element_name: String, custom_mat: Material = null) -> void:
	var shader_mat = _get_active_shader_material()
	if not shader_mat:
		push_warning("VisualElementModule: No se encontró un ShaderMaterial válido en el slime.")
		return
		
	var target_params: Dictionary = {}
	
	# 1. Si el objeto tenía un color/material propio
	if custom_mat != null and "albedo_color" in custom_mat:
		var c: Color = custom_mat.albedo_color
		target_params["element_color"] = c
		target_params["element_blend"] = 0.85
		target_params["ink_color"] = c.darkened(0.3)
		target_params["ink_density"] = 0.5
		
	# 2. String de elemento conocido
	elif element_profiles.has(element_name):
		target_params = element_profiles[element_name].duplicate()
		
	# 3. FALLBACK: Elemento desconocido (genera un resto aleatorio)
	else:
		var rnd_color = Color(randf(), randf(), randf(), 1.0)
		target_params["element_color"] = rnd_color
		target_params["element_blend"] = 0.8
		target_params["ink_color"] = rnd_color.lightened(0.2)
		target_params["ink_density"] = 0.6
		target_params["orb_size"] = randf_range(0.08, 0.2)
		target_params["orb_color"] = rnd_color.darkened(0.4)

	_inject_and_verify(shader_mat, target_params)

# Fuerza la actualización visual del elemento activo actual (útil tras romper asimilación)
func refresh_element() -> void:
	if slime and slime.matter_controller:
		var elem = slime.matter_controller.current_element
		var mat = slime.matter_controller.current_custom_material
		transition_to_element(elem, mat)

# ==========================================
# 🕵️ VERIFICACIÓN E INYECCIÓN EN EL SHADER
# ==========================================
func _inject_and_verify(mat: ShaderMaterial, params: Dictionary) -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		
	active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	for param_name in params.keys():
		# Verificación de seguridad: confirmamos que el ShaderMaterial realmente reconozca la propiedad
		var current_val = mat.get_shader_parameter(param_name)
		if current_val == null:
			push_warning("VisualElementModule: El parámetro '", param_name, "' no existe o no está definido en el Shader.")
			continue
			
		var target_val = params[param_name]
		active_tween.tween_property(mat, "shader_parameter/" + param_name, target_val, transition_duration)

func _get_active_shader_material() -> ShaderMaterial:
	if slime.has_node("MassManager"):
		var mass_mgr = slime.get_node("MassManager")
		if mass_mgr.has_method("get_master_shader"):
			return mass_mgr.get_master_shader()
		elif "liquid_mass_mesh" in mass_mgr and is_instance_valid(mass_mgr.liquid_mass_mesh):
			return mass_mgr.liquid_mass_mesh.material_override as ShaderMaterial
	return null
