shader_type spatial;
// The ground of a planet from the air: land and sea from noise on the
// map, the way the planet's own surface is, and a haze towards the edge.

uniform vec3 land_color : source_color = vec3(0.28, 0.40, 0.22);
uniform vec3 dry_color : source_color = vec3(0.55, 0.40, 0.25);
uniform vec3 sea_color : source_color = vec3(0.08, 0.22, 0.45);
uniform vec3 haze_color : source_color = vec3(0.55, 0.70, 0.90);
uniform float tech = 2.0;
uniform float seed = 1.0;
uniform float scale = 0.00018;

varying vec3 world;

float hash(vec2 p) {
	p = fract(p * vec2(0.3183099, 0.3678794) + seed * 0.137);
	p *= 17.0;
	return fract(p.x * p.y * (p.x + p.y));
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world.xz * scale;
	float h = value_noise(p * 3.0 + seed) * 0.6 + value_noise(p * 9.0) * 0.3 + value_noise(p * 31.0) * 0.1;
	float land = smoothstep(0.47, 0.5, h);
	vec3 ground = mix(land_color, dry_color, smoothstep(0.55, 0.75, value_noise(p * 5.0 + 4.0)));
	ALBEDO = mix(sea_color, ground, land);
	ROUGHNESS = mix(0.3, 0.9, land);
	SPECULAR = 0.15;
	// fields and streets where there are people
	if (tech >= 2.0) {
		float grid = step(0.93, fract(world.x * 0.0009)) + step(0.93, fract(world.z * 0.0009));
		ALBEDO = mix(ALBEDO, vec3(0.35, 0.33, 0.28), clamp(grid, 0.0, 1.0) * land * 0.35);
	}
}
