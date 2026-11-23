shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// 每房与桥板按实际米数铺设错缝地板，接缝和铆钉只影响表面，不改变可行走平面。
uniform vec4 plate_color : source_color;
varying vec2 deck_position;

void vertex() {
	deck_position = VERTEX.xz;
}

void fragment() {
	vec2 scaled = deck_position / vec2(2.5, 1.55);
	scaled.x += mod(floor(scaled.y), 2.0) * 0.5;
	vec2 cell = floor(scaled);
	vec2 uv = fract(scaled);
	vec2 edge = min(uv, 1.0 - uv) * vec2(2.5, 1.55);
	float joint = 1.0 - smoothstep(0.008, 0.026, min(edge.x, edge.y));
	float pins = 1.0 - smoothstep(0.020, 0.032, length(edge - vec2(0.11)));
	float variation = fract(sin(dot(cell, vec2(12.73, 81.97))) * 653.14);
	ALBEDO = plate_color.rgb * (0.92 + 0.13 * variation - 0.19 * joint - 0.12 * pins);
	ROUGHNESS = 0.86;
	SPECULAR = 0.19;
}
