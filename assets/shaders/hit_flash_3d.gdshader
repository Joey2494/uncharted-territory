shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled;

uniform vec4 flash_color : source_color = vec4(0.78, 0.12, 0.08, 0.9);

void fragment() {
	ALBEDO = flash_color.rgb;
	EMISSION = flash_color.rgb * 0.18;
	ALPHA = flash_color.a;
}
