shader_type spatial;
render_mode unshaded, fog_disabled;

uniform vec3 edge_color : source_color = vec3(1.0);
uniform float fresnel_strength : hint_range(0.0, 3.0, 0.1) = 0.5;
uniform float value_esperimental : hint_range(0.0, 100.0, 0.1) = 1.0;

uniform sampler2D screen_texture : hint_screen_texture;
uniform sampler2D normal_texture : hint_normal_roughness_texture;
uniform sampler2D depth_texture : hint_depth_texture;

void vertex() {
	// Lock to view (this is a post-processing shader)
	POSITION = vec4(VERTEX.xy, 0.5, 0.5);
}

void fragment() {
	// Convert the normal texture to a world-space normal
	vec3 norm = (texture(normal_texture, SCREEN_UV)).xyz;
	vec3 view_norm = 2.0 * norm - 1.0;
	vec3 world_norm = normalize((INV_VIEW_MATRIX * vec4(view_norm, 0.0))).xyz;

	// Get world position of the fragment
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	
	vec4 world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec3 world_position = world.xyz / world.w;
	
	// Calculate the direction of each fragment to the camera (view vector)
	vec3 view = normalize(CAMERA_POSITION_WORLD - world_position);
	
	// Now we have all we need to calculate a fresnel filter
	float fresnel = dot(view, world_norm);
	
	// Invert to get the right mix amount 
	fresnel = (value_esperimental - fresnel);
	
	// Apply the strength modifier
	fresnel *= fresnel_strength;
	
	// Now mask with the normal to ensure we are actually applying the effect to an object
	// If we don't have a normal, then it's the background
	float normal_mask = step(0.5, length(norm));
	fresnel = fresnel * normal_mask;
	
	// Mix the initial screen color with the fresnel effect
	vec3 screen_color = texture(screen_texture, SCREEN_UV).rgb;
	ALBEDO = mix(screen_color, edge_color, fresnel);
}
