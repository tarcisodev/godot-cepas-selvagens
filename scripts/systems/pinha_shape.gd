class_name PinhaShape
extends RefCounted

## Pinha-Lume procedural (GDD-10 §9) e o material que acende à noite.
## Pinha Fibonacci: as escamas seguem o ângulo de ouro (137,5°), e as cores alternadas
## revelam as espirais de 8 e 13. Pinha mandala: anéis de latitude com `simetria` escamas,
## cada anel deslocado meio passo, e uma estrela no topo.
## A pinha unitária tem ~1 m de altura, eixo +Y, centro na origem; `xform` a põe no mundo.

static var _glow: ShaderMaterial

const GLOW_SHADER := """
shader_type spatial;
// Cor por vértice; o alfa é a força do brilho (gene `brilho`). `night` vem da Ecology.
uniform float night = 0.0;
void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = c * 0.8;
	ROUGHNESS = 0.55;
	EMISSION = c * COLOR.a * (0.12 + night * 2.6);
}
"""

## Material único das partes que brilham (pontas dos galhos, pinhas, broto)
static func glow_material() -> ShaderMaterial:
	if _glow == null:
		var sh := Shader.new()
		sh.code = GLOW_SHADER
		_glow = ShaderMaterial.new()
		_glow.shader = sh
	return _glow

## 0 de dia, 1 de noite (a Ecology chama a cada frame)
static func set_night(v: float) -> void:
	glow_material().set_shader_parameter("night", v)

## Escamas vão em `glow` (cor do lume, alfa = brilho); o miolo escuro vai em `base`
static func append(glow: MeshBatch, base: MeshBatch, dna: PlantDNA, xform: Transform3D) -> void:
	var lume := dna.lume_color()
	var a := dna.glow_strength()
	var tones: Array[Color] = [lume.darkened(0.45), lume, lume.lightened(0.4)]
	for i in tones.size():
		tones[i].a = a
	if base:
		_add(base, xform * Transform3D(Basis.IDENTITY.scaled(Vector3(0.62, 0.9, 0.62)), Vector3.ZERO), Color(0.22, 0.16, 0.12))
	if dna.is_fibonacci():
		_fibonacci(glow, dna.escamas, xform, tones)
	else:
		_mandala(glow, dna.simetria, xform, tones)

static func _fibonacci(glow: MeshBatch, n: int, xform: Transform3D, tones: Array[Color]) -> void:
	var size := 0.66 * sqrt(21.0 / n)
	for i in n:
		var y := 1.0 - 2.0 * (i + 0.5) / n
		var ring := sqrt(maxf(0.0, 1.0 - y * y))
		var ang := i * PlantDNA.GOLDEN_ANGLE
		var normal := Vector3(cos(ang) * ring, y * 0.6, sin(ang) * ring).normalized()
		var pos := Vector3(cos(ang) * ring * 0.34 * (1.0 + 0.12 * y), y * 0.46, sin(ang) * ring * 0.34 * (1.0 + 0.12 * y))
		var s := size * (0.45 + 0.55 * ring)
		# Escamas com o mesmo i % 13 formam um braço de espiral: braços alternam claro/escuro,
		# e a espiral de 8 (vizinha de Fibonacci) ganha o tom mais claro
		var tone := 2 if i % 8 == 0 else (i % 13) % 2
		_add(glow, xform * _scale_xform(pos, normal, Vector3(s * 0.6, s * 0.48, s * 0.14)), tones[tone])

static func _mandala(glow: MeshBatch, sym: int, xform: Transform3D, tones: Array[Color]) -> void:
	var rings := 5
	for k in rings:
		var theta := (k + 0.6) / float(rings) * PI * 0.9
		var count := sym if k < rings - 1 else maxi(3, sym / 2)
		var r := 0.34 * sin(theta)
		var width := TAU * r / count * 1.2
		for j in count:
			var ang := (j + 0.5 * (k % 2)) / float(count) * TAU
			var normal := Vector3(sin(theta) * cos(ang), cos(theta), sin(theta) * sin(ang))
			var pos := Vector3(r * cos(ang), 0.46 * cos(theta), r * sin(ang))
			_add(glow, xform * _scale_xform(pos, normal, Vector3(width, 0.3, 0.07)), tones[(k + 1) % 3])
	# Estrela no topo e miolo aceso: o desenho da mandala visto de cima
	for j in sym:
		var ang := j / float(sym) * TAU
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		_add(glow, xform * _scale_xform(Vector3(0, 0.47, 0) + dir * 0.09, (dir * 0.4 + Vector3.UP).normalized(), Vector3(0.05, 0.13, 0.03)), tones[2])
	_add(glow, xform * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.07), Vector3(0, 0.5, 0)), tones[2])

## Escama achatada virada para `normal`
static func _scale_xform(pos: Vector3, normal: Vector3, size: Vector3) -> Transform3D:
	var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	return Transform3D(Basis.looking_at(normal, up) * Basis.from_scale(size), pos) # escala local

static func _add(batch: MeshBatch, xform: Transform3D, color: Color) -> void:
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	batch.append(MeshBatch.arrays_of(sm, "pinha_scale"), xform, color)
