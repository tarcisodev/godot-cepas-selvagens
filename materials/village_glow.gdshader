shader_type spatial;
render_mode cull_disabled;

// Lâmpadas e lanternas da vila (B36): uma MultiMesh só, cor por instância. `energy` sobe à noite
// (o CityHub ajusta pelo relógio único) e cada lâmpada tremula um pouco no próprio ritmo.

uniform float energy = 0.3;

varying float seed;

void vertex() {
	seed = fract(sin(float(INSTANCE_ID) * 12.9898 + 1.7) * 43758.5453);
}

void fragment() {
	float flicker = 0.9 + 0.1 * sin(TIME * (2.0 + seed * 3.0) + seed * 40.0);
	ALBEDO = COLOR.rgb * 0.35;
	EMISSION = COLOR.rgb * energy * flicker;
	ROUGHNESS = 0.4;
}
