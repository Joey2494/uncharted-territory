// Shared surface weathering only: no displacement, animation or gameplay masks.
float bg_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float bg_noise(vec2 p) {
	vec2 cell = floor(p), f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(bg_hash(cell),bg_hash(cell+vec2(1,0)),f.x),mix(bg_hash(cell+vec2(0,1)),bg_hash(cell+vec2(1)),f.x),f.y);
}
float bg_line(float value, float width) { return 1.0-smoothstep(width,width+0.014,abs(value)); }
vec3 bg_stone(vec2 p, vec2 slab_size, vec3 tint) {
	vec2 q = p/slab_size;
	q.x += mod(floor(q.y),2.0)*0.5;
	vec2 cell = floor(q), uv = fract(q);
	vec2 edge = min(uv,1.0-uv)*slab_size;
	float seam = 1.0-smoothstep(0.008,0.036,min(edge.x,edge.y));
	float seed = bg_hash(cell);
	float grain = bg_noise(p*73.0);
	float erosion = bg_noise(p*1.9)*0.65+bg_noise(p*0.33)*0.35;
	float crack_path = uv.y-(0.24+seed*0.44+(uv.x-0.5)*(seed-0.5)*0.5+sin(uv.x*19.0+seed*7.0)*0.012);
	float crack = bg_line(crack_path,0.0025)*step(0.59,seed);
	float chipped_edge = seam*(0.6+0.4*bg_noise(p*20.0));
	return tint*(0.81+0.27*seed+0.10*grain+0.13*erosion)*(1.0-chipped_edge*0.36-crack*0.32);
}
// These are quiet architectural engravings, unrelated to optical puzzle clues.
float bg_engraving(vec2 p, int theme) {
	float r = length(p), angle = atan(p.y,p.x);
	float design = 0.0;
	if (theme == 0) {
		design = max(bg_line(r-2.60,0.016),bg_line(r-2.76,0.009));
		design = max(design,bg_line(sin(angle*16.0)*r,0.018)*step(2.48,r)*step(r,2.68));
	} else if (theme == 1) {
		design = bg_line(abs(p.x)-7.4,0.018)*step(abs(p.y),6.5);
		design = max(design,bg_line(mod(p.y+1.6,3.2)-1.6,0.018)*step(6.2,abs(p.x)));
	} else if (theme == 2) {
		design = max(bg_line(r-4.15,0.016),bg_line(r-4.36,0.009));
		design = max(design,bg_line(sin(angle*24.0)*r,0.012)*step(3.98,r)*step(r,4.22));
	} else if (theme == 3) {
		design = bg_line(abs(p.x+1.0)-3.35,0.02)*step(abs(p.y),5.6);
	} else if (theme == 4) {
		design = bg_line(mod(p.x+1.5,3.0)-1.5,0.012)*step(3.3,abs(p.y));
		design = max(design,bg_line(abs(p.y)-4.9,0.02)*step(abs(p.x),6.2));
	} else if (theme == 5) {
		design = bg_line(abs(p.x)-8.1,0.018)*step(abs(p.y),4.8);
	} else if (theme == 6) {
		design = bg_line(abs(p.x)-4.7,0.018)*step(abs(p.y),5.0);
		design = max(design,bg_line(mod(p.y+0.9,1.8)-0.9,0.012)*step(4.4,abs(p.x))*step(abs(p.x),5.0));
	} else if (theme == 7) {
		design = bg_line(mod(p.y+0.7,1.4)-0.7,0.014)*step(6.8,abs(p.x));
	} else if (theme == 8) {
		design = max(bg_line(r-7.75,0.018),bg_line(r-8.0,0.009));
		design = max(design,bg_line(sin(angle*12.0)*r,0.016)*step(7.4,r)*step(r,8.1));
	} else if (theme == 9) {
		design = bg_line(r-3.15,0.025)+bg_line(r-3.40,0.012);
	} else if (theme == 10) {
		vec2 q = vec2(p.x+p.y,p.x-p.y)*0.7071;
		design = max(bg_line(abs(q.x)-5.7,0.015),bg_line(abs(q.y)-5.7,0.015));
	} else {
		design = bg_line(abs(p.x)-5.25,0.012)*step(abs(p.y),5.4);
	}
	return min(design,1.0);
}
// Static, low contrast ceiling rib and light-well projections; nothing crosses
// the camera as geometry, and H/I warning overlays continue to render on top.
float bg_roof_shadow(vec2 p, int theme) {
	float field;
	if (theme == 0 || theme == 2 || theme == 8 || theme == 9) {
		field = abs(sin(atan(p.y,p.x)*float(theme == 8 ? 10 : 6)))*length(p);
	} else if (theme == 10 || theme == 5) {
		field = abs(mod(p.x*0.65+p.y*0.9+1.7,3.4)-1.7);
	} else {
		field = abs(mod(p.x*0.17+p.y+1.8,3.6)-1.8);
	}
	return 0.86+0.14*smoothstep(0.10,0.46,field);
}
