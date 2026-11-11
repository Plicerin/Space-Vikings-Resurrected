shader_type canvas_item;
// The alert border: a glow along the edges of the screen, yellow or red, that
// breathes while the alert is on.
uniform vec4 colour : source_color = vec4(1.0, 0.2, 0.1, 1.0);
uniform float strength = 1.0;
uniform float pulse_rate = 2.0;
uniform vec2 screen_size = vec2(1280.0, 720.0);

void fragment() {
	vec2 px = UV * screen_size;
	float edge = min(min(px.x, screen_size.x - px.x), min(px.y, screen_size.y - px.y));
	float inset = 6.0;
	// a crisp neon line a little inside the edge, its glow spilling inwards only
	float line = exp(-pow((edge - inset) / 1.3, 2.0));
	float inner = edge > inset ? exp(-(edge - inset) / 22.0) * 0.45 : 0.0;
	float breathe = 0.75 + 0.25 * sin(TIME * pulse_rate * TAU * 0.5);
	vec3 core = mix(colour.rgb, vec3(1.0), 0.35 * line);
	COLOR = vec4(core, clamp((line + inner) * breathe * strength, 0.0, 1.0));
}
