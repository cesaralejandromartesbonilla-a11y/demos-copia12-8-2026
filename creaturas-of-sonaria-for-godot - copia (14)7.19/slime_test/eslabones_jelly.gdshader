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
// 🦠 VARIABLES DE DEFORMACIÓN (Sin Curvatura)
// ==========================================
uniform vec3 velocity_wobble = vec3(0.0);
uniform float deformation_speed = 3.0;
uniform float deformation_strength = 0.05;

void vertex() {
	// 🛑 Eliminamos la curvatura de péndulo, el script de Godot ya mueve los nodos.

	// 1. Inercia y respiración suave unificada
	// Usamos la posición global (NODE_POSITION_WORLD) en lugar de la local.
	// Esto hace que todos los eslabones separados respiren exactamente al mismo tiempo, 
	// ocultando las costuras y uniéndolos como un solo pilar.
	float world_y = NODE_POSITION_WORLD.y + VERTEX.y;
	
	vec3 movement_deform = velocity_wobble * VERTEX.y * -0.015;
	float wobble = sin(TIME * deformation_speed + world_y * 5.0) * deformation_strength;
	
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