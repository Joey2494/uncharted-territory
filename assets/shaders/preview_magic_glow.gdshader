shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float spark : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 point = UV * 2.0 - 1.0;
	float radius = length(point);
	float soft = pow(max(0.0, 1.0 - radius), 3.0);
	float core = exp(-dot(point, point) * 30.0);
	vec3 blue = mix(vec3(0.025, 0.18, 0.65), vec3(0.16, 0.58, 1.0), spark);
	ALBEDO = blue + vec3(0.3, 0.35, 0.4) * core * spark;
	ALPHA = (soft * mix(0.27, 0.75, spark) + core * spark * 0.6) * strength;
}
