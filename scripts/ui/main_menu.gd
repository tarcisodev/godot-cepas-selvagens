extends Control
class_name MainMenu

## Tela de título: Continuar (se houver save), Novo jogo, Configurações e Sair.
## Novo jogo passa pela criação de personagem antes de entrar no mundo.
# O fundo é uma captura do vale; as Configurações reaproveitam o PauseMenu.

const BACKGROUND: String = "res://assets/ui/menu_background.png"
const CHARACTER_CREATION: String = "res://scenes/character_creation.tscn"

var continue_button: Button
var settings_menu: PauseMenu
var _confirm_new: ConfirmationDialog

func _ready() -> void:
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

	_confirm_new = ConfirmationDialog.new()
	_confirm_new.title = "Novo jogo"
	_confirm_new.dialog_text = "Começar do zero apaga o progresso salvo ao entrar no mundo. Continuar?"
	_confirm_new.ok_button_text = "Começar do zero"
	_confirm_new.cancel_button_text = "Cancelar"
	_confirm_new.confirmed.connect(_open_character_creation)
	add_child(_confirm_new)

	if continue_button.disabled:
		(continue_button.get_parent().get_child(continue_button.get_index() + 1) as Button).grab_focus()
	else:
		continue_button.grab_focus()

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
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Cepa Selvagem"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.96, 0.9, 0.7))
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Caçe, esfole e forje num vale de alta magia.\nProtótipo jogável (MVP)"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.82, 0.88, 0.8, 0.9))
	box.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	box.add_child(spacer)

	continue_button = _make_button("▶  Continuar", func(): SaveGame.enter_world(true))
	continue_button.disabled = not SaveGame.has_save()
	if not continue_button.disabled and SaveGame.saved_name() != "":
		continue_button.text = "▶  Continuar — %s" % SaveGame.saved_name()
	if continue_button.disabled:
		continue_button.tooltip_text = "Nenhum jogo salvo ainda"
	box.add_child(continue_button)
	box.add_child(_make_button("🌱  Novo jogo", _on_new_game))
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

func _on_new_game() -> void:
	if SaveGame.has_save():
		_confirm_new.popup_centered()
	else:
		_open_character_creation()

func _open_character_creation() -> void:
	get_tree().change_scene_to_file(CHARACTER_CREATION)
