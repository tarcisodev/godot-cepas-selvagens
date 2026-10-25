shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled, blend_add;

// Cúpula Estelar Procedural: estrelas em 3 camadas com cintilação viva,
// faixa de nebulosa/Via Láctea e estrelas cadentes ocasionais.

uniform float sky_visibility : hint_range(0.0, 1.0) = 1.0;
uniform vec3 nebula_color_a : source_color = vec3(0.08, 0.22, 0.36);
uniform vec3 nebula_color_b : source_color = vec3(0.24, 0.11, 0.35);

varying vec3 local_dir;

float hash31(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yxz + 19.19);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float noise3d(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
		f.z
	);
}

// Camada de estrelas em grade 3D sobre a direção normalizada
vec3 star_layer(vec3 dir, float scale, float density, float size_base, float twinkle_speed) {
	vec3 p = dir * scale;
	vec3 id = floor(p);
	vec3 rnd = hash33(id);
	if (rnd.x > density) {
		return vec3(0.0);
	}
	vec3 center = id + 0.2 + rnd * 0.6;
	float dist = length(p - center);
	float brightness = smoothstep(size_base, 0.0, dist);
	brightness = pow(brightness, 2.2);

	// Cintilação individual por estrela
	float phase = rnd.y * 6.28318 + rnd.z * 17.0;
	float twinkle = 0.68 + 0.32 * sin(TIME * (twinkle_speed + rnd.x * 2.5) + phase);

	// Temperatura de cor da estrela (azulada, branca, dourada, rosada)
	vec3 cold_star = vec3(0.68, 0.84, 1.0);
	vec3 warm_star = vec3(1.0, 0.88, 0.68);
	vec3 rose_star = vec3(1.0, 0.75, 0.82);
	vec3 star_col = mix(cold_star, warm_star, rnd.y);
	if (rnd.z > 0.82) {
		star_col = mix(star_col, rose_star, 0.65);
	}

	// Brilho em cruz sutil para as estrelas mais fortes
	float flare = 0.0;
	if (rnd.z > 0.72 && size_base > 0.22) {
		vec3 d = abs(p - center);
		float cross_a = exp(-d.x * 18.0) * exp(-d.y * 55.0);
		float cross_b = exp(-d.y * 18.0) * exp(-d.z * 55.0);
		flare = (cross_a + cross_b) * 0.45;
	}

	return star_col * (brightness + flare) * twinkle * (0.55 + 0.45 * rnd.z);
}

// Estrela cadente esporádica
vec3 shooting_star(vec3 dir) {
	float period = 11.0;
	float cycle = floor(TIME / period);
	float local_t = fract(TIME / period) * period;
	// Dura ~0.85s dentro de cada janela
	if (local_t > 0.85 || dir.y < 0.12) {
		return vec3(0.0);
	}
	float progress = local_t / 0.85;
	vec3 seed = hash33(vec3(cycle, cycle * 1.7 + 3.1, cycle * 2.3 + 7.0));
	// Posição inicial no alto do céu
	float angle = seed.x * 6.28318;
	float elev = 0.42 + seed.y * 0.42;
	vec3 start_dir = normalize(vec3(cos(angle) * (1.0 - elev * 0.4), elev, sin(angle) * (1.0 - elev * 0.4)));
	vec3 tangent = normalize(cross(start_dir, vec3(0.2, 1.0, -0.3)));
	vec3 head = normalize(start_dir + tangent * (progress * 0.42));
	vec3 tail = normalize(start_dir + tangent * (max(0.0, progress - 0.16) * 0.42));

	// Distância do ponto de visão ao segmento [tail, head]
	vec3 seg = head - tail;
	float seg_len2 = max(dot(seg, seg), 0.00001);
	float h = clamp(dot(dir - tail, seg) / seg_len2, 0.0, 1.0);
	vec3 closest = normalize(tail + seg * h);
	float d = length(dir - closest);

	float streak = smoothstep(0.0065, 0.0, d) * h * sin(progress * 3.14159);
	return vec3(0.82, 0.95, 1.0) * streak * 2.2;
}

void vertex() {
	local_dir = normalize(VERTEX);
}

void fragment() {
	vec3 dir = normalize(local_dir);
	// Esconde abaixo do horizonte com transição suave
	float horizon_fade = smoothstep(-0.02, 0.18, dir.y);
	if (horizon_fade <= 0.001 || sky_visibility <= 0.001) {
		ALBEDO = vec3(0.0);
		ALPHA = 0.0;
	} else {
		// Três camadas de estrelas (poeira estelar, estrelas médias, estrelas guia)
		vec3 s1 = star_layer(dir, 95.0, 0.24, 0.19, 1.4) * 0.55;
		vec3 s2 = star_layer(dir + vec3(0.37, 0.19, -0.51), 52.0, 0.16, 0.24, 2.1) * 1.1;
		vec3 s3 = star_layer(dir + vec3(-0.61, 0.43, 0.29), 26.0, 0.09, 0.30, 2.8) * 1.65;

		// Faixa da Via Láctea / Nebulosa da Cepa
		float band_coord = dot(dir, normalize(vec3(0.45, 0.52, -0.72)));
		float band_mask = exp(-band_coord * band_coord * 9.5);
		float n1 = noise3d(dir * 4.5 + vec3(0.0, 0.0, TIME * 0.004));
		float n2 = noise3d(dir * 9.5 - vec3(TIME * 0.003, 0.0, 0.0));
		float nebula_density = band_mask * smoothstep(0.32, 0.82, n1 * 0.65 + n2 * 0.35);
		vec3 nebula = mix(nebula_color_a, nebula_color_b, n2) * nebula_density * 0.55;

		// Estrela cadente
		vec3 meteor = shooting_star(dir);

		vec3 total = (s1 + s2 + s3 + nebula + meteor) * horizon_fade * sky_visibility;
		ALBEDO = total;
		ALPHA = clamp(length(total), 0.0, 1.0);
	}
}
