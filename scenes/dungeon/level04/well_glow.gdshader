shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float opacity = 0.16;
void fragment() {
 float radial = 1.0-smoothstep(0.05,0.5,length(UV-vec2(0.5)));
 ALBEDO = vec3(0.12,0.38,0.65);
 EMISSION = vec3(0.12,0.35,0.58)*radial*0.22;
 ALPHA = radial*radial*opacity;
}
