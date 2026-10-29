shader_type spatial;

// Calçamento da Praça da Cepa-Mãe (B36): pedras de Voronoi em coordenadas de mundo, rejunte de
// terra entre elas e borda que se desfaz em pedras soltas (as células perto da borda somem e
// deixam a terra batida do terreno aparecer). Sem textura: tudo por ruído.

uniform vec3 stone_light : source_color = vec3(0.56, 0.53, 0.48);
uniform vec3 stone_dark : source_color = vec3(0.39, 0.37, 0.35);
uniform vec3 stone_warm : source_color = vec3(0.55, 0.46, 0.36);
uniform vec3 mortar : source_color = vec3(0.27, 0.22, 0.16);
uniform float cell_size = 0.62;
uniform vec2 center = vec2(0.0, 6.0);
uniform float radius = 8.0;
// Anel de mosaico em volta da árvore (pedras mais claras)
uniform float ring_inner = 2.4;
uniform float ring_outer = 2.9;

varying vec3 world_pos;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz / cell_size;
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 id = vec2(0.0);
	vec2 to_cell = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash2(i + g) * 0.75 + 0.125;
			vec2 r = g + o - f;
			float d = length(r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = i + g;
				to_cell = r;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	// Centro da pedra no mundo: decide se ela existe (borda esfarelada) e se é do anel
	vec2 cell_world = (id + hash2(id) * 0.75 + 0.125) * cell_size;
	float cr = length(cell_world - center);
	float h = hash2(id + 11.0).x;
	if (cr > radius - 1.6 * h) {
		discard;
	}
	float edge = d2 - d1;
	float stone_mask = smoothstep(0.05, 0.17, edge);
	if (cr > radius - 2.2 && stone_mask < 0.5) {
		discard;  // rejunte some perto da borda: pedras soltas na terra
	}
	vec3 stone = mix(stone_dark, stone_light, h);
	stone = mix(stone, stone_warm, step(0.82, hash2(id + 5.0).y) * 0.8);
	if (cr > ring_inner && cr < ring_outer) {
		stone = mix(stone, vec3(0.70, 0.64, 0.52), 0.65);
	}
	stone *= 0.88 + 0.24 * hash2(id + 3.0).x;
	// Abaulado: o centro da pedra fica mais claro que a beirada
	float dome = 1.0 - smoothstep(0.0, 0.55, d1);
	stone *= 0.86 + 0.18 * dome;
	ALBEDO = mix(mortar, stone, stone_mask);
	ROUGHNESS = mix(0.98, 0.78 - 0.12 * h, stone_mask);
	AO = mix(0.45, 1.0, stone_mask);
	// Normal falsa: a pedra inclina para fora do próprio centro perto da beirada
	vec2 slope = normalize(-to_cell + vec2(0.0001)) * (1.0 - stone_mask * 0.6) * 0.5;
	NORMAL = normalize((VIEW_MATRIX * vec4(slope.x, 1.0, slope.y, 0.0)).xyz);
}
