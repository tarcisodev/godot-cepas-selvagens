shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Corrente de vento sob a ilha voadora (GDD-18 §4): faixas claras subindo, mais fortes de lado
// (borda do tubo) e sumindo perto do chão e no topo.

uniform vec4 tint : source_color = vec4(0.88, 0.94, 1.0, 1.0);
uniform float strength = 0.09;
uniform float speed = 0.25;

void fragment() {
	float ends = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.8, UV.y);
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	float streak = 0.55 + 0.45 * sin((UV.x * 18.0) + (UV.y * 6.0 + TIME * speed) * 6.2831);
	ALBEDO = tint.rgb;
	ALPHA = strength * ends * (0.35 + rim) * streak;
}
