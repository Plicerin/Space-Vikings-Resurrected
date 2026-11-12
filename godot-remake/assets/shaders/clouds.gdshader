shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// A layer of cloud: soft patches drifting on the wind, white where the sun
// is on them and grey underneath, faded out with distance so that its edge
// is not seen, and thinning as the eye comes to its height.

uniform float seed = 1.0;
uniform float coverage = 0.52;
uniform vec3 sun_direction = vec3(0.6, 0.25, -0.75);
uniform float layer_height = 2200.0;

varying vec3 world;

float hash(vec2 p) {
	p = fract(p * vec2(0.3183099, 0.3678794) + seed * 0.211);
	p *= 17.0;
	return fract(p.x * p.y * (p.x + p.y));
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	return value_noise(p) * 0.5 + value_noise(p * 2.1 + 3.0) * 0.28 + value_noise(p * 4.3 + 7.0) * 0.14 + value_noise(p * 8.7 + 1.0) * 0.08;
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec2 drift = vec2(TIME * 14.0, TIME * 6.0);
	vec2 p = (world.xz + drift) * 0.00045;
	float density = fbm(p);
	float cloud = smoothstep(coverage, coverage + 0.2, density);
	float dist = distance(world.xz, cam.xz);
	float far_fade = 1.0 - smoothstep(14000.0, 34000.0, dist);
	float height_above = cam.y - layer_height;
	float near_fade = smoothstep(0.0, 120.0, abs(height_above)); // inside the layer it thins out
	// lit from above, grey from below, brightest on the thick middle of a patch
	float top = height_above > 0.0 ? 1.0 : 0.0;
	float sun = clamp(dot(vec3(0.0, 1.0, 0.0), normalize(sun_direction)) * 0.5 + 0.6, 0.4, 1.0);
	float thick = smoothstep(coverage + 0.05, coverage + 0.35, density);
	vec3 colour = mix(vec3(0.58, 0.62, 0.70), vec3(1.0, 1.0, 1.0), top * sun) * (0.85 + 0.15 * thick);
	ALBEDO = colour;
	ALPHA = cloud * far_fade * near_fade * 0.92;
}
