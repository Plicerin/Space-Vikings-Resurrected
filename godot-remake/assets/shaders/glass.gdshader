shader_type canvas_item;
// The glass of a CRT over its picture: the corners and edges fall dark, and a soft
// reflection of a window lies across the upper left. Rounded to the tube's corners.
uniform vec2 panel_size = vec2(350.0, 130.0);
uniform float corner = 10.0;

void fragment() {
	vec2 pos = UV * panel_size;
	vec2 half_size = panel_size * 0.5;
	vec2 q = abs(pos - half_size) - (half_size - vec2(corner));
	float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner;
	float mask = 1.0 - smoothstep(-0.5, 0.5, dist);
	vec2 c = (UV - 0.5) * 2.0;
	float vignette = smoothstep(0.5, 1.3, length(c * vec2(0.9, 1.05)));
	float band = (UV.x * 0.55 + UV.y * 0.6) - 0.3;
	float reflection = exp(-pow(band / 0.07, 2.0)) * 0.07 * (1.0 - UV.y * 0.8);
	float darkness = vignette * 0.6;
	float a = clamp(darkness + reflection, 0.0, 1.0);
	float whiteness = reflection / max(darkness + reflection, 0.0001);
	COLOR = vec4(vec3(whiteness), a * mask);
}
