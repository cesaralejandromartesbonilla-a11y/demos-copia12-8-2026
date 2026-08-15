shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_test_disabled;

uniform sampler2D depth_texture : hint_depth_texture;
uniform vec3 color : source_color = vec3(1.0, 0.0, 0.0);
uniform float density = 1.0;
uniform float valua_A : hint_range(0.0, 10.0, 0.1) = 1.0;
uniform float valua_B : hint_range(0.0, 10.0, 0.1) = 1.0;

void fragment() {
	// Distance to mesh surface
	float dist = length(VERTEX);
	
	// Distance to scene geometry
	vec3 scene_clip_pos = vec3(SCREEN_UV * 2.0 - 1.0, texture(depth_texture, SCREEN_UV).r);
	vec4 scene_view_pos = INV_PROJECTION_MATRIX * vec4(scene_clip_pos, 1.0);
	scene_view_pos.xyz /= scene_view_pos.w;
	float scene_dist = length(scene_view_pos.xyz);
	
	dist = min(dist, scene_dist);
	
	// Add density on back faces, subtract on front faces
	dist *= FRONT_FACING ? -valua_A : valua_B;
	
    ALBEDO = dist * color * density;
}