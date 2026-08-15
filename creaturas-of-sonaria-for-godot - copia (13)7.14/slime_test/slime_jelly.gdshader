shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;

// ==========================================
// 🎨 COLOR Y APARIENCIA GELATINOSA
// ==========================================
uniform vec4 base_color : source_color = vec4(0.0, 0.5, 1.0, 0.8);
uniform vec4 element_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float element_blend : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.1;
uniform float fresnel_power : hint_range(0.1, 5.0) = 2.0;

// ==========================================
// 🧅 VARIABLES DE ANDAMIO (CEBOLLETO)
// ==========================================
uniform vec2 scaffold_tilt = vec2(0.0);
uniform float stretch_ratio = 0.0;

// ==========================================
// 🦠 VARIABLES DE DEFORMACIÓN
// ==========================================
uniform vec3 velocity_wobble = vec3(0.0);
uniform float deformation_speed = 3.0;
uniform float deformation_strength = 0.05;
uniform float dynamic_floor_y = -0.55;
uniform float dynamic_ceil_y = 0.55;

// ==========================================
// 🧱 VARIABLES DE CONTACTO DOBLE (Paredes)
// ==========================================
uniform vec3 contact_1 = vec3(0.0);
uniform float weight_1 : hint_range(0.0, 1.0) = 0.0;
uniform vec3 contact_2 = vec3(0.0);
uniform float weight_2 : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	// 0. 🧅 CURVATURA DE PÉNDULO (Debe ir primero)
	// Mapeamos el Y local (-0.5 a 0.5) para que vaya de 0.0 (suelo) a 1.0 (cima)
	float height_factor = clamp(VERTEX.y + 0.5, 0.0, 1.0); 
	
	// Usamos una curva exponencial para que la base se mantenga recta y la punta se doble dramáticamente
	float bend_amount = pow(height_factor, 2.5) * stretch_ratio;
	
	// Desplazamos los ejes X y Z según la inclinación
	VERTEX.x += scaffold_tilt.x * bend_amount;
	VERTEX.z += scaffold_tilt.y * bend_amount;

	// 1. 🔥 SUELO DINÁMICO
	if (VERTEX.y < dynamic_floor_y) {
		float push_up = dynamic_floor_y - VERTEX.y;
		VERTEX.y = dynamic_floor_y;
		VERTEX.x += NORMAL.x * push_up * 1.5;
		VERTEX.z += NORMAL.z * push_up * 1.5;
	}

	// 2. 🔥 TECHO DINÁMICO
	if (VERTEX.y > dynamic_ceil_y) {
		float push_down = VERTEX.y - dynamic_ceil_y;
		VERTEX.y = dynamic_ceil_y;
		VERTEX.x += NORMAL.x * push_down * 1.5;
		VERTEX.z += NORMAL.z * push_down * 1.5;
	}

	// Limites de deformación para las paredes
	float inf_radius = 0.35; 
	float max_push = 0.25; 

	// 3. Pared 1
	if (weight_1 > 0.01) {
		float dist1 = distance(VERTEX, contact_1);
		if (dist1 < inf_radius) {
			float force1 = (inf_radius - dist1) * weight_1;
			VERTEX -= NORMAL * min(force1, max_push);
		}
	}
	
	// 4. Pared 2
	if (weight_2 > 0.01) {
		float dist2 = distance(VERTEX, contact_2);
		if (dist2 < inf_radius) {
			float force2 = (inf_radius - dist2) * weight_2;
			VERTEX -= NORMAL * min(force2, max_push);
		}
	}

	// 5. Inercia y respiración suave
	vec3 movement_deform = velocity_wobble * VERTEX.y * -0.015;
	float wobble = sin(TIME * deformation_speed + VERTEX.y * 5.0) * deformation_strength;
	
	VERTEX += (NORMAL * wobble) + movement_deform;
}

void fragment() {
	vec4 final_color = mix(base_color, element_color, element_blend);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	
	ALBEDO = final_color.rgb;
	ALPHA = final_color.a + (fresnel * 0.5);
	ROUGHNESS = roughness;
	EMISSION = final_color.rgb * fresnel * 0.5;
}