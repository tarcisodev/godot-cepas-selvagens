shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

// Fundo do palco de inspeção das cartas: halo radial na cor do elemento,
// raios lentos girando atrás da carta, grão leve e vinheta.

uniform vec3 tint : source_color = vec3(0.45, 0.35, 0.75);
uniform vec3 deep : source_color = vec3(0.025, 0.028, 0.045);
uniform float ray_strength = 0.16;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// Coordenadas de tela: o halo sempre fica centrado no palco, qualquer que seja o tamanho
	vec2 p = SCREEN_UV - vec2(0.5, 0.47);
	p.x *= VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	float r = length(p);

	float halo = exp(-r * r * 5.0);
	float ang = atan(p.y, p.x);
	float rays = 0.5 + 0.5 * sin(ang * 9.0 + TIME * 0.22) * sin(ang * 5.0 - TIME * 0.15);
	rays = pow(rays, 2.0) * smoothstep(0.85, 0.08, r) * ray_strength;

	vec3 col = mix(deep, tint * 0.42, halo) + tint * rays;
	col += tint * exp(-r * r * 60.0) * 0.12;
	col += (hash(SCREEN_UV * VIEWPORT_SIZE + fract(TIME)) - 0.5) * 0.004;
	col *= smoothstep(0.95, 0.2, r);
	ALBEDO = max(col, vec3(0.0));
}
