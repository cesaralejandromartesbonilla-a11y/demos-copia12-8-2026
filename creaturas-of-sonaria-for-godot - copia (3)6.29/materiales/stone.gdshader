shader_type spatial;
render_mode cull_disabled; // Cull disabled permite ver el interior de la cáscara

uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture;
uniform sampler2D normal_texture; // 🔥 NUEVO: Para el relieve exterior
uniform sampler2D noise_texture;
uniform float damage_level : hint_range(0.0, 1.0) = 0.0;

// 🔥 NUEVO: Parámetros para simular el grosor de la pared
uniform vec4 edge_color : source_color = vec4(0.05, 0.05, 0.05, 1.0); // Color del interior roto
uniform float edge_thickness : hint_range(0.0, 0.1) = 0.03; // Qué tan gruesa es la pared

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	float noise = texture(noise_texture, UV).r;
	
	float threshold = damage_level * 0.8;
	
	// 1. Descartar el píxel si está muy roto (Hueco transparente)
	if (noise < threshold) {
		discard;
	}
	
	// 2. Si el píxel está justo en el borde del hueco, lo pintamos como el "grosor"
	if (noise < threshold + edge_thickness) {
		ALBEDO = edge_color.rgb;
		ROUGHNESS = 1.0; // El interior de la piedra rota no brilla
	} 
	// 3. Si es la superficie exterior sana, aplicamos color y normales
	else {
		ALBEDO = tex.rgb * base_color.rgb;
		NORMAL_MAP = texture(normal_texture, UV).rgb;
	}
}