// Wiggly rainbow tunnel

shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_test_disabled;

uniform sampler2D depth_texture : hint_depth_texture;
uniform vec3 color : source_color = vec3(1.0, 0.0, 0.0);
uniform float intensity = 1.0;
uniform float valua_A : hint_range(0.0, 5.0, 0.1) = 1.0;
uniform float valua_B : hint_range(0.0, 20.0, 0.1) = 1.0;
uniform float valua_C : hint_range(0.0, 1000.0, 0.1) = 1.0;

float F(vec3 o, vec3 d, float t) {
	float a = o.y + TIME * TAU;
	float b = d.y;
	return 0.5 * (t - cos(a + b * t) / b);
}

float ray_integral(vec3 o, vec3 d, float t) {
	return F(o, d, t) - F(o, d, valua_C);
}

varying mat4 inv_modelview_matrix;

void vertex() {
	inv_modelview_matrix = inverse(MODELVIEW_MATRIX);
}

void fragment() {
	vec3 o = inv_modelview_matrix[3].xyz;
	vec3 d = (inv_modelview_matrix * vec4(-VIEW, 0.0)).xyz;
	
	vec3 scene_clip_pos = vec3(SCREEN_UV * 2.0 - 1.0, texture(depth_texture, SCREEN_UV).r);
	vec4 scene_view_pos = INV_PROJECTION_MATRIX * vec4(scene_clip_pos, 1.0);
	scene_view_pos.xyz /= scene_view_pos.w;

	float t = sqrt(min(dot(scene_view_pos.xyz, scene_view_pos.xyz), dot(VERTEX, VERTEX)));
	
	vec3 integral = vec3(
		ray_integral(o, d, t),
		ray_integral(o + vec3(0.0, TAU / 3.0, 0.0), d, t),
		ray_integral(o - vec3(0.0, TAU / 3.0, 0.0), d, t)
	);
	
	integral *= FRONT_FACING ? -valua_A : valua_B;
	
	ALBEDO = integral * intensity;
}