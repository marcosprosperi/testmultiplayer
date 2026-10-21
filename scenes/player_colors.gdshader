shader_type canvas_item;

// Paints the knight in the player's color: its red (plume and tunic) and
// gold (trim) are swapped for main_color and light_color.

uniform vec4 main_color = vec4(0.792, 0.349, 0.329, 1.0);
uniform vec4 light_color = vec4(0.933, 0.710, 0.318, 1.0);

const vec3 RED = vec3(202.0, 89.0, 84.0) / 255.0;
const vec3 GOLD = vec3(238.0, 181.0, 81.0) / 255.0;

// The sprite's modulate (star colors, blinking); in fragment() COLOR already
// has the original texture mixed in, so it's taken from the vertex instead
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (distance(tex.rgb, RED) < 0.08) {
		tex.rgb = main_color.rgb;
	} else if (distance(tex.rgb, GOLD) < 0.08) {
		tex.rgb = light_color.rgb;
	}
	COLOR = tex * tint;
}
