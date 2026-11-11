shader_type canvas_item;
// The attitude ball: a lit sphere, sky above the horizon and ground below, with a
// ladder every fifteen degrees. `pitch` and `bank` are radians; the ball shows the
// view ahead, nose up moves the horizon down, a bank tilts it.
uniform float pitch = 0.0;
uniform float bank = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	float aa = fwidth(d);
	float mask = 1.0 - smoothstep(0.94 - aa, 0.94 + aa, d);
	float rim = smoothstep(0.94 - aa, 0.94 + aa, d) * (1.0 - smoothstep(1.0 - aa, 1.0 + aa, d));
	vec2 q = p / 0.94;
	float z = sqrt(max(1.0 - dot(q, q), 0.0));
	vec3 n = vec3(q, z);
	vec3 down = vec3(-sin(-bank), cos(-bank), 0.0);
	float alt = dot(n, -down) * cos(pitch) + n.z * sin(pitch);
	float angle = asin(clamp(alt, -1.0, 1.0));
	vec3 sky = mix(vec3(0.10, 0.30, 0.70), vec3(0.45, 0.70, 0.95), smoothstep(0.0, 1.0, alt));
	vec3 ground = mix(vec3(0.30, 0.20, 0.10), vec3(0.12, 0.09, 0.05), smoothstep(0.0, 1.0, -alt));
	vec3 surface = alt >= 0.0 ? sky : ground;
	float ladder = 1.0 - smoothstep(0.0, 0.018, abs(fract(angle / radians(15.0) + 0.5) - 0.5) * radians(15.0));
	surface = mix(surface, vec3(1.0), ladder * 0.35);
	float horizon = 1.0 - smoothstep(0.0, 0.02, abs(angle));
	surface = mix(surface, vec3(1.0), horizon);
	vec3 light = normalize(vec3(-0.4, -0.5, 0.75));
	float shade = 0.55 + 0.45 * max(dot(n, light), 0.0);
	float spec = pow(max(dot(reflect(-light, n), vec3(0.0, 0.0, 1.0)), 0.0), 24.0);
	vec3 rgb = surface * shade + vec3(spec * 0.25);
	rgb = mix(rgb, rgb * 0.5, pow(1.0 - z, 3.0)); // the edge curves away
	rgb = rgb * mask + vec3(0.55, 0.65, 0.75) * rim;
	COLOR = vec4(rgb, max(mask, rim) * 0.95);
}
