// Versión simple: un solo punto de contacto (RuedaFisica ya lo expone).
// El multi-muestreo para neumáticos de baja presión queda afuera a propósito
// por ahora — ver la hoja de ruta, Paso 1.1.6.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 color_base : source_color = vec4(0.05, 0.05, 0.05, 1.0);
uniform float rugosidad : hint_range(0.0, 1.0) = 0.9;
uniform float metalico : hint_range(0.0, 1.0) = 0.0;

uniform vec3 punto_contacto_mundo;
uniform float profundidad_contacto;
uniform float radio_influencia = 0.15;

void vertex() {
	vec3 vertice_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float distancia = length(vertice_mundo - punto_contacto_mundo);

	float t = clamp(distancia / radio_influencia, 0.0, 1.0);
	float influencia = 1.0 - smoothstep(0.0, 1.0, t);

	VERTEX -= NORMAL * profundidad_contacto * influencia;
}

void fragment() {
	ALBEDO = color_base.rgb;
	ROUGHNESS = rugosidad;
	METALLIC = metalico;
}
