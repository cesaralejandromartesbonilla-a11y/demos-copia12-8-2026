shader_type spatial;

// Array de texturas: Index 0 = Tierra/Roca (Rojo), Index 1 = Pasto (Verde)
uniform sampler2DArray u_texture_array : source_color;
uniform float uv_scale = 0.5;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Usamos coordenadas del mundo para que la textura no se estire al deformar
	vec2 uv = v_world_pos.xz * uv_scale;
	
	// COLOR viene de los datos del Voxel (lo que pintamos con el script)
	// COLOR.r es la intensidad de la Textura 0 (Base/Roca)
	// COLOR.g es la intensidad de la Textura 1 (Pasto)
	
	vec3 texture_0 = texture(u_texture_array, vec3(uv, 0.0)).rgb; // Capa 0
	vec3 texture_1 = texture(u_texture_array, vec3(uv, 1.0)).rgb; // Capa 1
	
	// Mezcla simple: Si COLOR.g es alto, muestra pasto. Si no, muestra roca.
	// Asegúrate de que tus voxeles tengan por defecto color (1,0,0) o (0,1,0)
	vec3 final_albedo = mix(texture_0, texture_1, COLOR.g);
	
	ALBEDO = final_albedo;
	METALLIC = 0.0;
	ROUGHNESS = 1.0;
}