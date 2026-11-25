shader_type spatial;
render_mode diffuse_burley;
#include "res://scenes/dungeon/level04/background_surface.gdshaderinc"
uniform int segment_count = 1;
uniform vec4 segments[8];
uniform float segment_starts[8];
varying vec2 floor_point;
void vertex() { floor_point = VERTEX.xz; }
void fragment() {
	float nearest = 1e20;
	vec2 paving = vec2(0.0);
	for (int index = 0; index < 8; index++) {
		if (index >= segment_count) break;
		vec2 start = segments[index].xy, end = segments[index].zw;
		vec2 delta = end-start;
		float length_squared = max(dot(delta,delta),0.0001);
		float t = clamp(dot(floor_point-start,delta)/length_squared,0.0,1.0);
		vec2 offset = floor_point-(start+delta*t);
		float distance_squared = dot(offset,offset);
		if (distance_squared < nearest) {
			nearest = distance_squared;
			vec2 direction = delta/sqrt(length_squared);
			paving = vec2(dot(offset,vec2(-direction.y,direction.x)),segment_starts[index]+t*sqrt(length_squared));
		}
	}
	vec3 stone = bg_stone(paving,vec2(1.25,1.8),vec3(0.15,0.20,0.23));
	float trim = bg_line(abs(paving.x)-2.08,0.022);
	ALBEDO = mix(stone,vec3(0.26,0.21,0.14),trim*0.58);
	ROUGHNESS = 0.92-trim*0.16;
	METALLIC = trim*0.30;
	SPECULAR = 0.18;
}
