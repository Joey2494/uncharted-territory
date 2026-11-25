shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float film_opacity = 0.24;
void fragment() {
 vec2 frame = vec2(UV.x,fract(UV.y*3.0));
 float border = step(frame.x,0.10)+step(0.90,frame.x)+step(frame.y,0.07)+step(0.93,frame.y);
 float perforation = step(abs(UV.x-0.045),0.022)+step(abs(UV.x-0.955),0.022);
 perforation *= step(abs(fract(UV.y*18.0)-0.5),0.20);
 vec2 p = (frame-vec2(0.5))*vec2(1.0,1.30);
 float lens = 1.0-smoothstep(0.006,0.017,abs(length(p)-0.23));
 float trace = (1.0-smoothstep(0.006,0.015,abs(p.y)))*step(abs(p.x),0.31);
 ALBEDO = mix(vec3(0.10,0.19,0.24),vec3(0.38,0.54,0.60),max(lens,trace)*0.5);
 ALPHA = (film_opacity+min(1.0,border)*0.10+lens*0.04)*(1.0-min(1.0,perforation));
}
