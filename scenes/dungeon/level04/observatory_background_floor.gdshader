shader_type spatial;
render_mode diffuse_burley;
#include "res://scenes/dungeon/level04/background_surface.gdshaderinc"
uniform int room_theme = 0;
uniform vec2 room_center = vec2(0.0);
uniform vec2 room_extent = vec2(7.0);
uniform vec2 slab_size = vec2(1.65,1.25);
uniform vec3 stone_tint : source_color = vec3(0.30,0.34,0.36);
uniform vec3 accent_tint : source_color = vec3(0.38,0.30,0.17);
varying vec2 surface_world;
void vertex() { surface_world = (MODEL_MATRIX*vec4(VERTEX,1.0)).xz; }
void fragment() {
	vec2 p = surface_world-room_center;
	vec2 paving = p;
	if (room_theme == 2 || room_theme == 8 || room_theme == 9) {
		paving = vec2(atan(p.y,p.x)*5.5,length(p));
	} else if (room_theme == 10) {
		paving = vec2(p.x+p.y,p.x-p.y)*0.7071;
	}
	vec3 stone = bg_stone(paving,slab_size,stone_tint);
	float oil = bg_noise(p*0.6+vec2(7.4))*bg_noise(p*1.3);
	float scuff = bg_line(sin(p.x*16.0+bg_noise(p*0.24)*5.0),0.02)*smoothstep(0.4,0.8,oil);
	if (room_theme == 1 || room_theme == 6 || room_theme == 9) stone *= 1.0-oil*0.22-scuff*0.07;
	if (room_theme == 11) stone *= 0.84+0.16*bg_noise(p*1.2);
	float engraving = bg_engraving(p,room_theme)*(0.50+0.50*bg_noise(p*2.5));
	stone = mix(stone,accent_tint,engraving*0.60);
	vec2 normalized = p/room_extent;
	float cool_pool = exp(-dot((normalized-vec2(-0.42,-0.62))*vec2(2.7,3.8),(normalized-vec2(-0.42,-0.62))*vec2(2.7,3.8)));
	float warm_pool = exp(-dot((normalized-vec2(0.55,0.13))*vec2(3.3,3.0),(normalized-vec2(0.55,0.13))*vec2(3.3,3.0)));
	float perimeter = smoothstep(0.50,1.05,max(abs(normalized.x),abs(normalized.y)));
	stone *= bg_roof_shadow(p,room_theme)*(1.0-perimeter*0.15);
	stone = mix(stone,stone*vec3(0.85,0.98,1.15),cool_pool*0.65);
	stone = mix(stone,stone*vec3(1.15,1.01,0.81),warm_pool*0.55);
	ALBEDO = stone;
	ROUGHNESS = clamp(0.91+oil*0.08-engraving*0.22,0.66,0.99);
	METALLIC = engraving*0.24;
	SPECULAR = 0.18;
	EMISSION = vec3(0.025,0.062,0.078)*cool_pool*0.12;
}
