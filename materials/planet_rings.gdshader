shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

// Anéis concêntricos do Planeta Anelado: divisão de Cassini, poeira de gelo/quartzo,
// iluminação solar e sombra projetada pela esfera do planeta.

uniform vec3 sun_dir = vec3(0.5, 0.7, 0.5);
uniform float sky_fade : hint_range(0.0, 1.0) = 1.0;
uniform vec3 ring_color_inner : source_color = vec3(0.95, 0.84, 0.64);
uniform vec3 ring_color_outer : source_color = vec3(0.62, 0.86, 0.94);

varying vec3 local_vertex;

void vertex() {
	local_vertex = VERTEX;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);

	// Anel existe entre r = 0.44 e r = 0.98
	float inner_mask = smoothstep(0.43, 0.48, r);
	float outer_mask = 1.0 - smoothstep(0.93, 0.99, r);
	float ring_mask = inner_mask * outer_mask;

	if (ring_mask <= 0.001 || sky_fade <= 0.001) {
		ALBEDO = vec3(0.0);
		ALPHA = 0.0;
	} else {
		// Divisão de Cassini (falha escura em r ~ 0.74) e múltiplos sub-anéis
		float cassini = 1.0 - 0.85 * exp(-pow((r - 0.74) * 38.0, 2.0));
		float gap2 = 1.0 - 0.55 * exp(-pow((r - 0.58) * 55.0, 2.0));
		float ripples = 0.72 + 0.28 * sin(r * 140.0) * cos(r * 63.0);

		float t = clamp((r - 0.44) / 0.54, 0.0, 1.0);
		vec3 col = mix(ring_color_inner, ring_color_outer, t);
		col *= (0.85 + 0.15 * sin(r * 210.0));

		// Sombra projetada pelo corpo do planeta sobre a parte de trás do anel
		vec3 world_pos = (MODEL_MATRIX * vec4(local_vertex, 1.0)).xyz;
		vec3 planet_center = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		vec3 rel = normalize(world_pos - planet_center);
		float shadow_align = dot(rel, -normalize(sun_dir));
		float planet_shadow = 1.0 - 0.75 * smoothstep(0.78, 0.94, shadow_align);

		float density = ring_mask * cassini * gap2 * ripples * 0.78;
		ALBEDO = col * planet_shadow;
		ALPHA = clamp(density * sky_fade * mix(0.45, 1.0, planet_shadow), 0.0, 0.92);
	}
}
