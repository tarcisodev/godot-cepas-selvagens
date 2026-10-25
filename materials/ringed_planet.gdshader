shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

// Gigante Gasoso ("O Observador Anelado"): bandas atmosféricas procedurais,
// vórtice de tempestade, brilho de atmosfera (Fresnel) e fase iluminada pelo sol.

uniform vec3 sun_dir = vec3(0.5, 0.7, 0.5);
uniform float sky_fade : hint_range(0.0, 1.0) = 1.0;
uniform vec3 band_color_a : source_color = vec3(0.88, 0.68, 0.44);
uniform vec3 band_color_b : source_color = vec3(0.58, 0.36, 0.24);
uniform vec3 band_color_c : source_color = vec3(0.32, 0.56, 0.62);
uniform vec3 night_side_color : source_color = vec3(0.04, 0.05, 0.10);

varying vec3 world_normal;
varying vec3 local_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	local_pos = normalize(VERTEX);
}

void fragment() {
	// Coordenadas esféricas locais para bandas gasosas
	float lat = local_pos.y;
	float lon = atan(local_pos.x, local_pos.z);

	float turb = noise2d(vec2(lon * 2.5 + TIME * 0.02, lat * 9.0)) * 0.14
	           + noise2d(vec2(lon * 6.0 - TIME * 0.015, lat * 20.0)) * 0.06;

	float b1 = sin((lat + turb) * 22.0) * 0.5 + 0.5;
	float b2 = cos((lat - turb * 0.6) * 11.0 + 1.2) * 0.5 + 0.5;

	vec3 surface = mix(band_color_a, band_color_b, b1);
	surface = mix(surface, band_color_c, smoothstep(0.62, 0.92, b2) * 0.55);

	// Grande Mancha da Cepa (vórtice oval no hemisfério sul)
	vec2 spot_d = vec2( fract((lon + TIME * 0.01) / 6.28318) - 0.5, lat + 0.24 ) * vec2(3.2, 7.5);
	float spot = smoothstep(0.45, 0.05, length(spot_d));
	surface = mix(surface, vec3(0.95, 0.52, 0.32), spot * 0.65);

	// Iluminação solar (fase do planeta) + faixa sutil de sombra dos anéis
	float ndotl = dot(world_normal, normalize(sun_dir));
	float lit = smoothstep(-0.12, 0.22, ndotl);
	float ring_shadow = 1.0 - 0.35 * exp(-pow((lat - 0.08) * 18.0, 2.0));

	// Brilho atmosférico na borda (Fresnel)
	float view_dot = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - view_dot, 2.8) * smoothstep(-0.05, 0.35, ndotl);
	vec3 atmo_glow = vec3(0.48, 0.82, 0.95) * rim * 0.55;

	vec3 col = mix(night_side_color, surface * ring_shadow + atmo_glow, lit);
	ALBEDO = col;
	ALPHA = sky_fade * mix(0.28, 0.98, lit);
}
