shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D reflection_texture : source_color, filter_linear;
uniform float occlusion_alpha = 1.0;
void fragment() {
 vec2 uv = vec2(1.0-SCREEN_UV.x,SCREEN_UV.y);
 vec3 reflected = texture(reflection_texture,uv).rgb;
 float scratch = pow(max(0.0,sin(UV.x*520.0+sin(UV.y*31.0)*0.8)),48.0)*0.045;
 float tarnish = smoothstep(0.25,0.49,abs(UV.x-0.5))*0.22;
 ALBEDO = mix(vec3(0.045,0.11,0.15),reflected*vec3(0.64,0.80,0.90),0.82-tarnish)+scratch;
 EMISSION = vec3(0.018,0.035,0.047);
 ALPHA = occlusion_alpha;
}
