shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec2 p = UV - vec2(0.5, 0.30);
	p.x *= 1.6;
	float radius = length(p);
	float halo = exp(-radius * 7.0) * 0.15;
	float rays = pow(max(0.0, sin(atan(p.y, p.x) * 14.0 + TIME * 0.09)), 12.0);
	float beam = rays * exp(-radius * 5.0) * smoothstep(0.10, 0.24, radius) * 0.18;
	COLOR = vec4(0.88, 0.64, 0.24, halo + beam);
}
