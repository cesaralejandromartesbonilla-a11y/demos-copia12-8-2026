//gracias a https://godotshaders.com/shader/another-water-shader/
// esta es una version modificada
shader_type spatial;
// Necesario para que el agua sea transparente
render_mode blend_mix, depth_draw_always;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, repeat_disable, filter_nearest; 

group_uniforms Colores;
uniform float depth_fade_distance : hint_range(0.0, 10.0) = 1.0;
uniform float absorbance : hint_range(0.0, 10.0) = 2.0;
uniform vec3 shallow_color : source_color = vec3(0.22, 0.66, 1.0);
uniform vec3 deep_color : source_color = vec3(0.0, 0.25, 0.45);

group_uniforms Espuma;
uniform float foam_amount : hint_range(0.0, 2.0) = 0.5; // Grosor de la espuma
uniform vec3 foam_color : source_color = vec3(1);
uniform sampler2D foam_noise : repeat_enable; // ¡NUEVO! Textura de ruido para la espuma
uniform float foam_cutoff : hint_range(0.0, 1.0) = 0.5; // Qué tan "rota" se ve la espuma

group_uniforms Superficie;
uniform float roughness : hint_range(0.0, 1.0) = 0.05;
uniform sampler2D wave_texture;
uniform float wave_scale = 4.0;
uniform float height_scale = 0.15;

uniform sampler2D normal1;
uniform vec2 wave_dir1 = vec2(1.0, 0.0);
uniform sampler2D normal2;
uniform vec2 wave_dir2 = vec2(0.0, 1.0);
uniform float wave_speed : hint_range(0.0, 0.2) = 0.015;

varying float wave_height;
varying vec3 uv_world_pos;

vec3 screen(vec3 base, vec3 blend){
	return 1.0 - (1.0 - base) * (1.0 - blend);
}

void vertex() {
	uv_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wave_height = texture(wave_texture, uv_world_pos.xz / wave_scale + TIME * wave_speed).r;
	VERTEX.y += wave_height * height_scale;
}

void fragment() {
	// 1. Cálculo de profundidad
	float depth = texture(DEPTH_TEXTURE, SCREEN_UV, 0.0).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float depth_texture_y = world.y / world.w;
	float vertex_y = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
	float vertical_depth = vertex_y - depth_texture_y;
	
	// 2. Colores base y transparencia
	float depth_fade_blend = exp(-vertical_depth / depth_fade_distance);
	depth_fade_blend = clamp(depth_fade_blend, 0.0, 1.0);
	
	float alpha_blend = -vertical_depth * absorbance;
	alpha_blend = clamp(1.0 - exp(alpha_blend), 0.0, 1.0);
	
	// 3. ¡ESPUMA MEJORADA!
	// Mezclamos la profundidad con un ruido que se mueve
	float noise_speed = TIME * wave_speed;
	float noise_sample = texture(foam_noise, uv_world_pos.xz / (wave_scale * 0.5) + noise_speed).r;
	
	// Esta fórmula hace que la espuma no sea una línea recta
	float foam_mask = clamp(1.0 - (vertical_depth / foam_amount), 0.0, 1.0);
	float combined_foam = step(foam_cutoff, foam_mask * noise_sample);
	
	vec3 foam = combined_foam * foam_color;
	
	// 4. Mezcla final
	vec3 color_out = mix(deep_color, shallow_color, depth_fade_blend);
	color_out = screen(color_out, foam);
	
	// 5. Normal maps para reflejos
	vec2 normal_offset1 = (TIME * wave_dir1) * wave_speed;
	vec2 normal_offset2 = (TIME * wave_dir2) * wave_speed;
	vec3 n1 = texture(normal1, uv_world_pos.xz / wave_scale + normal_offset1).rgb;
	vec3 n2 = texture(normal2, uv_world_pos.xz / wave_scale + normal_offset2).rgb;
	vec3 normal_blend = mix(n1, n2, 0.5);
	
	ALBEDO = color_out;
	ALPHA = alpha_blend;
	ROUGHNESS = roughness;
	NORMAL_MAP = normal_blend;
}