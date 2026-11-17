shader_type canvas_item;
render_mode unshaded;
uniform float remaining : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 p = UV - vec2(0.5);
	float angle = fract(atan(p.x, -p.y) / 6.2831853 + 1.0);
	float disc = 1.0 - smoothstep(0.46, 0.49, length(p));
	COLOR = vec4(0.015, 0.02, 0.02, step(angle, remaining) * disc * 0.78);
}
