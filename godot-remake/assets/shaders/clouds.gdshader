shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// A layer of cloud, a shell round the planet: soft patches drifting on the wind, white where the
// sun is on them and grey underneath, faded out with distance so that its edge is not seen, and
// thinning as the eye comes to its height.

uniform float seed = 1.0;
uniform float coverage = 0.52;
uniform vec3 sun_direction = vec3(0.6, 0.25, -0.75);
uniform float world_scale = 3.0; // the scene's units to one of the ground's
uniform float planet_radius = 450000.0; // in the ground's units

varying vec3 world;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3) + seed * 0.211);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

float fbm(vec3 p) {
	return value_noise3(p) * 0.5 + value_noise3(p * 2.1 + 3.0) * 0.28 + value_noise3(p * 4.3 + 7.0) * 0.14 + value_noise3(p * 8.7 + 1.0) * 0.08;
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 n = normalize(world);
	vec3 drift = vec3(TIME * 14.0, TIME * 6.0, TIME * 9.0) / planet_radius;
	vec3 p = (n + drift) * planet_radius * 0.00045;
	float density = fbm(p);
	float cloud = smoothstep(coverage, coverage + 0.2, density);
	float dist = distance(world, cam) / world_scale;
	float far_fade = 1.0 - smoothstep(14000.0, 34000.0, dist);
	float height_above = (length(cam) - length(world)) / world_scale;
	float near_fade = smoothstep(0.0, 120.0, abs(height_above)); // inside the layer it thins out
	// lit from above, grey from below, brightest on the thick middle of a patch
	float top = height_above > 0.0 ? 1.0 : 0.0;
	float sun = clamp(dot(n, normalize(sun_direction)) * 0.5 + 0.6, 0.4, 1.0);
	float thick = smoothstep(coverage + 0.05, coverage + 0.35, density);
	vec3 colour = mix(vec3(0.58, 0.62, 0.70), vec3(1.0, 1.0, 1.0), top * sun) * (0.85 + 0.15 * thick);
	ALBEDO = colour;
	ALPHA = cloud * far_fade * near_fade * 0.92;
}
