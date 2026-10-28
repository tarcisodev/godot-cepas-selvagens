extends Control
class_name AgeGate

## Tela de classificação 18+ (B34): aparece antes do primeiro menu, uma vez por dispositivo.
# "Tenho 18 anos ou mais" grava `legal/age_confirmed` no GameSettings e segue para o menu;
# "Sair" fecha o jogo (na web volta para a página anterior). Não guarda data de nascimento.

const BACKGROUND: String = "res://assets/ui/menu_background.png"
const MAIN_MENU_SCENE: String = "res://scenes/main_menu.tscn"
const SCENE_PATH: String = "res://scenes/ui/age_gate.tscn"

const WARNING_TEXT: String = "Cepas Selvagens contém uso de drogas, violência e temas adultos. É destinado a maiores de 18 anos."
const ACCEPT_TEXT: String = "Tenho 18 anos ou mais"
const EXIT_TEXT: String = "Sair"

signal accepted()
signal exited()

var accept_button: Button
var exit_button: Button
## Testes desligam a troca de cena e o quit
var auto_navigate: bool = true

## true se o dispositivo ainda não confirmou a idade
static func is_needed(settings: Node) -> bool:
	if settings == null or not settings.has_method("get_value"):
		return true
	return not bool(settings.get_value("legal", "age_confirmed"))

## Próxima cena depois do splash: a tela 18+ se faltar a confirmação, senão o menu
static func scene_after_splash(settings: Node) -> String:
	return SCENE_PATH if is_needed(settings) else MAIN_MENU_SCENE

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_ui()
	if accept_button:
		accept_button.grab_focus()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.05)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if ResourceLoader.exists(BACKGROUND):
		var tex := TextureRect.new()
		tex.texture = load(BACKGROUND)
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex.modulate = Color(0.3, 0.3, 0.3)
		add_child(tex)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.05, 0.92)
	style.border_color = Color(0.85, 0.3, 0.75, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.custom_minimum_size = Vector2(520, 0)
	panel.add_child(box)

	var badge := Label.new()
	badge.text = "18+"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 54)
	badge.add_theme_color_override("font_color", Color(0.95, 0.35, 0.8))
	box.add_child(badge)

	var msg := Label.new()
	msg.text = WARNING_TEXT
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 18)
	msg.add_theme_color_override("font_color", Color(0.93, 0.9, 0.82))
	box.add_child(msg)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)

	accept_button = Button.new()
	accept_button.name = "AcceptButton"
	accept_button.text = ACCEPT_TEXT
	accept_button.custom_minimum_size = Vector2(240, 48)
	accept_button.pressed.connect(accept)
	row.add_child(accept_button)

	exit_button = Button.new()
	exit_button.name = "ExitButton"
	exit_button.text = EXIT_TEXT
	exit_button.custom_minimum_size = Vector2(140, 48)
	exit_button.pressed.connect(exit_game)
	row.add_child(exit_button)

## Confirma a idade: grava no GameSettings (persistente) e segue para o menu
func accept() -> void:
	var settings := get_node_or_null("/root/GameSettings")
	if settings:
		settings.set_value("legal", "age_confirmed", true)
		settings.save()
	accepted.emit()
	if auto_navigate and is_inside_tree():
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)

## Sair: fecha o jogo; na web volta para a página anterior
func exit_game() -> void:
	exited.emit()
	if not auto_navigate:
		return
	if OS.has_feature("web"):
		JavaScriptBridge.eval("history.back()")
	else:
		get_tree().quit()
