shader_type canvas_item;

// Arte de carta ainda não descoberta: tons de cinza escuros, quase uma silhueta.

uniform float brightness = 0.32;
uniform vec3 shade : source_color = vec3(0.05, 0.055, 0.08);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(shade + vec3(g) * brightness, c.a);
}
