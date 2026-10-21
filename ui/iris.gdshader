shader_type canvas_item;

// Cartoon "iris" transition: everything outside a circle is covered.
// radius is in screen heights (0 = all covered, 1.2 = all open).

uniform float radius = 1.2;
uniform float aspect = 1.7778;
uniform vec4 cover_color = vec4(0.11, 0.07, 0.18, 1.0);
uniform vec4 ring_color = vec4(1.0, 0.82, 0.25, 1.0);

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(aspect, 1.0);
	float d = length(p);
	if (d < radius) {
		COLOR = vec4(0.0);
	} else if (d < radius + 0.012) {
		COLOR = ring_color;
	} else {
		COLOR = cover_color;
	}
}
