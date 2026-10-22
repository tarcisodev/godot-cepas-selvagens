shader_type spatial;
// Nuvem macia: cada "pufe" é um quadrado virado para a câmera (montado no vértice), com borda
// esfumada por ruído. Topo claro, base mais escura; cor e opacidade vêm do clima.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 top_color = vec3(1.0, 1.0, 1.0);
uniform vec3 base_color = vec3(0.72, 0.75, 0.82);
uniform float opacity = 0.8;
uniform float drift = 0.01;

varying float v_height;
varying vec2 v_seed;

void vertex() {
	// VERTEX = centro do pufe; UV = canto (0..1); UV2 = (tamanho, semente); COLOR.r = altura no bolo
	vec3 center = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX = center + vec3((UV - 0.5) * UV2.x, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_height = COLOR.r;
	v_seed = vec2(UV2.y, UV2.y * 1.7);
}

void fragment() {
	vec2 p = UV - 0.5;
	float d = length(p) * 2.0;
	float n = texture(noise_tex, UV * 0.6 + v_seed + TIME * drift).r;
	float n2 = texture(noise_tex, UV * 1.4 - v_seed * 0.5).r;
	float puff = smoothstep(1.0, 0.25, d + (n - 0.5) * 0.7 + (n2 - 0.5) * 0.3);
	// Luz de cima: mais claro no alto do pufe e no alto da nuvem
	float lit = clamp(v_height * 0.6 + (p.y + 0.5) * 0.5 + n2 * 0.2, 0.0, 1.0);
	ALBEDO = mix(base_color, top_color, lit);
	ALPHA = puff * opacity;
}
