shader_type canvas_item;
render_mode unshaded;
void fragment() {
	float vignette = 0.18 + smoothstep(0.3, 0.8, length((UV - 0.5) * vec2(1.0, 0.7))) * 0.25;
	float footer = smoothstep(0.60, 0.96, UV.y) * 0.94;
	float title_band = (1.0 - smoothstep(0.04, 0.17, abs(UV.y - 0.27))) * 0.24;
	COLOR = vec4(0.012, 0.016, 0.019, max(footer, max(vignette, title_band)));
}
