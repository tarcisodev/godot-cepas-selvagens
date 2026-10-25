class_name Campfire
extends Node3D

const _Player = preload("res://scripts/player.gd")
const _RoastSpitMinigame = preload("res://scripts/ui/roast_spit_minigame.gd")

## Fogueira de descanso e assado (GDD-10 §10.2 e GDD-13 §2):
## - A até 4 m dela, sentado, a Vida volta a 2%/s e conta para o buff Descansado.
## - [E] abre o minigame do espeto para assar carnes cruas ou peixes.
## Uso público: qualquer jogador descansa e assa na fogueira de outro.
## A mesma fogueira serve a peça construída (BuildablePiece.FOGUEIRA) e a do acampamento da vila.

const USE_RANGE: float = 3.5

## Acesa (a fogueira do slice não apaga; lenha e chuva ficam para depois)
@export var lit: bool = true

var _flames: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _t: float = 0.0
var _prompt: Label3D
var _minigame: _RoastSpitMinigame

func _ready() -> void:
	add_to_group("rest_fires")
	add_to_group("talkable")
	_build()
	_setup_minigame()

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

func _setup_minigame() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_minigame = _RoastSpitMinigame.new()
	layer.add_child(_minigame)

	_prompt = Label3D.new()
	_prompt.text = "🔥 [E] Assar Carne (Espeto)"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 14
	_prompt.outline_size = 4
	_prompt.modulate = Color(1.0, 0.75, 0.35)
	_prompt.position.y = 1.1
	_prompt.visible = false
	add_child(_prompt)

func _set_lit_visuals() -> void:
	for f in _flames:
		f.visible = lit
	if _light:
		_light.visible = lit

func talk_to(player_node: Node) -> void:
	if _minigame:
		_minigame.open(player_node as _Player)

## Chama tremendo e monitora proximidade do jogador
func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D if is_inside_tree() else null
	if _prompt:
		_prompt.visible = lit and player != null and player.global_position.distance_to(global_position) < USE_RANGE

	if not lit:
		return
	_t += delta
	for i in _flames.size():
		var k := 1.0 + sin(_t * (9.0 + i * 3.0) + i) * 0.08 + sin(_t * 23.0) * 0.04
		_flames[i].scale = Vector3(1.0, k, 1.0)
	_light.light_energy = 1.5 + sin(_t * 11.0) * 0.15 + sin(_t * 27.0) * 0.08
