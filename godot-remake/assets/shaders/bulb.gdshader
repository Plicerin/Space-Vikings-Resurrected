shader_type canvas_item;
// A frosted LED bulb in a metal seat, resolution-independent: the quad is 1.7 bulb
// radii on a side from the middle, the bulb is the unit circle in it.
uniform vec4 colour : source_color = vec4(0.1, 0.95, 0.3, 1.0);
uniform float lit : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 * 1.7;
	float d = length(p);
	float aa = fwidth(d);
	float body_mask = 1.0 - smoothstep(0.98 - aa, 0.98 + aa, d);
	float seat_mask = smoothstep(0.98 - aa, 0.98 + aa, d) * (1.0 - smoothstep(1.16 - aa, 1.16 + aa, d));
	float z = sqrt(max(1.0 - d * d, 0.0));
	vec3 n = normalize(vec3(p, z));
	vec3 light = normalize(vec3(-0.4, -0.5, 0.75));
	float diffuse = max(dot(n, light), 0.0);
	// translucent plastic: brightest through the middle, deeper colour at the edge
	float core = pow(z, 1.4);
	vec3 on = mix(colour.rgb * 0.5, mix(colour.rgb, vec3(1.0), 0.5), core);
	on += colour.rgb * pow(1.0 - z, 2.0) * 0.2; // light scattered in the frosted skin
	vec3 off = colour.rgb * (0.10 + 0.10 * diffuse) + vec3(0.03); // dark, milky
	vec3 body = mix(off, on, lit);
	float spec = pow(max(dot(reflect(-light, n), vec3(0.0, 0.0, 1.0)), 0.0), 16.0);
	body += vec3(1.0) * spec * (0.18 + 0.2 * lit);
	vec3 seat = vec3(0.34, 0.36, 0.40) * (0.65 + 0.35 * (0.5 - p.y * 0.4));
	float halo = lit * 0.45 * pow(clamp(1.0 - (d - 1.0) / 0.7, 0.0, 1.0), 2.0) * (1.0 - body_mask) * (1.0 - seat_mask);
	vec3 rgb = body * body_mask + seat * seat_mask * (1.0 - body_mask) + colour.rgb * halo;
	float alpha = max(max(body_mask, seat_mask), halo);
	COLOR = vec4(rgb, alpha);
}
