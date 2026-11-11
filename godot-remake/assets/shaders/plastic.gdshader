shader_type canvas_item;
// A moulded dark plastic panel: a rounded slab with a bevelled edge lit from the
// top left, a fine matte grain, and a slow sheen down the face.
uniform vec2 panel_size = vec2(480.0, 120.0);
uniform float corner = 8.0;
uniform float bevel = 4.0;
uniform vec4 base : source_color = vec4(0.085, 0.088, 0.097, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 pos = UV * panel_size;
	vec2 half_size = panel_size * 0.5;
	vec2 q = abs(pos - half_size) - (half_size - vec2(corner));
	float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner; // negative inside
	float mask = 1.0 - smoothstep(-0.5, 0.5, dist);
	float edge = clamp(-dist / bevel, 0.0, 1.0); // 0 on the rim, 1 on the flat face
	// the bevel's slope faces outwards: lit where it faces the top left
	vec2 out_dir = normalize((pos - half_size) + vec2(0.001));
	float facing = dot(out_dir, normalize(vec2(-0.6, -0.8)));
	float bevel_light = (1.0 - edge) * facing * 0.45;
	float sheen = 0.06 * (1.0 - UV.y) + 0.03 * smoothstep(0.0, 1.0, 1.0 - length(UV - vec2(0.25, 0.15)));
	float grain = (hash(floor(pos)) - 0.5) * 0.035;
	vec3 rgb = base.rgb + sheen + grain + bevel_light;
	// a thin dark seam where the bevel meets the face
	rgb *= 1.0 - 0.35 * (1.0 - smoothstep(0.0, 0.08, abs(edge - 0.98)));
	COLOR = vec4(rgb, mask);
}
