class_name NurseryScreen
extends Control

## Interface do Berçário e Maternidade da Cidade (GDD-14 §4.3 e §4.4).
## Oferece parto gratuito com a parteira Mestra Clara e gestão de filhos da comunidade.

const _Player = preload("res://scripts/player.gd")
const _FamilyComponent = preload("res://scripts/components/family_component.gd")

var player: _Player
var nursery_station: Node

var _panel: PanelContainer
var _maternity_box: VBoxContainer
var _nursery_box: VBoxContainer
var _child_name_edit: LineEdit
var _birth_btn: Button
var _status_label: Label
var _progress_bar: ProgressBar
var _children_list: VBoxContainer
var _tab_btn_maternity: Button
var _tab_btn_nursery: Button

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
	_panel.custom_minimum_size = Vector2(560, 440)
	_panel.set_anchors_preset(PRESET_CENTER)
	_panel.offset_left = -280
	_panel.offset_top = -220
	_panel.offset_right = 280
	_panel.offset_bottom = 220

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.13, 0.16, 0.96)
	style.border_color = Color(0.45, 0.75, 0.85)
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
	var title := Label.new()
	title.text = "👶 Berçário da Cidade & Casa da Parteira"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = " ✕ "
	close_btn.pressed.connect(close)
	header.add_child(close_btn)
	vbox.add_child(header)

	# Abas (Maternidade / Berçário)
	var tabs := HBoxContainer.new()
	_tab_btn_maternity = Button.new()
	_tab_btn_maternity.text = "🏥 Maternidade & Parteira"
	_tab_btn_maternity.size_flags_horizontal = SIZE_EXPAND_FILL
	_tab_btn_maternity.pressed.connect(func(): _show_tab(0))
	tabs.add_child(_tab_btn_maternity)

	_tab_btn_nursery = Button.new()
	_tab_btn_nursery.text = "🍼 Berçário Comunitário"
	_tab_btn_nursery.size_flags_horizontal = SIZE_EXPAND_FILL
	_tab_btn_nursery.pressed.connect(func(): _show_tab(1))
	tabs.add_child(_tab_btn_nursery)
	vbox.add_child(tabs)

	# Aba 1: Maternidade
	_maternity_box = VBoxContainer.new()
	_maternity_box.add_theme_constant_override("separation", 10)
	vbox.add_child(_maternity_box)

	_status_label = Label.new()
	_status_label.text = "Mestra Clara: Bem-vinda à Casa da Parteira."
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 13)
	_maternity_box.add_child(_status_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size.y = 24
	_progress_bar.max_value = 27.0
	_progress_bar.show_percentage = false
	_maternity_box.add_child(_progress_bar)

	var name_box := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = "Nome do Bebê:"
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_box.add_child(name_lbl)

	_child_name_edit = LineEdit.new()
	_child_name_edit.placeholder_text = "Ex: Luan, Marina, Gael..."
	_child_name_edit.text = "Luan"
	_child_name_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	name_box.add_child(_child_name_edit)
	_maternity_box.add_child(name_box)

	_birth_btn = Button.new()
	_birth_btn.text = "🍼 Realizar Parto com Mestra Clara (Gratuito)"
	_birth_btn.custom_minimum_size.y = 42
	_birth_btn.pressed.connect(_on_birth_pressed)
	_maternity_box.add_child(_birth_btn)

	# Aba 2: Berçário Comunitário
	_nursery_box = VBoxContainer.new()
	_nursery_box.visible = false
	_nursery_box.add_theme_constant_override("separation", 8)
	vbox.add_child(_nursery_box)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 220
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_children_list = VBoxContainer.new()
	_children_list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_children_list)
	_nursery_box.add_child(scroll)

func open(p_player: _Player, p_station: Node = null) -> void:
	player = p_player
	nursery_station = p_station
	visible = true
	_show_tab(0)
	_refresh()

