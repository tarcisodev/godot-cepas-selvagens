class_name Campfire
extends Node3D

## Fogueira de descanso (GDD-10 §10.2): a até 4 m dela, sentado, a Vida volta a 2%/s e conta
## para o buff Descansado. Uso público: qualquer jogador descansa na fogueira de outro.
## A mesma fogueira serve a peça construída (BuildablePiece.FOGUEIRA) e a do acampamento da vila.

## Acesa (a fogueira do slice não apaga; lenha e chuva ficam para depois)
@export var lit: bool = true

var _flames: Array[MeshInstance3D] = []
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
	for i in 2:
		var flame := MeshInstance3D.new()
		var fm := CylinderMesh.new()
		fm.top_radius = 0.0
		fm.bottom_radius = 0.17 - i * 0.06
		fm.height = 0.55 - i * 0.15
		fm.radial_segments = 7
		flame.mesh = fm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.55, 0.15) if i == 0 else Color(1.0, 0.85, 0.35)
		flame.material_override = m
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.position = Vector3(0, 0.12 + fm.height * 0.5, 0)
		add_child(flame)
		_flames.append(flame)
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
		f.visible = lit
	if _light:
		_light.visible = lit

## Chama tremendo (só desenho; a regra de descanso lê `lit`)
func _process(delta: float) -> void:
	if not lit:
		return
	_t += delta
	for i in _flames.size():
		var k := 1.0 + sin(_t * (9.0 + i * 3.0) + i) * 0.08 + sin(_t * 23.0) * 0.04
		_flames[i].scale = Vector3(1.0, k, 1.0)
	_light.light_energy = 1.5 + sin(_t * 11.0) * 0.15 + sin(_t * 27.0) * 0.08
