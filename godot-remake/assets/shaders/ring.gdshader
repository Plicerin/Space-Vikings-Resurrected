shader_type canvas_item;
// A glowing ring round a gauge: a thin bright band with a soft halo either side,
// dark and dim when off. The ring is at `radius` of the quad's half-width.
uniform vec4 colour : source_color = vec4(0.35, 0.8, 1.0, 1.0);
uniform float lit : hint_range(0.0, 1.0) = 1.0;
uniform float radius = 0.8;
uniform float thickness = 0.022;

void fragment() {
	float d = length((UV - 0.5) * 2.0);
	float aa = fwidth(d);
	float band = 1.0 - smoothstep(thickness - aa, thickness + aa, abs(d - radius));
	float halo = exp(-abs(d - radius) / 0.05) * 0.5 * lit;
	vec3 on = mix(colour.rgb, vec3(1.0), 0.3);
	vec3 off = vec3(0.22, 0.24, 0.28);
	vec3 rgb = mix(off, on, lit);
	float alpha = max(band * mix(0.8, 1.0, lit), halo);
	COLOR = vec4(mix(rgb, colour.rgb, halo * (1.0 - band)), alpha);
}
