shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;

// ==========================================
// 🌊 1. COLOR EXTERIOR (Líquido Base)
// ==========================================
uniform vec4 base_color : source_color = vec4(0.0, 0.5, 1.0, 0.5);
uniform vec4 element_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float element_blend : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.1;
uniform float fresnel_power : hint_range(0.1, 5.0) = 2.0;
uniform float parallax_depth : hint_range(0.0, 1.0) = 0.35; // Profundidad de la ilusión 3D

// ==========================================
// 🌫️ 2. CAPA DE TINTA (Manchas disueltas)
// ==========================================
uniform vec4 ink_color : source_color = vec4(0.0, 0.3, 0.8, 1.0);
uniform float ink_density : hint_range(0.0, 1.0) = 0.2; 
uniform float ink_scale = 4.0;
uniform float ink_flow_speed = 0.25;

// ==========================================
// 🔴 3. CAPA DE ORBES (Canicas sólidas)
// ==========================================
uniform vec4 orb_color : source_color = vec4(1.0, 0.0, 0.2, 1.0); 
uniform float orb_size : hint_range(0.0, 0.5) = 0.0; // Ponlo en >0 para ver los orbes
uniform float orb_grid_scale = 3.0; 
uniform float orb_float_speed = 0.6; 

// ==========================================
// 🧅 VARIABLES DE DEFORMACIÓN FÍSICA (INTACTAS)
// ==========================================
uniform vec2 scaffold_tilt = vec2(0.0);
uniform float stretch_ratio = 0.0;
uniform vec3 velocity_wobble = vec3(0.0);
uniform float deformation_speed = 3.0;
uniform float deformation_strength = 0.05;
uniform float dynamic_floor_y = -0.55;
uniform float dynamic_ceil_y = 0.55;
uniform vec3 contact_1 = vec3(0.0);
uniform float weight_1 : hint_range(0.0, 1.0) = 0.0;
uniform vec3 contact_2 = vec3(0.0);
uniform float weight_2 : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_local_pos;

// ==========================================
// 🧮 FUNCIONES MATEMÁTICAS 3D
// ==========================================
vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

// Ruido para las manchas de tinta
float cellular_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float min_dist = 1.0;
	for(int x = -1; x <= 1; x++) {
		for(int y = -1; y <= 1; y++) {
			for(int z = -1; z <= 1; z++) {
				vec3 neighbor = vec3(float(x), float(y), float(z));
				vec3 point = hash33(i + neighbor);
				vec3 diff = neighbor + point - f;
				min_dist = min(min_dist, length(diff));
			}
		}
	}
	return min_dist;
}

// ==========================================
// 📐 VÉRTICE (FÍSICAS)
// ==========================================
void vertex() {
	float height_factor = clamp(VERTEX.y + 0.5, 0.0, 1.0); 
	float bend_amount = pow(height_factor, 2.5) * stretch_ratio; 
	VERTEX.x += scaffold_tilt.x * bend_amount; 
	VERTEX.z += scaffold_tilt.y * bend_amount; 

	if (VERTEX.y < dynamic_floor_y) { 
		float push_up = dynamic_floor_y - VERTEX.y; 
		VERTEX.y = dynamic_floor_y; 
		VERTEX.x += NORMAL.x * push_up * 1.5; 
		VERTEX.z += NORMAL.z * push_up * 1.5; 
	} 

	if (VERTEX.y > dynamic_ceil_y) { 
		float push_down = VERTEX.y - dynamic_ceil_y; 
		VERTEX.y = dynamic_ceil_y; 
		VERTEX.x += NORMAL.x * push_down * 1.5; 
		VERTEX.z += NORMAL.z * push_down * 1.5; 
	} 

	float inf_radius = 0.35; 
	float max_push = 0.25; 

	if (weight_1 > 0.01) { 
		float dist1 = distance(VERTEX, contact_1); 
		if (dist1 < inf_radius) { 
			float force1 = (inf_radius - dist1) * weight_1; 
			VERTEX -= NORMAL * min(force1, max_push); 
		} 
	} 
	
	if (weight_2 > 0.01) { 
		float dist2 = distance(VERTEX, contact_2); 
		if (dist2 < inf_radius) { 
			float force2 = (inf_radius - dist2) * weight_2; 
			VERTEX -= NORMAL * min(force2, max_push); 
		} 
	} 

	vec3 movement_deform = velocity_wobble * VERTEX.y * -0.015; 
	float wobble = sin(TIME * deformation_speed + VERTEX.y * 5.0) * deformation_strength; 
	VERTEX += (NORMAL * wobble) + movement_deform; 
	
	v_local_pos = VERTEX;
}

