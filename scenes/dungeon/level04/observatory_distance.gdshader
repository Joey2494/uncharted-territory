shader_type sky;
// Infinitely distant architecture and haze. No scene meshes or screen overlay.
float sky_hash(vec2 p) { return fract(sin(dot(p,vec2(53.7,179.1)))*4375.83); }
void sky() {
	vec3 direction = normalize(EYEDIR);
	float azimuth = atan(direction.x,direction.z);
	float height = direction.y;
	float bay = fract(azimuth*5.09296+0.5);
	float rib = 1.0-smoothstep(0.018,0.055,min(bay,1.0-bay));
	float arch_curve = sqrt(max(0.0,1.0-pow((bay-0.5)*2.0,2.0)));
	float vault = 1.0-smoothstep(0.006,0.028,abs(height-(arch_curve*0.22-0.08)));
	float terrace = (1.0-smoothstep(0.007,0.024,abs(height+0.32)))+(1.0-smoothstep(0.006,0.018,abs(height+0.61)))*0.5;
	float mist = exp(-pow((height+0.38)*2.7,2.0));
	vec3 base = mix(vec3(0.012,0.022,0.032),vec3(0.027,0.050,0.066),mist);
	base *= 1.0-rib*0.25-vault*0.12;
	base += vec3(0.012,0.024,0.030)*terrace;
	float slits = (1.0-smoothstep(0.003,0.009,abs(bay-0.17)))*smoothstep(-0.75,-0.60,height)*(1.0-smoothstep(-0.45,-0.30,height));
	base += vec3(0.016,0.044,0.060)*slits;
	float aged = sky_hash(floor(vec2(azimuth*150.0,height*100.0)));
	COLOR = base*(0.97+aged*0.06);
}
