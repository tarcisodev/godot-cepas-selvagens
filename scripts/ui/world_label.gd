class_name WorldLabel
extends Label3D

## Rótulo do mundo com uma regra só (B25): mesmo tamanho e contorno para tudo, e o que aparece
## depende da distância até o jogador.
## - NAME: nome inteiro até NEAR; de NEAR a FAR só o ícone; além disso, nada.
## - PROMPT ("[E] …"): só o do alvo em foco — o mais perto do jogador dentro do alcance e à
##   frente da câmera. Os outros ficam escondidos.
## - SIGN: placa de lugar; texto inteiro até `sign_range`.
## O dono liga e desliga com `active`; quem mexe em `visible` é o próprio rótulo.

enum Kind { NAME, PROMPT, SIGN }

const NEAR := 6.0
const FAR := 15.0
const FADE := 0.7  # metros de transição (sem estalo ao trocar nome ↔ ícone)
const FONT_SIZE := 40
const PIXEL_SIZE := 0.0022  # ~9 cm de letra
const SIGN_PIXEL_SIZE := 0.004
const OUTLINE := 12
const COLORS := {
	Kind.NAME: Color(1.0, 0.94, 0.78),
	Kind.PROMPT: Color(1.0, 0.86, 0.45),
	Kind.SIGN: Color(1.0, 0.88, 0.6),
}
const PROMPT_GROUP := &"world_prompts"
const NAME_GROUP := &"world_names"
## Na praça cheia, só os nomes mais perto aparecem por extenso; os outros ficam no ícone
const MAX_NEAR_NAMES := 3

@export var kind: Kind = Kind.NAME
## Ícone que fica no lugar do nome entre NEAR e FAR (vazio: some junto com o nome)
@export var icon: String = ""
## Alcance do PROMPT (mesmo do [E] do jogador por padrão)
@export var use_range: float = 2.6
## Até onde a placa (SIGN) é lida
@export var sign_range: float = 30.0
## Desligado pelo dono (fora de uso, menu aberto, coletado…)
@export var active: bool = true

const SLEEP_MARGIN := 6.0  # a 6 m/s de corrida, 20 quadros dão ~2 m: acorda antes de precisar
const SLEEP_FRAMES := 20

var full_text: String = ""
var _sleep: int = 0

static var _focus: WorldLabel = null
static var _focus_frame: int = -1
static var _viewer_pos: Vector3
static var _viewer_frame: int = -1
static var _near_names: Array = []
static var _near_frame: int = -1

## Atalho para criar por código.
static func make(k: Kind, txt: String, ico: String = "", tint: Color = Color(0, 0, 0, 0)) -> WorldLabel:
	var l := WorldLabel.new()
	l.kind = k
	l.icon = ico
	l.full_text = txt
	l.text = txt
	if tint.a > 0.0:
		l.modulate = tint
	return l

## Troca um Label3D de cena (.tscn) por um WorldLabel no mesmo lugar e com o mesmo texto.
static func replace(old: Label3D, k: Kind, ico: String = "") -> WorldLabel:
	var l := make(k, old.text, ico)
	l.name = old.name
	l.transform = old.transform
	var parent := old.get_parent()
	parent.remove_child(old)
	old.queue_free()
	parent.add_child(l)
	return l

func _ready() -> void:
	if full_text.is_empty():
		full_text = text
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	font_size = FONT_SIZE
	pixel_size = SIGN_PIXEL_SIZE if kind == Kind.SIGN else PIXEL_SIZE
	outline_size = OUTLINE
	outline_modulate = Color(0, 0, 0, 0.85)
	visibility_range_end = 0.0  # a distância é regra deste script, não do motor
	if modulate == Color.WHITE:  # sem cor própria do dono: cor do tipo
		modulate = COLORS[kind]
	if kind == Kind.PROMPT:
		add_to_group(PROMPT_GROUP)
	elif kind == Kind.NAME:
		add_to_group(NAME_GROUP)
	_update()

## Troca o texto (use no lugar de `text =`, que é reescrito a cada quadro).
func set_full_text(txt: String) -> void:
	full_text = txt

func _process(_delta: float) -> void:
	if _sleep > 0:
		_sleep -= 1
		return
	_update()

