shader_type spatial;
render_mode unshaded;
varying vec2 depth_position;
void vertex() { depth_position = VERTEX.xz; }
void fragment() {
	float radius = length(depth_position);
	float shelves = pow(max(0.0,sin(radius*0.9)),10.0);
	float haze = exp(-radius*0.045);
	ALBEDO = mix(vec3(0.012,0.022,0.030),vec3(0.027,0.055,0.071),haze);
	ALBEDO += vec3(0.008,0.016,0.020)*shelves*haze;
}
