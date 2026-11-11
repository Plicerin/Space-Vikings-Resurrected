shader_type spatial;
// A planet: a lit sphere with an atmosphere's rim, and on the night side
// the lights of cities, more of them the more advanced the planet.

uniform vec3 land_color : source_color = vec3(0.30, 0.42, 0.26);
uniform vec3 sea_color : source_color = vec3(0.08, 0.20, 0.42);
uniform vec3 air_color : source_color = vec3(0.35, 0.60, 1.0);
uniform vec3 light_color : source_color = vec3(1.0, 0.78, 0.45);
// Where the sun is, the way the sphere's own axes point.
uniform vec3 sun_direction = vec3(0.6, 0.25, -0.75);
// 0 nothing living to 4 more advanced than we are: sets how many lights.
uniform float tech = 2.0;
// The cities: directions from the planet's middle, the first `city_count` of
// them lit. (The game's own cluster of points round its planet, given a
// planet to be on.)
uniform vec3 cities[144];
uniform int city_count = 0;
// Different for every planet, so that each has its own lights.
uniform float seed = 1.0;
uniform float air = 1.0;

varying vec3 surface;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3) + seed * 0.137);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

void vertex() {
	surface = normalize(VERTEX);
}

void fragment() {
	vec3 n = normalize(surface);
	// land and sea from a few octaves of noise
	float h = value_noise(n * 3.0 + seed) * 0.6 + value_noise(n * 7.0) * 0.3 + value_noise(n * 15.0) * 0.1;
	float land = smoothstep(0.48, 0.52, h);
	vec3 colour = mix(sea_color, land_color, land);
	ALBEDO = colour;
	ROUGHNESS = mix(0.55, 0.95, land);
	SPECULAR = 0.12;

	float day = dot(n, normalize(sun_direction));
	float night = 1.0 - smoothstep(-0.08, 0.12, day);

	// villages: a dot in some cells of a grid on the sphere, on land only
	float density = 0.0;
	if (tech >= 1.0) { density = 0.004; }
	if (tech >= 2.0) { density = 0.02; }
	if (tech >= 3.0) { density = 0.05; }
	if (tech >= 4.0) { density = 0.10; }
	vec3 cell_space = n * 46.0;
	vec3 cell = floor(cell_space);
	float on = step(1.0 - density, hash(cell + 11.0));
	float round_dot = smoothstep(0.55, 0.15, length(fract(cell_space) - 0.5));
	float glow = on * round_dot * land * night * 0.7;
	// and the cities, each a bright dot with a haze round it
	float cities_glow = 0.0;
	for (int i = 0; i < 144; i++) {
		if (i >= city_count) { break; }
		float closeness = dot(n, normalize(cities[i]));
		float size = 0.6 + 0.8 * hash(cities[i] * 91.0);
		cities_glow += size * (smoothstep(0.99985, 0.999995, closeness) + 0.3 * smoothstep(0.9996, 0.9999, closeness));
	}
	glow += min(cities_glow, 1.4) * night * (0.55 + 0.1 * tech);

	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	EMISSION = light_color * glow * 2.2 + air_color * rim * air * (0.15 + 0.5 * clamp(day + 0.4, 0.0, 1.0));
}