func _update() -> void:
	if not active or not is_inside_tree():
		visible = false
		return
	var d := _flat_distance(_viewer_position(), global_position)
	# Longe de tudo (a maioria dos [E] de coleta do mapa): dorme alguns quadros
	var reach := sign_range if kind == Kind.SIGN else (use_range if kind == Kind.PROMPT else FAR)
	if d > reach + SLEEP_MARGIN:
		visible = false
		_sleep = SLEEP_FRAMES + (get_instance_id() % 7)  # espalha quem acorda em cada quadro
		return
	var a := 0.0
	match kind:
		Kind.NAME:
			if d < NEAR and _is_near_name():
				text = full_text
				a = clampf((NEAR - d) / FADE, 0.0, 1.0)
			elif not icon.is_empty():
				text = icon
				# de perto (fora dos 3 mais próximos) o ícone fica inteiro; perto de 6 m faz a troca
				var fade_in := 1.0 if d < NEAR - FADE else clampf(absf(d - NEAR) / FADE, 0.0, 1.0)
				a = minf(fade_in, clampf((FAR - d) / FADE, 0.0, 1.0))
		Kind.PROMPT:
			text = full_text
			if _focused_prompt() == self:
				# Proximity fade suave: surge gradualmente nos últimos metros até o alvo
				var prompt_fade_dist: float = minf(FADE, use_range * 0.45)
				a = clampf((use_range - d) / prompt_fade_dist, 0.0, 1.0)
			else:
				a = 0.0
		Kind.SIGN:
			text = full_text
			a = clampf((sign_range - d) / (FADE * 4.0), 0.0, 1.0)
	visible = a > 0.0
	modulate.a = a
	outline_modulate.a = 0.85 * a

## Só no chão: o rótulo fica ~2 m acima de quem ele nomeia.
static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

## Distância conta do jogador (é ele que interage); sem jogador, da câmera.
func _viewer_position() -> Vector3:
	var frame := Engine.get_process_frames()
	if _viewer_frame == frame:
		return _viewer_pos
	_viewer_frame = frame
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		_viewer_pos = player.global_position
	else:
		var cam := get_viewport().get_camera_3d()
		_viewer_pos = cam.global_position if cam else global_position
	return _viewer_pos

## Escolhe uma vez por quadro o único PROMPT que aparece.
static func _focused_prompt_in(tree: SceneTree, viewer: Vector3, cam: Camera3D) -> WorldLabel:
	var best: WorldLabel = null
	var best_d := INF
	for node in tree.get_nodes_in_group(PROMPT_GROUP):
		var l := node as WorldLabel
		if l == null or not l.active or not l.is_inside_tree():
			continue
		var d := _flat_distance(viewer, l.global_position)
		if d > l.use_range or d >= best_d:
			continue
		if cam and (l.global_position - cam.global_position).dot(-cam.global_basis.z) <= 0.0:
			continue
		best = l
		best_d = d
	return best

## Os MAX_NEAR_NAMES nomes ativos mais perto do jogador dentro de NEAR (uma vez por quadro).
func _is_near_name() -> bool:
	var frame := Engine.get_process_frames()
	if _near_frame != frame:
		_near_frame = frame
		var viewer := _viewer_position()
		var cam := get_viewport().get_camera_3d()
		var near: Array = []
		for node in get_tree().get_nodes_in_group(NAME_GROUP):
			var l := node as WorldLabel
			if l == null or not l.active or not l.is_inside_tree():
				continue
			if cam and (l.global_position - cam.global_position).dot(-cam.global_basis.z) <= 0.0:
				continue  # atrás da câmera não ocupa vaga
			var d := _flat_distance(viewer, l.global_position)
			if d < NEAR:
				near.append([d, l])
		near.sort_custom(func(x, y): return x[0] < y[0])
		_near_names = near.slice(0, MAX_NEAR_NAMES).map(func(e): return e[1])
	return _near_names.has(self)

func _focused_prompt() -> WorldLabel:
	var frame := Engine.get_process_frames()
	if _focus_frame != frame:
		_focus_frame = frame
		_focus = _focused_prompt_in(get_tree(), _viewer_position(), get_viewport().get_camera_3d())
	return _focus
