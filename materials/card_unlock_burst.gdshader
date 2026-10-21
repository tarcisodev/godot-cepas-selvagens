shader_type canvas_item;
render_mode blend_add;

// Explosão de luz atrás da carta recém-descoberta: raios girando e halo na cor da raridade.

uniform vec4 glow_color : source_color = vec4(1.0, 0.82, 0.3, 1.0);
uniform float intensity = 1.0;
uniform float ray_count = 14.0;

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float ang = atan(p.y, p.x);
	float rays = pow(0.5 + 0.5 * sin(ang * ray_count + TIME * 1.4), 6.0);
	rays += pow(0.5 + 0.5 * sin(ang * ray_count * 0.5 - TIME * 0.9), 10.0) * 0.6;
	float fade = smoothstep(1.0, 0.15, r);
	float halo = exp(-r * r * 6.0);
	float a = (rays * fade * 0.55 + halo * 0.9) * intensity;
	COLOR = vec4(glow_color.rgb * a, 1.0);
}
