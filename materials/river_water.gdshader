shader_type spatial;
render_mode blend_mix, depth_draw_opaque, specular_schlick_ggx;

// Rio estilizado: ondulações que correm na direção do fluxo (UV.y = ao longo do rio),
// margens mais claras e brilho de fresnel. Sem texturas: ruído procedural.

uniform vec3 deep_color : source_color = vec3(0.12, 0.40, 0.50);
uniform vec3 shallow_color : source_color = vec3(0.36, 0.70, 0.74);
uniform vec3 foam_color : source_color = vec3(0.92, 0.97, 1.0);
uniform float flow_speed = 0.9;
uniform float alpha = 0.8;

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
	float t = TIME * flow_speed;
	float ripple = noise(vec2(uv.x * 6.0, uv.y * 0.6 - t)) * 0.6 + noise(vec2(uv.x * 14.0 + 3.0, uv.y * 1.5 - t * 1.7)) * 0.4;

	// Centro mais fundo, margens rasas com espuma fina
	float center = 1.0 - abs(uv.x - 0.5) * 2.0;
	vec3 col = mix(shallow_color, deep_color, smoothstep(0.0, 0.8, center));
	float edge_foam = smoothstep(0.12, 0.0, min(uv.x, 1.0 - uv.x)) * (0.5 + 0.5 * ripple);
	float sparkle = smoothstep(0.78, 0.95, ripple) * 0.35;

	col = mix(col, foam_color, clamp(edge_foam + sparkle, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.06 + ripple * 0.1;
	SPECULAR = 0.7;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALPHA = clamp(alpha + fresnel * 0.15 + edge_foam * 0.2, 0.0, 1.0);
}
