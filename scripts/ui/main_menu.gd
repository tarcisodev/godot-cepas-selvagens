extends Control
class_name MainMenu

## Tela de título: Foco exclusivo em Jogar Online (Beta), Hospedar Servidor, Configurações e Sair.
# O fundo é uma captura do vale; as Configurações reaproveitam o PauseMenu.

const BACKGROUND: String = "res://assets/ui/menu_background.png"
const OnlineAuthModalClass = preload("res://scripts/ui/online_auth_modal.gd")

var play_online_button: Button
var settings_menu: PauseMenu

func _ready() -> void:
	CustomCursor.ensure_installed(get_tree())
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false

	_build_background()
	_build_column()

	# Mesmo arranjo do mundo: o PauseMenu dentro de um CanvasLayer ocupa a tela toda
	var settings_layer := CanvasLayer.new()
	add_child(settings_layer)
	settings_menu = PauseMenu.new()
	settings_menu.in_title_screen = true
	settings_layer.add_child(settings_menu)

	if play_online_button != null:
		play_online_button.grab_focus()

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.13, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	if ResourceLoader.exists(BACKGROUND):
		var tex := TextureRect.new()
		tex.texture = load(BACKGROUND)
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(tex)

	# Escurece a esquerda para o texto ler bem
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.04, 0.03, 0.88))
	grad.set_color(1, Color(0.02, 0.04, 0.03, 0.0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_to = Vector2(1.0, 0.0)
	shade.texture = gtex
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.custom_minimum_size = Vector2(720, 0)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(shade)

func _build_column() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	margin.add_theme_constant_override("margin_left", 80)
	add_child(margin)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(360, 0)
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Cepa Selvagem"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.96, 0.9, 0.7))
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Mundo Aberto Multijogador & Sobrevivência Selvagem\nBeta Online"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.82, 0.88, 0.8, 0.9))
	box.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	box.add_child(spacer)

	play_online_button = _make_button("⚔️  Jogar Online (Entrar)", func(): _open_auth(false))
	box.add_child(play_online_button)
	box.add_child(_make_button("🖥️  Hospedar Servidor no PC", func(): _open_auth(true)))
	box.add_child(_make_button("⚙  Configurações", func(): settings_menu.open_settings()))
	box.add_child(_make_button("🚪  Sair", func(): get_tree().quit()))

	var hint := Label.new()
	hint.text = "WASD andar · Clique atacar/conjurar · C esquivar · E esfolar · Tab forja · K cartas · Esc menu"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.6))
	box.add_child(hint)

func _make_button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(320, 44)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(callback)
	return b

func _open_auth(host_mode: bool) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 25
	add_child(layer)

	var modal: Control = OnlineAuthModalClass.new()
	if "is_host_mode" in modal:
		modal.set("is_host_mode", host_mode)
	layer.add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.tree_exited.connect(func():
		if is_instance_valid(layer):
			layer.queue_free()
	)
