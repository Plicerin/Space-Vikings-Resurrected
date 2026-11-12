shader_type spatial;
// The ground of a planet from the air: sea and land from noise on the map, with
// relief (the light falling on hills that are not there to collide with), beaches,
// fields and woods, rock on the heights, a glint on the water, fine detail that
// comes up as the ground comes near, and a haze towards the edge.

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

// The map: broad continents and coasts, ridges on them.
float height(vec2 w) {
	vec2 p = w * scale;
	float h = value_noise(p * 3.0 + seed) * 0.55 + value_noise(p * 9.0) * 0.28 + value_noise(p * 31.0) * 0.12 + value_noise(p * 97.0) * 0.05;
	return h;
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float dist = distance(world, cam);
	vec2 w = world.xz;
	float h = height(w);
	// relief: the slope of the map, a few hundred units to a side
	float e = 60.0;
	float dx = height(w + vec2(e, 0.0)) - height(w - vec2(e, 0.0));
	float dz = height(w + vec2(0.0, e)) - height(w - vec2(0.0, e));
	float land = smoothstep(sea_level - 0.006, sea_level + 0.006, h);
	float high = clamp((h - sea_level) / 0.28, 0.0, 1.0); // 0 at the shore, 1 on the heights
	vec3 slope = normalize(vec3(-dx * relief * land, 1.0, -dz * relief * land));
	// fine detail, near the eye
	float near = 1.0 - smoothstep(600.0, 9000.0, dist);
	float fine = value_noise(w * 0.02) * 0.5 + value_noise(w * 0.09) * 0.3 + value_noise(w * 0.4) * 0.2;
	float grain = (fine - 0.5) * near;
	// the sea
	float depth = clamp((sea_level - h) / 0.12, 0.0, 1.0);
	vec3 sea = mix(shallow_color, deep_color, sqrt(depth));
	// the land
	float wet = value_noise(w * scale * 6.0 + 7.0);
	vec3 low = mix(grass_color, dry_color, smoothstep(0.45, 0.75, value_noise(w * scale * 5.0 + 4.0)));
	float woods = smoothstep(0.55, 0.7, wet) * (1.0 - high);
	low = mix(low, wood_color, woods * (0.6 + 0.4 * value_noise(w * 0.05)));
	vec3 ground = mix(sand_color, low, smoothstep(0.0, 0.07, high));
	ground = mix(ground, rock_color, smoothstep(0.45, 0.7, high));
	ground = mix(ground, snow_color, smoothstep(0.82, 0.95, high + (value_noise(w * 0.004) - 0.5) * 0.1));
	// fields and streets where there are people, on the low land
	if (tech >= 2.0) {
		float grid = step(0.93, fract(world.x * 0.0009)) + step(0.93, fract(world.z * 0.0009));
		float plots = floor(w.x * 0.0009) * 0.37 + floor(w.y * 0.0009) * 0.61;
		ground = mix(ground, ground * (0.85 + 0.3 * fract(plots * 7.3)), 0.5 * (1.0 - smoothstep(0.1, 0.3, high)) * near);
		ground = mix(ground, vec3(0.35, 0.33, 0.28), clamp(grid, 0.0, 1.0) * 0.35 * (1.0 - smoothstep(0.05, 0.25, high)));
	}
	ground *= 1.0 + grain * 0.5;
	ALBEDO = mix(sea, ground, land);
	// the sea is smooth and bright with the sun on it; the land rough
	ROUGHNESS = mix(0.06, 0.9, land);
	SPECULAR = mix(0.9, 0.12, land);
	METALLIC = 0.0;
	vec3 view_normal = (VIEW_MATRIX * vec4(slope, 0.0)).xyz;
	NORMAL = normalize(mix(NORMAL, view_normal, land));
}
