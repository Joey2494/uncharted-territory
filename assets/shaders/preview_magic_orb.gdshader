shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;

uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform float power : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	float stream_a = sin(UV.y * 31.0 + UV.x * 12.56637 + sin(UV.x * 25.13274 + phase * 2.0) * 1.1 - phase * 4.0);
	float stream_b = sin(UV.x * 37.69911 - UV.y * 17.0 + sin(UV.y * 20.0 - phase * 2.0) * 1.4 + phase * 3.0);
	float threads = max(1.0 - smoothstep(0.035, 0.16, abs(stream_a)), (1.0 - smoothstep(0.025, 0.12, abs(stream_b))) * 0.65);
	float current = 0.5 + 0.5 * sin(UV.y * 18.0 - UV.x * 12.56637 + phase * 4.0);
	vec3 blue = mix(vec3(0.035, 0.18, 0.58), vec3(0.08, 0.42, 1.0), current * 0.55 + rim * 0.35);
	vec3 light_blue = vec3(0.22, 0.65, 1.0);
	ALBEDO = mix(blue, light_blue, threads * 0.65);
	EMISSION = blue * (0.35 + power * 0.25) + light_blue * (threads * 0.9 + rim * 0.5);
	ALPHA = (0.24 + rim * 0.23 + threads * 0.25) * reveal;
}
