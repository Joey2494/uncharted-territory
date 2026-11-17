shader_type canvas_item;
render_mode unshaded;
varying vec2 letter_position;
void vertex() {
	letter_position = VERTEX;
}
void fragment() {
	vec4 glyph = texture(TEXTURE, UV) * COLOR;
	float height = clamp(letter_position.y / 85.0, 0.0, 1.0);
	float metal = 0.79 + 0.23 * sin(height * 3.14159);
	float grain = fract(sin(dot(floor(letter_position * 1.8), vec2(127.1, 311.7))) * 43758.5453);
	float glint = pow(max(0.0, sin(letter_position.x * 0.009 - TIME * 0.16)), 18.0) * 0.12;
	glyph.rgb *= metal + (grain - 0.5) * 0.035 + glint;
	COLOR = glyph;
}
