shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

// Lua: o lado virado para o sol brilha, o outro fica no escuro (com um pouco de "luz cinérea").
// Como a lua é posicionada no céu pela fase (nova = perto do sol, cheia = oposta), as fases
// aparecem sozinhas: crescente, quarto, gibosa, cheia.

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0); // direção do sol no céu (mundo)
uniform vec3 lit_color : source_color = vec3(0.95, 0.94, 0.86);
uniform vec3 dark_color : source_color = vec3(0.06, 0.07, 0.1);
uniform float sky_fade = 1.0; // some de dia

varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float lit = smoothstep(-0.04, 0.06, dot(world_normal, normalize(sun_dir)));
	// Mares (manchas escuras) para não parecer uma bola lisa
	float maria = hash(floor(UV * 9.0)) * 0.12 + hash(floor(UV * 23.0)) * 0.06;
	vec3 col = mix(dark_color, lit_color * (1.0 - maria), lit);
	ALBEDO = col;
	ALPHA = mix(0.0, 1.0, sky_fade) * mix(0.35, 1.0, lit);
}
