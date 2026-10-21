shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

// Brilho de foil sobre a face da carta. Reage à inclinação (normal em espaço de vista),
// então o reflexo "corre" pela carta quando o cursor a inclina. Intensidade por raridade.

uniform float strength = 0.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float rainbow = 0.0;
uniform vec2 card_size = vec2(2.295, 3.213);
uniform float corner_radius = 0.13;

float rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	vec2 p = (UV - 0.5) * card_size;
	float d = rounded_box(p, card_size * 0.5, corner_radius);
	float inside = 1.0 - smoothstep(-0.008, 0.008, d);

	float shift = NORMAL.x * 2.2 + NORMAL.y * 1.6;
	float band = UV.x * 0.8 + UV.y * 1.2 + shift;
	float stripes = pow(0.5 + 0.5 * sin(band * 9.4 + TIME * 0.5), 8.0);
	float sweep = smoothstep(0.1, 0.0, abs(fract(band * 0.45 - TIME * 0.07) - 0.5));
	float edge = smoothstep(-0.1, 0.0, d);

	vec3 col = mix(tint, hue(fract(band * 0.6 + TIME * 0.04)), rainbow);
	float a = (stripes * 0.35 + sweep * 0.8 + edge * 0.6) * strength * inside;
	ALBEDO = col * a;
}
