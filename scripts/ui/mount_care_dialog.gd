class_name MountCareDialog
extends Control

## Tela da montaria própria (GDD-16): mostra nome, índole e Elo, e oferece montar, alimentar,
## cuidar no estábulo, escolher a Companheira, dar a ordem Seguir/Ficar e batizar.
## O mundo continua rodando enquanto a tela está aberta (nada de pausa).

## &"montar", &"alimentar", &"cuidar", &"companheira", &"ordem", &"batizar" (text = nome), &"fechar"
signal chosen(choice: StringName, text: String)

const TEXT := Color(0.92, 0.92, 0.95)
const TEXT_DIM := Color(0.62, 0.64, 0.7)
const GOLD := Color(0.95, 0.78, 0.35)

var _title: Label
var _info: Label
var _elo_bar: ProgressBar
var _next: Label
var _buttons: Dictionary = {}
var _name_edit: LineEdit

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.add_theme_stylebox_override("panel", _box(Color(0.08, 0.08, 0.07, 0.95), Color(GOLD.r, GOLD.g, GOLD.b, 0.4), 14, 1, Vector2(24, 20)))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	_title = _label(col, 22, TEXT)
	_info = _label(col, 14, TEXT_DIM)
	_elo_bar = ProgressBar.new()
	_elo_bar.max_value = MountBond.ELO_MAX
	_elo_bar.custom_minimum_size = Vector2(0, 18)
	_elo_bar.show_percentage = false
	var fill := _box(GOLD, GOLD, 6, 0)
	_elo_bar.add_theme_stylebox_override("fill", fill)
	_elo_bar.add_theme_stylebox_override("background", _box(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.12), 6, 1))
	col.add_child(_elo_bar)
	_next = _label(col, 13, TEXT_DIM)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	col.add_child(name_row)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 16
	_name_edit.placeholder_text = "Nome da montaria"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_submitted.connect(func(t): _choose(&"batizar", t))
	name_row.add_child(_name_edit)
	_buttons[&"batizar"] = _add_button(name_row, "✏️  Batizar", &"batizar")
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	col.add_child(list)
	for spec in [[&"montar", "🐾  Montar (1,5 s parado)"], [&"alimentar", ""], [&"cuidar", ""], [&"companheira", ""], [&"ordem", ""], [&"fechar", "✖  Fechar"]]:
		_buttons[spec[0]] = _add_button(list, spec[1], spec[0])

## state: montado pelo EcosystemSpawner (title, info, elo, next, feed, care, companion, order)
func ask(state: Dictionary) -> void:
	_title.text = state.get("title", "")
	_info.text = state.get("info", "")
	_elo_bar.value = float(state.get("elo", 0.0))
	_next.text = state.get("next", "")
	_name_edit.text = state.get("name", "")
	_set_button(&"alimentar", state.get("feed", ["", false]))
	_set_button(&"cuidar", state.get("care", ["", false]))
	_set_button(&"companheira", state.get("companion", ["", false]))
	_set_button(&"ordem", state.get("order", ["", false]))
	_buttons[&"ordem"].visible = state.get("order", ["", false])[0] != ""
	visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close() -> void:
	if not visible:
		return
	visible = false
	remove_from_group("open_menus")
	_name_edit.release_focus()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _set_button(choice: StringName, spec: Array) -> void:
	var b: Button = _buttons[choice]
	b.text = spec[0]
	b.disabled = not spec[1]

func _choose(choice: StringName, text: String = "") -> void:
	if choice == &"batizar":
		text = _name_edit.text
	# Batizar e alimentar deixam a tela aberta (o spawner reabre com o estado novo)
	close()
	chosen.emit(choice, text)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_choose(&"fechar")

func _label(parent: Node, size: int, color: Color) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

func _add_button(parent: Node, text: String, choice: StringName) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, TEXT)
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.48))
	b.add_theme_stylebox_override("normal", _box(Color(GOLD.r, GOLD.g, GOLD.b, 0.1), Color(GOLD.r, GOLD.g, GOLD.b, 0.45), 10, 1, Vector2(14, 10)))
	b.add_theme_stylebox_override("hover", _box(Color(GOLD.r, GOLD.g, GOLD.b, 0.22), GOLD, 10, 1, Vector2(14, 10)))
	b.add_theme_stylebox_override("pressed", _box(Color(GOLD.r, GOLD.g, GOLD.b, 0.3), GOLD, 10, 1, Vector2(14, 10)))
	b.add_theme_stylebox_override("disabled", _box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.08), 10, 1, Vector2(14, 10)))
	b.pressed.connect(_choose.bind(choice))
	parent.add_child(b)
	return b

func _box(bg: Color, border: Color, radius: int, border_w: int, pad: Vector2 = Vector2.ZERO) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad.x
	s.content_margin_right = pad.x
	s.content_margin_top = pad.y
	s.content_margin_bottom = pad.y
	return s
