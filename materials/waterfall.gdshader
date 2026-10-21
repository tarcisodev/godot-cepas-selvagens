shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, specular_schlick_ggx;

// Cachoeira estilizada: faixas de água descendo (UV.y cresce para baixo)
// e espuma branca no pé da queda. Sem texturas: ruído procedural.

uniform vec3 water_color : source_color = vec3(0.32, 0.62, 0.72);
uniform vec3 foam_color : source_color = vec3(0.95, 0.98, 1.0);
uniform float flow_speed = 1.6;
uniform float streaks = 14.0;
uniform float base_alpha = 0.82;

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

void fragment() {
	vec2 uv = UV;
	// Faixas verticais esticadas que escorrem
	float n = noise(vec2(uv.x * streaks, uv.y * 3.0 - TIME * flow_speed));
	float n2 = noise(vec2(uv.x * streaks * 2.3 + 7.0, uv.y * 5.0 - TIME * flow_speed * 1.4));
	float streak = smoothstep(0.45, 0.85, n * 0.6 + n2 * 0.5);

	// Espuma: mais forte no topo (borda) e muito forte no pé da queda
	float foam_top = smoothstep(0.12, 0.0, uv.y);
	float foam_bottom = smoothstep(0.7, 1.0, uv.y) * (0.6 + 0.4 * noise(uv * vec2(20.0, 6.0) + vec2(0.0, -TIME * 2.0)));
	float foam = clamp(streak * 0.55 + foam_top + foam_bottom, 0.0, 1.0);

	ALBEDO = mix(water_color, foam_color, foam);
	ROUGHNESS = mix(0.08, 0.6, foam);
	SPECULAR = 0.6;
	EMISSION = foam_color * foam * 0.12;
	// Bordas laterais esfiapadas
	float edge = smoothstep(0.0, 0.08, uv.x) * smoothstep(1.0, 0.92, uv.x);
	ALPHA = clamp((base_alpha + foam * 0.2) * edge, 0.0, 1.0);
}
