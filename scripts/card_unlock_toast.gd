class_name CardUnlockToast
extends CanvasLayer

## Anúncio de carta recém-descoberta (B08): a carta cai de costas, vira revelando a arte
## com uma explosão de luz na cor da raridade e some sozinha. Descobertas seguidas entram em fila.

signal toast_finished(card: CardData)

const CARD_BACK_TEXTURE: Texture2D = preload("res://assets/cards_3d/card_kit/Renders/0_CardBack.png")
const HOLD_SECONDS := 2.8

@export var sfx: CardAlbumSfx

var _queue: Array[CardData] = []
var _showing: bool = false
var _tween: Tween

var _root: Control
var _panel: PanelContainer
var _art: TextureRect
var _burst: ColorRect
var _title: Label
var _meta: Label

func _ready() -> void:
	_setup_nodes()
	_root.visible = false

func _setup_nodes() -> void:
	if _root == null:
		_root = get_node_or_null("Root") as Control
		_panel = get_node_or_null("%Panel") as PanelContainer
		_art = get_node_or_null("%Art") as TextureRect
		_burst = get_node_or_null("%Burst") as ColorRect
		_title = get_node_or_null("%CardTitle") as Label
		_meta = get_node_or_null("%Meta") as Label

## Enfileira o anúncio de uma carta
func announce(card: CardData) -> void:
	if card == null:
		return
	_queue.append(card)
	if not _showing:
		_show_next()

func is_showing() -> bool:
	return _showing

func pending_count() -> int:
	return _queue.size()

func _show_next() -> void:
	_setup_nodes()
	if _queue.is_empty() or _root == null:
		_showing = false
		return
	_showing = true
	var card: CardData = _queue.pop_front()
	var color := card.get_rarity_color()

	_title.text = card.title
	_meta.text = "%s  •  %s  •  %s" % [card.get_rarity_name(), card.get_element_name(), card.category]
	_meta.add_theme_color_override("font_color", color.lightened(0.15))
	var style := _panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = color
	style.shadow_color = Color(color.r, color.g, color.b, 0.3)
	_panel.add_theme_stylebox_override("panel", style)
	(_burst.material as ShaderMaterial).set_shader_parameter("glow_color", color)

	_art.texture = CARD_BACK_TEXTURE
	_art.scale = Vector2(0.3, 0.3)
	_art.rotation = -0.35
	_burst.modulate.a = 0.0
	_burst.scale = Vector2(0.4, 0.4)
	_root.visible = true
	_root.modulate.a = 0.0
	_root.position.y = -40.0

	if _tween:
		_tween.kill()
	_tween = create_tween()
	# Entrada: painel desce, carta cai girando
	_tween.tween_callback(_play.bind(&"unlock_whoosh"))
	_tween.tween_property(_root, "modulate:a", 1.0, 0.2)
	_tween.parallel().tween_property(_root, "position:y", 26.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_art, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_art, "rotation", 0.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Virada: fecha no eixo X, troca para a arte e abre com a explosão
	_tween.tween_interval(0.15)
	_tween.tween_property(_art, "scale:x", 0.0, 0.12).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_reveal.bind(card))
	_tween.tween_property(_art, "scale:x", 1.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_burst, "modulate:a", 1.0, 0.15)
	_tween.parallel().tween_property(_burst, "scale", Vector2(1.25, 1.25), 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_burst, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(_burst, "modulate:a", 0.55, 0.5)
	# Permanência e saída
	_tween.tween_interval(HOLD_SECONDS)
	_tween.tween_property(_root, "modulate:a", 0.0, 0.35)
	_tween.parallel().tween_property(_root, "position:y", 10.0, 0.35)
	_tween.tween_callback(_finish.bind(card))

func _reveal(card: CardData) -> void:
	if not card.render_path.is_empty() and ResourceLoader.exists(card.render_path):
		_art.texture = load(card.render_path) as Texture2D
	_play(&"unlock_reveal")
	if card.rarity >= CardData.Rarity.LEGENDARY:
		_play(&"unlock_legendary")

func _finish(card: CardData) -> void:
	_root.visible = false
	toast_finished.emit(card)
	_show_next()

func _play(id: StringName) -> void:
	if sfx:
		sfx.play(id, 0.03)
