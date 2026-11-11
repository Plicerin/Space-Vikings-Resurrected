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
	float glow = exp(-edge / 26.0) * 0.85 + exp(-edge / 90.0) * 0.25;
	float line = 1.0 - smoothstep(2.0, 4.0, edge); // a thin bright rim at the very edge
	float breathe = 0.7 + 0.3 * sin(TIME * pulse_rate * TAU * 0.5);
	COLOR = vec4(colour.rgb, clamp((glow + line * 0.6) * breathe * strength, 0.0, 1.0));
}
