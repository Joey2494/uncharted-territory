shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
void fragment() {
 vec2 p = (UV-vec2(0.5))*2.0;
 float r = length(p);
 if (r>0.97) { discard; }
 float circle = 1.0-smoothstep(0.015,0.035,abs(r-0.76));
 float inner = 1.0-smoothstep(0.012,0.024,abs(r-0.38));
 float crosshair = max(1.0-smoothstep(0.008,0.02,abs(p.x)),1.0-smoothstep(0.008,0.02,abs(p.y)));
 float ticks = step(0.96,cos(atan(p.y,p.x)*24.0))*smoothstep(0.64,0.84,r)*(1.0-smoothstep(0.86,0.9,r));
 ALBEDO = vec3(0.48,0.80,0.97);
 EMISSION = vec3(0.10,0.24,0.34);
 ALPHA = max(max(circle,inner),max(crosshair*0.5,ticks))*0.28;
}
