shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;

// Rio com profundidade de verdade: lê a profundidade da cena atrás da água.
// Raso = transparente, mostra o leito (refração leve) com tom verde-água;
// fundo = escurece até azul-petróleo. Espuma onde a água encosta na margem e nas pedras.
// Ondulação corre no sentido do fluxo (UV.y = ao longo do rio) e mexe no reflexo.

uniform float emission_strength = 0.45; // cai à noite (o rio não brilha no escuro)
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

uniform vec3 shallow_color : source_color = vec3(0.28, 0.62, 0.56);
uniform vec3 deep_color : source_color = vec3(0.03, 0.17, 0.24);
uniform vec3 foam_color : source_color = vec3(0.9, 0.96, 1.0);
uniform float depth_fade = 2.2;      // metros de água até ficar "fundo"
uniform float clarity = 0.85;        // quanto do leito aparece no raso
uniform float refraction = 0.035;
uniform float flow_speed = 0.55;
uniform float foam_width = 0.45;     // metros de água junto à margem com espuma

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Altura das ondinhas: duas camadas correndo rio abaixo
float waves(vec2 p, float t) {
	return noise(p * vec2(1.6, 0.7) + vec2(0.0, -t)) * 0.6 + noise(p * vec2(3.7, 2.1) + vec2(4.0, -t * 1.6)) * 0.4;
}

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * flow_speed;
	vec2 p = vec2(world.x, UV.y * 1.3);

	// Normal das ondinhas (diferenças finitas)
	float e = 0.15;
	float h0 = waves(p, t);
	float hx = waves(p + vec2(e, 0.0), t);
	float hz = waves(p + vec2(0.0, e), t);
	vec3 wave_n = normalize(vec3(h0 - hx, 1.6, h0 - hz));
	NORMAL = normalize((VIEW_MATRIX * vec4(wave_n, 0.0)).xyz);

	// Espessura da água: profundidade da cena atrás menos a da superfície
	float raw = texture(depth_texture, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	v.xyz /= v.w;
	float thickness = max(-v.z - (-VERTEX.z), 0.0);
	float d = clamp(thickness / depth_fade, 0.0, 1.0);

	// Leito visto através da água (distorcido pelas ondas, menos no raso)
	vec2 off = (wave_n.xz) * refraction * d;
	vec3 bed = textureLod(screen_texture, SCREEN_UV + off, 0.0).rgb;

	vec3 water = mix(shallow_color, deep_color, pow(d, 0.6));
	vec3 col = mix(bed * shallow_color * 1.6, water, clamp(pow(d, 0.55) + (1.0 - clarity), 0.0, 1.0));

	// Espuma na beira e nas cristas
	float edge = 1.0 - clamp(thickness / foam_width, 0.0, 1.0);
	float foam = smoothstep(0.35, 0.9, edge * (0.6 + 0.6 * noise(world.xz * 3.0 + vec2(0.0, -t * 2.0))));
	foam += smoothstep(0.82, 0.97, h0) * 0.25 * d;
	foam = clamp(foam, 0.0, 1.0);

	ALBEDO = mix(col * 0.55, foam_color, foam);
	EMISSION = col * emission_strength * (1.0 - foam);
	ROUGHNESS = mix(0.04, 0.5, foam);
	SPECULAR = 0.65;
	ALPHA = 1.0;
}