func close() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _show_tab(index: int) -> void:
	_maternity_box.visible = index == 0
	_nursery_box.visible = index == 1
	_tab_btn_maternity.modulate = Color(1.2, 1.2, 1.2) if index == 0 else Color(0.8, 0.8, 0.8)
	_tab_btn_nursery.modulate = Color(1.2, 1.2, 1.2) if index == 1 else Color(0.8, 0.8, 0.8)
	_refresh()

func _refresh() -> void:
	if player == null or player.family == null:
		return
	var fam: _FamilyComponent = player.family

	if fam.is_pregnant:
		_progress_bar.visible = true
		_progress_bar.value = fam.pregnancy_days
		var months := int(fam.pregnancy_days / 3.0) + 1
		if fam.is_labor_ready():
			_status_label.text = "🤰 Gestação Completa: 9 meses (27 dias)! O bebê está pronto para nascer com auxílio da parteira."
			_status_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
			_birth_btn.disabled = false
		else:
			_status_label.text = "🤰 Gestação em curso: Mês %d de 9 (%.1f / 27.0 dias de sol). A gestante segue explorando normalmente." % [months, fam.pregnancy_days]
			_status_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
			_birth_btn.disabled = true
	else:
		_progress_bar.visible = false
		_status_label.text = "Mestra Clara: Tudo calmo por aqui. Quando você e seu cônjuge decidirem ter um filho, descansando juntos, cuidarei de todo o parto gratuitamente."
		_status_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		_birth_btn.disabled = true

	# Lista de crianças do berçário
	for c in _children_list.get_children():
		c.queue_free()

	var all_children: Array = []
	if nursery_station and nursery_station.has_method("get_registered_children"):
		all_children = nursery_station.get_registered_children()
	elif fam.children.size() > 0:
		all_children = fam.children

	if all_children.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Nenhum bebê no berçário no momento."
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_children_list.add_child(empty_lbl)
	else:
		for ch in all_children:
			var c_card := PanelContainer.new()
			var c_style := StyleBoxFlat.new()
			c_style.bg_color = Color(0.18, 0.2, 0.25, 0.9)
			c_style.set_corner_radius_all(6)
			c_style.content_margin_left = 12
			c_style.content_margin_right = 12
			c_style.content_margin_top = 8
			c_style.content_margin_bottom = 8
			c_card.add_theme_stylebox_override("panel", c_style)

			var c_box := HBoxContainer.new()
			var icon_lbl := Label.new()
			var stage_val: int = ch.get("stage", 0)
			icon_lbl.text = "👶" if stage_val == 0 else ("🧒" if stage_val == 1 else "🧑")
			icon_lbl.add_theme_font_size_override("font_size", 20)
			c_box.add_child(icon_lbl)

			var desc_lbl := Label.new()
			var c_name: String = ch.get("name", "Bebê")
			var stage_name: String = ch.get("stage_name", "Criança")
			var craft: String = ch.get("craft", "Aprendiz Geral")
			var parents: String = "%s & %s" % [ch.get("mother", "Mãe"), ch.get("father", "Pai")]
			desc_lbl.text = "%s (%s) — Pais: %s | Ofício: %s" % [c_name, stage_name, parents, craft]
			desc_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
			c_box.add_child(desc_lbl)
			c_card.add_child(c_box)
			_children_list.add_child(c_card)

func _on_birth_pressed() -> void:
	if player == null or player.family == null or not player.family.is_labor_ready():
		return
	var baby_name := _child_name_edit.text.strip_edges()
	if baby_name.is_empty():
		baby_name = "Luan"

	var child_data := player.family.give_birth(baby_name)
	if nursery_station and nursery_station.has_method("admit_child"):
		nursery_station.admit_child(child_data)

	_status_label.text = "🎉 Parabéns! %s nasceu saudável e foi acolhido com amor no Berçário da Cidade!" % baby_name
	_status_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.5))
	_refresh()
