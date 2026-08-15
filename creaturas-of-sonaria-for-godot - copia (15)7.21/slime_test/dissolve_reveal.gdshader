shader_type spatial;
render_mode blend_mix, cull_back;

// ==========================================
// 🌊 DISOLUCIÓN — transición slime → forma asimilada
// ==========================================
// reveal_progress va de 0 (invisible/disuelto) a 1 (totalmente revelado).
// FormController lo anima con un Tween. Al llegar a 1, FormController
// cambia material_override al material real del objeto — este shader
// es solo para el instante de la transición.

uniform vec4 base_color : source_color = vec4(0.85, 0.85, 0.9, 1.0);
uniform vec4 edge_color : source_color = vec4(0.2, 0.6, 1.0, 1.0); // mismo azul que el líquido base
uniform float edge_width : hint_range(0.0, 0.3) = 0.08;
uniform float reveal_progress : hint_range(0.0, 1.0) = 0.0;
uniform float noise_scale : hint_range(1.0, 20.0) = 6.0;

varying vec3 model_vertex;

void vertex() {
	model_vertex = VERTEX; // posición en espacio de objeto, estable frame a frame
}

// Ruido simple basado en hash — no necesita textura externa.
float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash3(i);
	float b = hash3(i + vec3(1.0, 0.0, 0.0));
	float c = hash3(i + vec3(0.0, 1.0, 0.0));
	float d = hash3(i + vec3(1.0, 1.0, 0.0));
	float e = hash3(i + vec3(0.0, 0.0, 1.0));
	float f2 = hash3(i + vec3(1.0, 0.0, 1.0));
	float g = hash3(i + vec3(0.0, 1.0, 1.0));
	float h = hash3(i + vec3(1.0, 1.0, 1.0));
	float xy1 = mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
	float xy2 = mix(mix(e, f2, f.x), mix(g, h, f.x), f.y);
	return mix(xy1, xy2, f.z);
}

void fragment() {
	float n = value_noise(model_vertex * noise_scale);

	// Franja iluminada justo en el borde de la disolución
	float edge = smoothstep(reveal_progress - edge_width, reveal_progress, n)
	           - smoothstep(reveal_progress, reveal_progress + edge_width, n);

	ALBEDO = base_color.rgb;
	EMISSION = edge_color.rgb * edge * 4.0;

	if (n > reveal_progress) {
		discard; // todavía no "materializado" en este punto de la malla
	}
}
