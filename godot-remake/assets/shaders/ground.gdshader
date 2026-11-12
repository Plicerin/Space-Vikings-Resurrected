shader_type spatial;
render_mode blend_mix, cull_back;
// The ground of a planet from the air, drawn on the planet's own sphere (the planet shader's
// sphere, at the same radius): sea and land from the planet's own noise, with relief (the light
// falling on hills that are not there to collide with), beaches, fields and woods, rock on the
// heights, a glint on the water, fine detail that comes up as the ground comes near, and a haze
// towards the edge. It is clear from far off (the planet shader's look shows through) and comes
// in as the eye comes down, so that the descent from orbit is one flight over one planet.

uniform vec3 deep_color : source_color = vec3(0.03, 0.12, 0.30);
uniform vec3 shallow_color : source_color = vec3(0.10, 0.38, 0.52);
uniform vec3 sand_color : source_color = vec3(0.72, 0.64, 0.45);
uniform vec3 grass_color : source_color = vec3(0.26, 0.42, 0.18);
uniform vec3 dry_color : source_color = vec3(0.52, 0.44, 0.26);
uniform vec3 wood_color : source_color = vec3(0.09, 0.22, 0.10);
uniform vec3 rock_color : source_color = vec3(0.42, 0.38, 0.35);
uniform vec3 snow_color : source_color = vec3(0.92, 0.94, 0.98);
uniform float tech = 2.0;
uniform float seed = 1.0;
uniform float scale = 0.00018;
uniform float sea_level = 0.5;
uniform float relief = 5200.0;
// `world_scale` of the scene's units to one of the ground's, and the planet's radius in the ground's.
uniform float world_scale = 3.0;
uniform float planet_radius = 45000.0;
// The eye's height above the ground (in the ground's units) over which the ground comes in.
uniform float comes_in_from = 26000.0;
uniform float comes_in_to = 9000.0;

varying vec3 world;
varying vec3 local;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3) + seed * 0.137);
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

// The map: the planet's continents and coasts (planet.gdshader), ridges on them. `n` is a
// direction from the planet's centre.
float height(vec3 n) {
	float h = value_noise3(n * 3.0 + seed) * 0.6 + value_noise3(n * 7.0) * 0.3 + value_noise3(n * 15.0) * 0.1;
	vec3 p = n * planet_radius * scale;
	return h + (value_noise3(p * 31.0) - 0.5) * 0.10 + (value_noise3(p * 97.0) - 0.5) * 0.05;
}

void vertex() {
	local = VERTEX;
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 n = normalize(local);
	vec3 up = normalize(world);
	vec3 p = n * planet_radius; // where on the ground, in the ground's units
	float dist = distance(world, cam) / world_scale;
	float eye_height = (length(cam) - length(world)) / world_scale;
	float coming = 1.0 - smoothstep(comes_in_to, comes_in_from, eye_height);
	float h = height(n);
	// relief: the slope of the map, a few hundred units to a side, along the ground's two directions
	float e = 60.0 / planet_radius;
	vec3 t1 = normalize(cross(n, abs(n.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 t2 = cross(n, t1);
	float dx = height(normalize(n + t1 * e)) - height(normalize(n - t1 * e));
	float dz = height(normalize(n + t2 * e)) - height(normalize(n - t2 * e));
	float land = smoothstep(sea_level - 0.006, sea_level + 0.006, h);
	float high = clamp((h - sea_level) / 0.28, 0.0, 1.0); // 0 at the shore, 1 on the heights
	vec3 world_t1 = normalize(cross(up, abs(up.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 world_t2 = cross(up, world_t1);
	vec3 slope = normalize(up - (world_t1 * dx + world_t2 * dz) * relief * land);
	// fine detail, near the eye
	float near = 1.0 - smoothstep(600.0, 9000.0, dist);
	float fine = value_noise3(p * 0.02) * 0.5 + value_noise3(p * 0.09) * 0.3 + value_noise3(p * 0.4) * 0.2;
	float grain = (fine - 0.5) * near;
	// the sea
	float depth = clamp((sea_level - h) / 0.12, 0.0, 1.0);
	vec3 sea = mix(shallow_color, deep_color, sqrt(depth));
	// the land
	float wet = value_noise3(p * scale * 6.0 + 7.0);
	vec3 low = mix(grass_color, dry_color, smoothstep(0.45, 0.75, value_noise3(p * scale * 5.0 + 4.0)));
	float woods = smoothstep(0.55, 0.7, wet) * (1.0 - high);
	low = mix(low, wood_color, woods * (0.6 + 0.4 * value_noise3(p * 0.05)));
	vec3 ground = mix(sand_color, low, smoothstep(0.0, 0.07, high));
	ground = mix(ground, rock_color, smoothstep(0.45, 0.7, high));
	ground = mix(ground, snow_color, smoothstep(0.82, 0.95, high + (value_noise3(p * 0.004) - 0.5) * 0.1));
	// fields and streets where there are people, on the low land
	if (tech >= 2.0) {
		float grid = step(0.93, fract(p.x * 0.0009)) + step(0.93, fract(p.z * 0.0009));
		float plots = floor(p.x * 0.0009) * 0.37 + floor(p.z * 0.0009) * 0.61;
		ground = mix(ground, ground * (0.85 + 0.3 * fract(plots * 7.3)), 0.5 * (1.0 - smoothstep(0.1, 0.3, high)) * near);
		ground = mix(ground, vec3(0.35, 0.33, 0.28), clamp(grid, 0.0, 1.0) * 0.35 * (1.0 - smoothstep(0.05, 0.25, high)));
	}
	ground *= 1.0 + grain * 0.5;
	ALBEDO = mix(sea, ground, land);
	ALPHA = coming;
	// the sea is smooth and bright with the sun on it; the land rough
	ROUGHNESS = mix(0.06, 0.9, land);
	SPECULAR = mix(0.9, 0.12, land);
	METALLIC = 0.0;
	vec3 view_normal = (VIEW_MATRIX * vec4(slope, 0.0)).xyz;
	NORMAL = normalize(mix(NORMAL, view_normal, land));
}
