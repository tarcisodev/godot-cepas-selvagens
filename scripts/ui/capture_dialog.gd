class_name CaptureDialog
extends Control

## Escolha depois de capturar um bicho (GDD-03 §9.3): abate cuidadoso (todas as partes Íntegras),
## levar ao estábulo como montaria própria (Trotador e Planador; até 3) ou soltar.
## O mundo continua rodando enquanto a tela está aberta.

signal chosen(choice: StringName)  # &"abate", &"estabulo", &"rancho", &"soltar"

const TEXT := Color(0.92, 0.92, 0.95)
const TEXT_DIM := Color(0.62, 0.64, 0.7)
const GOLD := Color(0.95, 0.78, 0.35)

var _title: Label
var _genes: Label
var _stable_btn: Button
var _rancho_btn: Button
var _buttons: VBoxContainer

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
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", TEXT)
	col.add_child(_title)
	_genes = Label.new()
	_genes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_genes.add_theme_color_override("font_color", TEXT_DIM)
	_genes.add_theme_font_size_override("font_size", 14)
	col.add_child(_genes)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	col.add_child(_buttons)
	_add_button("🔪  Abate cuidadoso — todas as partes saem Íntegras (+1★)", &"abate")
	_stable_btn = _add_button("", &"estabulo")
	_rancho_btn = _add_button("🏡  Enviar ao Rancho — matriz reprodutiva para o Cercado", &"rancho")
	_add_button("🌿  Soltar na natureza", &"soltar")

func ask(dna: CreatureDNA, can_stable: bool, stable_reason: String) -> void:
	_title.text = "✨ Você capturou: %s" % dna.species_name()
	var genes: Array[String] = []
	genes.append("Porte %s (%d%%)" % ["".join(dna.alleles.get("porte", [])), roundi(dna.size_factor() * 100.0)])
	genes.append("Chifre/penacho: %s" % ("sim" if dna.has_horns() else "não"))
	genes.append("Pelagem: %s" % ("listrada" if dna.is_striped() else "lisa"))
	if dna.is_mutant():
		genes.append("✦ MUTANTE iridescente")
	_genes.text = " · ".join(genes)
	_stable_btn.text = "🐎  Levar ao estábulo — vira sua montaria" + ("" if can_stable else "  (%s)" % stable_reason)
	_stable_btn.disabled = not can_stable
	var can_rancho: bool = dna.species != CreatureDNA.Species.RINOLITO
	_rancho_btn.disabled = not can_rancho
	_rancho_btn.text = "🏡  Enviar ao Rancho — matriz reprodutiva" + ("" if can_rancho else "  (Monstro colossal indomável)")
	visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _choose(choice: StringName) -> void:
	visible = false
	remove_from_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	chosen.emit(choice)

func _add_button(text: String, choice: StringName) -> Button:
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
	_buttons.add_child(b)
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
