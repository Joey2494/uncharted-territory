shader_type canvas_item;
render_mode unshaded;

uniform vec4 stone_shadow : source_color = vec4(0.065, 0.070, 0.062, 1.0);
uniform vec4 stone_light : source_color = vec4(0.145, 0.145, 0.124, 1.0);
uniform float grain_strength : hint_range(0.0, 0.1) = 0.022;
varying vec2 panel_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), u.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	panel_position = VERTEX;
}

void fragment() {
	vec2 p = panel_position;
	float coarse = noise(p * 0.027);
	float detail = noise(p * 0.13);
	float grain = hash(floor(p * 1.7));
	float pits = pow(noise(p * 0.23), 5.0);
	float seam = 1.0 - smoothstep(0.0, 0.017, abs(noise(p * 0.032 + vec2(7.0, 19.0)) - 0.51));
	vec3 stone = mix(stone_shadow.rgb, stone_light.rgb, coarse * 0.68 + detail * 0.22);
	stone += (grain - 0.5) * grain_strength;
	stone *= 1.0 - pits * 0.17 - seam * 0.08;
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	stone *= mix(0.64, 1.0, smoothstep(0.0, 0.055, edge));
	COLOR = vec4(stone, 1.0);
}
