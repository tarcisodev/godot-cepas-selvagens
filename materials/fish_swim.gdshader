shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Natação de peixe sem armature nem blend shapes (estilo ABZU, GDC 2017).
// Portado do "Fish shader" de frankiezafe (MIT, Godot Asset Library #222) para Godot 4.
// O eixo do corpo é o Z local: a máscara head_color -> tail_color ao longo dele
// controla quanto cada vértice sofre de cada deformação (r=twist, g=S, b=yaw, a=translate).

uniform float frequency = 5.0;
uniform float twist_factor = 0.8;
uniform float twist_factor_frequency = -5.0;
uniform float s_factor = 0.08;
uniform float s_factor_frequency = 5.0;
uniform float yaw_factor = 0.25;
uniform vec3 translate = vec3(0.02, 0.0, 0.0);
// Escala espacial da onda ao longo do corpo (o original assume um peixe de ~2 m).
uniform float wave_scale = 4.5;

uniform float head_z = 0.19;
uniform vec4 head_color : source_color = vec4(0.5, 0.14, 0.55, 0.11);
uniform float tail_z = -0.3;
uniform vec4 tail_color : source_color = vec4(1.0);

uniform vec4 albedo : source_color = vec4(1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float specular : hint_range(0.0, 1.0) = 0.5;

// Por instância: desfasa os peixes e acelera a batida conforme a velocidade de nado.
instance uniform float swim_phase = 0.0;
instance uniform float swim_speed = 1.0;

vec2 rotate2(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

void vertex() {
	float t = TIME * swim_speed + swim_phase;
	float tmult = sin(t * frequency);
	float wz = VERTEX.z * wave_scale;

	float ranged_z = clamp((VERTEX.z - head_z) / (tail_z - head_z), 0.0, 1.0);
	vec4 ctrl = mix(head_color, tail_color, ranged_z);

	vec3 pos = VERTEX;
	vec3 nrm = NORMAL;

	// twist (rolagem em torno do eixo do corpo)
	float twist_a = ctrl.r * sin(wz + t * twist_factor_frequency) * twist_factor;
	pos.xy = rotate2(pos.xy, twist_a);
	nrm.xy = rotate2(nrm.xy, twist_a);

	// curva em S que corre da cabeça para a cauda
	pos.x += ctrl.g * sin(wz - t * s_factor_frequency) * s_factor;

	// yaw (o corpo balança de lado)
	float yaw_a = ctrl.b * tmult * yaw_factor;
	pos.xz = rotate2(pos.xz, yaw_a);
	nrm.xz = rotate2(nrm.xz, yaw_a);

	// deslocamento lateral
	pos += ctrl.a * translate * tmult;

	VERTEX = pos;
	NORMAL = normalize(nrm);
}

void fragment() {
	ALBEDO = albedo.rgb * COLOR.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
