class_name MarriageScreen
extends Control

## Interface do Altar de Votos da Capela (GDD-14 §4.1).
## Permite aos jogadores realizarem casamentos, trocarem alianças de votos e solicitarem divórcios.

const _Player = preload("res://scripts/player.gd")
const _FamilyComponent = preload("res://scripts/components/family_component.gd")

const CANDIDATES: Array[Dictionary] = [
	{"name": "Ayla", "title": "Caçadora dos Ermos", "feminine": true, "seed": 101},
	{"name": "Breno", "title": "Mestre da Forja", "feminine": false, "seed": 102},
	{"name": "Elena", "title": "Guardiã da Horta", "feminine": true, "seed": 103},
	{"name": "Dario", "title": "Pescador do Rio", "feminine": false, "seed": 104},
	{"name": "Mirela", "title": "Erborista da Vila", "feminine": true, "seed": 105},
	{"name": "Cassio", "title": "Sentinela do Totem", "feminine": false, "seed": 106},
]

var player: _Player
var _panel: PanelContainer
var _title_label: Label
var _status_label: Label
var _partner_option: OptionButton
var _custom_name_edit: LineEdit
var _action_button: Button
var _info_label: Label

func _ready() -> void:
	visible = false
	_build_ui()

func _build_ui() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.set_anchors_preset(PRESET_FULL_RECT)
	backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close()
	)
	add_child(backdrop)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(500, 380)
	_panel.set_anchors_preset(PRESET_CENTER)
	_panel.offset_left = -250
	_panel.offset_top = -190
	_panel.offset_right = 250
	_panel.offset_bottom = 190

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.15, 0.96)
	style.border_color = Color(0.85, 0.72, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(vbox)

	# Cabeçalho
	var header := HBoxContainer.new()
	_title_label = Label.new()
	_title_label.text = "💍 Altar de Votos — Capela da Esperança"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	_title_label.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(_title_label)

	var close_btn := Button.new()
	close_btn.text = " ✕ "
	close_btn.pressed.connect(close)
	header.add_child(close_btn)
	vbox.add_child(header)

	var desc := Label.new()
	desc.text = "Celebre o matrimônio abençoado nas Cepas Selvagens. Casais recebem a Aliança de Votos (+10% de regeneração de vida e vigor ao explorarem juntos)."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	vbox.add_child(desc)

	_status_label = Label.new()
	_status_label.text = "Status: Solteiro(a)"
	_status_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_status_label)

	# Seleção de parceiro
	var select_box := VBoxContainer.new()
	select_box.name = "SelectBox"
	select_box.add_theme_constant_override("separation", 6)

	var opt_label := Label.new()
	opt_label.text = "Escolher Cônjuge da Comunidade:"
	opt_label.add_theme_font_size_override("font_size", 12)
	select_box.add_child(opt_label)

	_partner_option = OptionButton.new()
	for i in CANDIDATES.size():
		var c: Dictionary = CANDIDATES[i]
		_partner_option.add_item("%s (%s)" % [c.name, c.title], i)
	_partner_option.add_item("Outro (Nome personalizado abaixo)", 99)
	select_box.add_child(_partner_option)

	_custom_name_edit = LineEdit.new()
	_custom_name_edit.placeholder_text = "Ou digite o nome de outro aventureiro..."
	select_box.add_child(_custom_name_edit)
	vbox.add_child(select_box)

	# Botão de Ação (Votos / Divórcio)
	_action_button = Button.new()
	_action_button.text = "💍 Celebrar Votos Sagrados"
	_action_button.custom_minimum_size.y = 40
	_action_button.pressed.connect(_on_action_pressed)
	vbox.add_child(_action_button)

	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.add_theme_font_size_override("font_size", 13)
	_info_label.text = ""
	vbox.add_child(_info_label)

func open(p_player: _Player) -> void:
	player = p_player
	visible = true
	_refresh()

func close() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	if player == null or player.family == null:
		return
	var fam: _FamilyComponent = player.family
	var select_box := _panel.find_child("SelectBox", true, false)

	if fam.is_married():
		_status_label.text = "Status: Casado(a) com %s" % fam.spouse_name
		_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
		if select_box:
			select_box.visible = false
		_action_button.text = "💔 Solicitar Divórcio Amigável"
		_info_label.text = "Aliança de Votos ativa no inventário. O divórcio dissolve os votos sem custo."
		_info_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	else:
		_status_label.text = "Status: Solteiro(a)"
		_status_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
		if select_box:
			select_box.visible = true
		_action_button.text = "💍 Celebrar Votos Sagrados"
		_info_label.text = "A cerimônia sela a união e entrega a Aliança de Votos."
		_info_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

func _on_action_pressed() -> void:
	if player == null or player.family == null:
		return
	var fam: _FamilyComponent = player.family
	if fam.is_married():
		# Divórcio
		var ex := fam.spouse_name
		fam.divorce()
		_info_label.text = "Divórcio concluído. Os votos com %s foram desfeitos." % ex
		_info_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
	else:
		# Matrimônio
		var chosen_name := ""
		var chosen_dna = null
		var idx := _partner_option.selected
		if idx < CANDIDATES.size():
			var c: Dictionary = CANDIDATES[idx]
			chosen_name = c.name
			var char_dna_class = preload("res://scripts/data/character_dna.gd")
			chosen_dna = char_dna_class.randomized(c.seed)
			chosen_dna.gender = char_dna_class.Gender.FEMALE if c.feminine else char_dna_class.Gender.MALE
		elif not _custom_name_edit.text.strip_edges().is_empty():
			chosen_name = _custom_name_edit.text.strip_edges()
		else:
			chosen_name = "Ayla"

		fam.marry(chosen_name, chosen_dna)
		_info_label.text = "Parabéns! Votos celebrados com %s! Aliança de Votos entregue." % chosen_name
		_info_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
	_refresh()
