shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;

// ==========================================
// 🎨 COLOR Y APARIENCIA GELATINOSA (Idéntico al Slime)
// ==========================================
uniform vec4 base_color : source_color = vec4(0.0, 0.5, 1.0, 0.8);
uniform vec4 element_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float element_blend : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.1;
uniform float fresnel_power : hint_range(0.1, 5.0) = 2.0;

// ==========================================
// 〰️ VARIABLES DE TENSIÓN (Cuerda)
// ==========================================
uniform float deformation_speed = 8.0;
uniform float deformation_strength = 0.02; // Más sutil que el slime para mantener la forma
uniform float tension_wobble_freq = 15.0;

void vertex() {
	// El brazo es un cilindro. En su espacio local, la longitud va de arriba a abajo (eje Y).
	// Hacemos que vibre como una cuerda tensa moviéndose en X y Z.
	// La deformación es menor en los extremos (donde se une al slime y al nodo) usando una parábola suave.
	
	// Normalizamos el tamaño de 0 a 1 aprox para atenuar las puntas
	float edge_attenuation = 1.0 - abs(VERTEX.y); 
	edge_attenuation = clamp(edge_attenuation, 0.0, 1.0);
	
	float wobble_x = sin(TIME * deformation_speed + VERTEX.y * tension_wobble_freq) * deformation_strength;
	float wobble_z = cos(TIME * deformation_speed + VERTEX.y * tension_wobble_freq) * deformation_strength;
	
	VERTEX.x += wobble_x * edge_attenuation;
	VERTEX.z += wobble_z * edge_attenuation;
}

void fragment() {
	vec4 final_color = mix(base_color, element_color, element_blend);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	
	ALBEDO = final_color.rgb;
	ALPHA = final_color.a + (fresnel * 0.5);
	ROUGHNESS = roughness;
	EMISSION = final_color.rgb * fresnel * 0.5;
}