// ==========================================
// 🎨 FRAGMENTO (VISUALES EN CAPAS)
// ==========================================
void fragment() {
	vec4 outer_color = mix(base_color, element_color, element_blend);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	
	// --- 1. CÁLCULO DE PARALLAX (VISIÓN INTERNA) ---
	vec3 cam_pos_local = (inverse(MODEL_MATRIX) * INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 ray_dir = normalize(v_local_pos - cam_pos_local);
	vec3 internal_pos = v_local_pos + (ray_dir * parallax_depth);
	
	// --- 2. CAPA: TINTA/IMPUREZAS (Suave) ---
	vec3 ink_pos = internal_pos + vec3(0.0, TIME * ink_flow_speed, TIME * (ink_flow_speed * 0.5));
	float ink_noise = cellular_noise(ink_pos * ink_scale);
	float ink_shape = 1.0 - ink_noise;
	float ink_thresh = 1.0 - ink_density;
	// smoothstep amplio para bordes difuminados
	float ink_mask = smoothstep(ink_thresh, ink_thresh + 0.15, ink_shape); 
	
	// --- 3. CAPA: ORBES/CANICAS (Sólido y Brillante) ---
	vec3 orb_pos = internal_pos * orb_grid_scale;
	orb_pos.y -= TIME * orb_float_speed;
	
	vec3 i = floor(orb_pos);
	vec3 f = fract(orb_pos);
	float min_dist = 1.0;
	vec3 orb_normal_raw = vec3(0.0);
	
	for(int x = -1; x <= 1; x++) {
		for(int y = -1; y <= 1; y++) {
			for(int z = -1; z <= 1; z++) {
				vec3 neighbor = vec3(float(x), float(y), float(z));
				vec3 point_offset = sin(TIME * 1.5 + hash33(i + neighbor) * 6.28) * 0.15 + 0.5;
				vec3 cell_center = neighbor + point_offset;
				vec3 diff = cell_center - f;
				float dist = length(diff);
				if (dist < min_dist) {
					min_dist = dist;
					orb_normal_raw = -diff; 
				}
			}
		}
	}
	// smoothstep cerrado para bordes duros y definidos
	float orb_mask = smoothstep(orb_size + 0.01, orb_size, min_dist);
	
	vec3 orb_normal = normalize(orb_normal_raw);
	vec3 fake_light_dir = normalize(vec3(0.5, 1.0, 0.5));
	float diffuse = max(dot(orb_normal, fake_light_dir), 0.0);
	float specular = pow(max(dot(orb_normal, normalize(fake_light_dir + VIEW)), 0.0), 32.0); 
	vec3 shaded_orb_color = (orb_color.rgb * (0.3 + diffuse * 0.7)) + (vec3(1.0) * specular * 0.8);

	// --- 4. MEZCLA FINAL (COMPOSICIÓN) ---
	// Empezamos con el líquido base
	vec3 final_rgb = outer_color.rgb;
	float final_alpha = outer_color.a;
	
	// Añadimos la tinta por encima
	final_rgb = mix(final_rgb, ink_color.rgb, ink_mask * ink_color.a);
	final_alpha = final_alpha + (ink_mask * ink_color.a);
	
	// Añadimos los orbes sólidos por encima de todo
	final_rgb = mix(final_rgb, shaded_orb_color, orb_mask * orb_color.a);
	final_alpha = mix(final_alpha, orb_color.a, orb_mask * orb_color.a); // Los orbes reemplazan el alpha
	
	// --- RESULTADO ---
	ALBEDO = final_rgb;
	ALPHA = clamp(final_alpha + (fresnel * 0.5), 0.0, 1.0);
	ROUGHNESS = roughness;
	
	// El fresnel ilumina el borde, la tinta brilla un poco, los orbes no emiten luz propia (solo reflejan)
	EMISSION = (outer_color.rgb * fresnel * 0.5) + (ink_color.rgb * ink_mask * 0.15);
}