shader_type spatial;
render_mode diffuse_burley;
#include "res://scenes/dungeon/level04/background_surface.gdshaderinc"
uniform bool background_finish = true;
uniform bool bridge_mode = false;
uniform int room_theme = 5;
uniform vec2 room_center = vec2(0.0);
uniform vec2 room_extent = vec2(11.0,7.0);
uniform vec2 slab_size = vec2(1.65,1.25);
uniform vec3 stone_tint : source_color = vec3(0.30,0.34,0.36);
uniform vec3 accent_tint : source_color = vec3(0.38,0.30,0.17);
uniform int segment_count = 1;
uniform vec4 segments[8];
uniform float segment_starts[8];
varying vec2 surface_world;
varying float top_face;
void vertex() {
 surface_world = (MODEL_MATRIX*vec4(VERTEX,1.0)).xz;
 top_face = NORMAL.y;
}
void fragment() {
 vec2 p = surface_world-room_center;
 vec2 paving = p;
 // Target bridge meshes contain all bent segments in level coordinates.
 // Longitudinal texture distance continues across their shared corners.
 if (bridge_mode) {
  float nearest = 1e20;
  for (int index = 0; index < 8; index++) {
   if (index >= segment_count) break;
   vec2 start = segments[index].xy, end = segments[index].zw;
   vec2 delta = end-start;
   float length_squared = max(dot(delta,delta),0.0001);
   float t = clamp(dot(surface_world-start,delta)/length_squared,0.0,1.0);
   vec2 offset = surface_world-(start+delta*t);
   float distance_squared = dot(offset,offset);
   if (distance_squared < nearest) {
    nearest = distance_squared;
    vec2 direction = delta/sqrt(length_squared);
    paving = vec2(dot(offset,vec2(-direction.y,direction.x)),segment_starts[index]+t*sqrt(length_squared));
   }
  }
 }
 vec3 stone;
 float roughness;
 float metallic;
 if (bridge_mode) {
  stone = bg_stone(paving,vec2(1.25,1.8),vec3(0.15,0.20,0.23));
  float trim = bg_line(abs(paving.x)-2.08,0.022);
  stone = mix(stone,vec3(0.26,0.21,0.14),trim*0.58);
  roughness = 0.92-trim*0.16;
  metallic = trim*0.30;
 } else {
  stone = bg_stone(paving,slab_size,stone_tint);
  float oil = bg_noise(p*0.6+vec2(7.4))*bg_noise(p*1.3);
  float engraving = bg_engraving(p,room_theme)*(0.50+0.50*bg_noise(p*2.5));
  stone = mix(stone,accent_tint,engraving*0.60);
  vec2 normalized = p/room_extent;
  float cool_pool = exp(-dot((normalized-vec2(-0.42,-0.62))*vec2(2.7,3.8),(normalized-vec2(-0.42,-0.62))*vec2(2.7,3.8)));
  float warm_pool = exp(-dot((normalized-vec2(0.55,0.13))*vec2(3.3,3.0),(normalized-vec2(0.55,0.13))*vec2(3.3,3.0)));
  float perimeter = smoothstep(0.50,1.05,max(abs(normalized.x),abs(normalized.y)));
  stone *= bg_roof_shadow(p,room_theme)*(1.0-perimeter*0.15);
  stone = mix(stone,stone*vec3(0.85,0.98,1.15),cool_pool*0.65);
  stone = mix(stone,stone*vec3(1.15,1.01,0.81),warm_pool*0.55);
  EMISSION = vec3(0.025,0.062,0.078)*cool_pool*0.12;
  roughness = clamp(0.91+oil*0.08-engraving*0.22,0.66,0.99);
  metallic = engraving*0.24;
 }
 bool lane = bridge_mode ? abs(paving.x)<1.20 : (abs(abs(p.x)-3.8)<0.82 && abs(p.y)<5.15);
 float lengthwise = bridge_mode ? paving.y : p.y;
 bool glass = lane && fract((lengthwise+0.35)/1.7)>0.11 && top_face>0.5;
 ALBEDO = stone;
 ROUGHNESS = roughness;
 METALLIC = metallic;
 SPECULAR = 0.18;
 ALPHA = 1.0;
 if (glass) {
  vec2 optical = bridge_mode ? paving : p;
  float facet = abs(fract((optical.x+optical.y*0.48)*0.9)-0.5);
  float glint = 1.0-smoothstep(0.006,0.023,facet);
  ALBEDO = mix(vec3(0.10,0.25,0.31),vec3(0.48,0.72,0.78),facet*0.6+glint*0.4);
  EMISSION = vec3(0.10,0.29,0.36)*(0.15+glint*0.25);
  ROUGHNESS = 0.16;
  METALLIC = 0.0;
  SPECULAR = 0.70;
  ALPHA = 0.30+glint*0.28;
 }
}
