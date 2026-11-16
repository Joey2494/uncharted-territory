shader_type canvas_item;
render_mode unshaded;

void fragment() {
	float left_shade = 1.0 - smoothstep(0.28, 0.69, UV.x);
	float edges = smoothstep(0.26, 0.72, distance(UV, vec2(0.65, 0.45)));
	float vertical = pow(abs(UV.y - 0.5) * 2.0, 3.0) * 0.62;
	float scene_shade = 0.10 * smoothstep(0.35, 0.80, UV.x);
	COLOR = vec4(vec3(0.023, 0.028, 0.027), max(scene_shade, max(left_shade * 0.98, max(edges * 0.68, vertical))));
}
