shader_type spatial;
render_mode diffuse_burley;
varying vec2 floor_uv;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void vertex() { floor_uv = VERTEX.xz; }
void fragment() {
 vec2 p = floor_uv / vec2(1.65,1.25);
 p.x += mod(floor(p.y),2.0)*0.5;
 vec2 cell = floor(p);
 vec2 uv = fract(p);
 float seed = hash(cell);
 float seam = 1.0-smoothstep(0.009,0.028,min(min(uv.x,1.0-uv.x),min(uv.y,1.0-uv.y)));
 float grain = hash(floor(floor_uv*90.0));
 float stain = sin(floor_uv.x*0.73+sin(floor_uv.y*1.31))*sin(floor_uv.y*0.52);
 float fracture = abs(uv.y-(uv.x*(seed*0.7-0.35)+0.3+seed*0.3+sin(uv.x*23.0)*0.014));
 float crack = (1.0-smoothstep(0.004,0.011,fracture))*step(0.65,seed);
 vec3 stone = mix(vec3(0.29,0.34,0.36),vec3(0.46,0.47,0.44),seed);
 ALBEDO = stone*(0.91+grain*0.14+stain*0.08)*(1.0-seam*0.35-crack*0.40);
 ROUGHNESS = 0.95;
 SPECULAR = 0.12;
}
