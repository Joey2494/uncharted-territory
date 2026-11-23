shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec2 center;
uniform vec2 radii;
uniform float side = 1.0;
uniform vec2 angles;
uniform vec4 tint : source_color;
uniform bool enabled = false;
varying vec2 ground;

void vertex() {
	ground = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz;
}

void fragment() {
	vec2 p = (ground - center) / radii;
	float angle = atan(side*p.x,-p.y);
	if (!enabled || dot(p,p)>1.0 || side*p.x<0.0 || angle<angles.x || angle>angles.y) {
		discard;
	}
	float rim = smoothstep(0.91,0.985,length(p));
	ALBEDO = tint.rgb;
	ALPHA = min(1.0,tint.a+rim*0.25);
}
