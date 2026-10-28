class_name Campfire
extends Node3D

## Fogueira de descanso (GDD-10 §10.2): a até 4 m dela, sentado, a Vida volta a 2%/s e conta
## para o buff Descansado. Uso público: qualquer jogador descansa na fogueira de outro.
## A mesma fogueira serve a peça construída (BuildablePiece.FOGUEIRA) e a do acampamento da vila.

## Acesa (a fogueira do slice não apaga; lenha e chuva ficam para depois)
@export var lit: bool = true

var _flames: Array[CPUParticles3D] = []  # chama, fagulhas e fumaça
var _embers_bed: MeshInstance3D
var _light: OmniLight3D
var _t: float = 0.0

func _ready() -> void:
	add_to_group("rest_fires")
	_build()

func _build() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.42, 0.4, 0.38)
	stone.roughness = 1.0
	for i in 8:
		var a := TAU * i / 8.0
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.13
		sm.height = 0.16
		sm.radial_segments = 7
		sm.rings = 3
		s.mesh = sm
		s.material_override = stone
		s.position = Vector3(cos(a) * 0.42, 0.05, sin(a) * 0.42)
		add_child(s)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.2, 0.11)
	for i in 3:
		var stick := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.045
		cm.bottom_radius = 0.05
		cm.height = 0.62
		cm.radial_segments = 6
		stick.mesh = cm
		stick.material_override = wood
		stick.position = Vector3(0, 0.08, 0)
		stick.rotation = Vector3(deg_to_rad(80.0), TAU * i / 3.0, 0)
		add_child(stick)
	# Brasa no meio da lenha: o que fica quando a chama baixa
	_embers_bed = MeshInstance3D.new()
	var bed := SphereMesh.new()
	bed.radius = 0.2
	bed.height = 0.1
	bed.radial_segments = 8
	bed.rings = 3
	_embers_bed.mesh = bed
	var bed_mat := StandardMaterial3D.new()
	bed_mat.albedo_color = Color(0.15, 0.05, 0.02)
	bed_mat.emission_enabled = true
	bed_mat.emission = Color(1.0, 0.35, 0.08)
	bed_mat.emission_energy_multiplier = 2.5
	_embers_bed.material_override = bed_mat
	_embers_bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_embers_bed.position.y = 0.06
	add_child(_embers_bed)
	_flames.append(_make_flame())
	_flames.append(_make_sparks())
	_flames.append(_make_smoke())
	for p in _flames:
		add_child(p)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.62, 0.3)
	_light.omni_range = 7.0
	_light.omni_attenuation = 1.3
	_light.light_energy = 1.6
	_light.position.y = 0.6
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = 50.0
	_light.distance_fade_length = 20.0
	add_child(_light)
	# Não se atravessa o fogo
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = 0.4
	col.shape = shape
	col.position.y = 0.2
	body.add_child(col)
	add_child(body)
	_set_lit_visuals()

func _set_lit_visuals() -> void:
	for f in _flames:
		f.emitting = lit
		f.visible = lit
	if _embers_bed:
		_embers_bed.visible = lit
	if _light:
		_light.visible = lit

## Mesmo desenho de partícula da chama da tocha (TorchComponent), em escala de fogueira.
static var _soft_dot: GradientTexture2D

## Mancha redonda de borda suave: sem ela a partícula aparece como um quadrado.
static func _soft_texture() -> GradientTexture2D:
	if _soft_dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.75))
		_soft_dot = GradientTexture2D.new()
		_soft_dot.gradient = g
		_soft_dot.fill = GradientTexture2D.FILL_RADIAL
		_soft_dot.fill_from = Vector2(0.5, 0.5)
		_soft_dot.fill_to = Vector2(0.5, 0.0)
		_soft_dot.width = 64
		_soft_dot.height = 64
	return _soft_dot

static func _particle_quad(size: Vector2, additive: bool) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = size
	var m := StandardMaterial3D.new()
	m.albedo_texture = _soft_texture()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	if additive:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = m
	return quad

static func _curve(start: float, end: float) -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, start))
	c.add_point(Vector2(1, end))
	return c

static func _ramp(from: Color, mid: Color, to: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, from)
	g.set_color(1, to)
	g.add_point(0.4, mid)
	return g

func _make_flame() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Flame"
	p.amount = 28
	p.lifetime = 0.6
	p.local_coords = false
	p.position.y = 0.14
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.13
	p.direction = Vector3.UP
	p.spread = 10.0
	p.gravity = Vector3(0, 1.4, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.6
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.2
	p.scale_amount_curve = _curve(1.0, 0.1)
	p.color_ramp = _ramp(Color(1.0, 0.75, 0.3, 0.55), Color(1.0, 0.42, 0.1, 0.45), Color(0.6, 0.1, 0.02, 0.0))
	p.mesh = _particle_quad(Vector2(0.32, 0.42), true)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

func _make_sparks() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Sparks"
	p.amount = 8
	p.lifetime = 1.4
	p.local_coords = false
	p.position.y = 0.3
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0, 0.4, 0)
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.2
	p.damping_min = 0.4
	p.damping_max = 0.8
	p.scale_amount_curve = _curve(1.0, 0.0)
	p.color_ramp = _ramp(Color(1.0, 0.8, 0.35, 1.0), Color(1.0, 0.45, 0.1, 1.0), Color(0.8, 0.2, 0.05, 0.0))
	p.mesh = _particle_quad(Vector2(0.035, 0.035), true)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

## Fumaça com luz (não aditiva): de dia é cinza, à noite pega o laranja da própria fogueira.
func _make_smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Smoke"
	p.amount = 10
	p.lifetime = 3.5
	p.local_coords = false
	p.position.y = 0.75
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.1
	p.direction = Vector3.UP
	p.spread = 8.0
	p.gravity = Vector3(0.15, 0.25, 0)  # vento leve
	p.initial_velocity_min = 0.35
	p.initial_velocity_max = 0.55
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.scale_amount_curve = _curve(0.4, 1.0)
	p.color_ramp = _ramp(Color(0.45, 0.43, 0.42, 0.0), Color(0.42, 0.4, 0.4, 0.42), Color(0.5, 0.5, 0.5, 0.0))
	p.mesh = _particle_quad(Vector2(0.7, 0.7), false)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

## Luz tremendo (só desenho; a regra de descanso lê `lit`)
func _process(delta: float) -> void:
	if not lit:
		return
	_t += delta
	_light.light_energy = 1.5 + sin(_t * 11.0) * 0.15 + sin(_t * 27.0) * 0.08
