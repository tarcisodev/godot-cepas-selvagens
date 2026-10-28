class_name GuildScreen
extends Control

const _Player = preload("res://scripts/player.gd")
const _GuildData = preload("res://scripts/data/guild_data.gd")
const _GuildSystem = preload("res://scripts/systems/guild_system.gd")
const _GuildComponent = preload("res://scripts/components/guild_component.gd")
const _MaterialData = preload("res://scripts/data/material_data.gd")

## Tela de Gerenciamento da Guilda, Território, Contribuição e Uniformes (GDD-15).

enum Tab { OVERVIEW, DONATIONS, MEMBERS, WARDROBE }

const TEXT_COLOR := Color(0.92, 0.9, 0.86)
const ACCENT_COLOR := Color(1.0, 0.72, 0.3)
const BG_DARK := Color(0.09, 0.08, 0.07, 0.96)

var player: _Player
var current_guild: _GuildData
var active_tab: Tab = Tab.OVERVIEW

var _title_label: Label
var _tag_label: Label
var _emblem_label: Label
var _content_box: VBoxContainer
var _tab_buttons: Array[Button] = []

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.03, 0.82)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -440
	panel.offset_top = -280
	panel.offset_right = 440
	panel.offset_bottom = 280

	var style := StyleBoxFlat.new()
	style.bg_color = BG_DARK
	style.border_color = ACCENT_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Cabeçalho
	var header := HBoxContainer.new()
	_emblem_label = Label.new()
	_emblem_label.text = "⚔️"
	_emblem_label.add_theme_font_size_override("font_size", 28)
	header.add_child(_emblem_label)

	var title_vbox := VBoxContainer.new()
	_title_label = Label.new()
	_title_label.text = "SEDE DA GUILDA"
	_title_label.add_theme_color_override("font_color", ACCENT_COLOR)
	_title_label.add_theme_font_size_override("font_size", 18)
	_tag_label = Label.new()
	_tag_label.text = "[TAG] · Nível 1"
	_tag_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_tag_label.add_theme_font_size_override("font_size", 12)
	title_vbox.add_child(_title_label)
	title_vbox.add_child(_tag_label)
	header.add_child(title_vbox)

	header.add_spacer(false)
	var close_btn := Button.new()
	close_btn.text = "✕ Fechar [Esc]"
	close_btn.pressed.connect(close)
	header.add_child(close_btn)
	vbox.add_child(header)

	# Barra de Abas
	var tabs_box := HBoxContainer.new()
	tabs_box.add_theme_constant_override("separation", 8)

	var tab_names := ["🏛️ Visão Geral", "📦 Contribuição do Clã", "👥 Membros", "🎩 Armário de Uniformes"]
	for i in tab_names.size():
		var btn := Button.new()
		btn.text = tab_names[i]
		btn.custom_minimum_size = Vector2(160, 36)
		var t_idx := i
		btn.pressed.connect(func(): _switch_tab(t_idx))
		tabs_box.add_child(btn)
		_tab_buttons.append(btn)
	vbox.add_child(tabs_box)

	# Área de Conteúdo
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_content_box = VBoxContainer.new()
	_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_box.add_theme_constant_override("separation", 10)
	scroll.add_child(_content_box)

func open(p_player: _Player, p_guild: _GuildData = null) -> void:
	player = p_player
	if p_guild:
		current_guild = p_guild
	elif player:
		var g_comp: _GuildComponent = player.get("guild")
		if g_comp:
			current_guild = g_comp.get_guild_data()
	
	visible = true
	_refresh_screen()

func close() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _switch_tab(tab_idx: int) -> void:
	active_tab = tab_idx as Tab
	_refresh_screen()

func _refresh_screen() -> void:
	for child in _content_box.get_children():
		child.queue_free()

	if current_guild == null:
		_show_no_guild_view()
		return

	_title_label.text = current_guild.name
	_tag_label.text = "[%s] · Sede Nível %d (%s) · Raio %.0f m" % [
		current_guild.tag,
		current_guild.level,
		_level_name(current_guild.level),
		current_guild.get_territory_radius()
	]
	_emblem_label.text = current_guild.get_emblem_icon()
	_emblem_label.modulate = current_guild.secondary_color

	match active_tab:
		Tab.OVERVIEW:
			_render_overview()
		Tab.DONATIONS:
			_render_donations()
		Tab.MEMBERS:
			_render_members()
		Tab.WARDROBE:
			_render_wardrobe()

func _show_no_guild_view() -> void:
	_title_label.text = "SEM GUILDA"
	_tag_label.text = "Junte-se a uma guilda ou finque um Totem de Guilda"
	_emblem_label.text = "❓"

	var lbl := Label.new()
	lbl.text = "Você não pertence a nenhuma guilda no momento.\nFinque um Totem de Guilda na natureza ou receba o convite de um clã."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_box.add_child(lbl)

func _level_name(lvl: int) -> String:
	match lvl:
		1: return "Acampamento Pioneiro"
		2: return "Forte de Madeira"
		3: return "Cidadela de Pedra & Ferro"
		_: return "Território Ancestral"

func _render_overview() -> void:
	var info_box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.12, 0.10)
	style.set_corner_radius_all(6)
	info_box.add_theme_stylebox_override("panel", style)
	_content_box.add_child(info_box)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	info_box.add_child(vb)

	var motto_lbl := Label.new()
	motto_lbl.text = "📜 Lema: \"%s\"" % (current_guild.motto if not current_guild.motto.is_empty() else "Unidos pela Sobrevivência")
	motto_lbl.add_theme_color_override("font_color", ACCENT_COLOR)
	vb.add_child(motto_lbl)

	var terr_lbl := Label.new()
	terr_lbl.text = "🛡️ Território Protegido: Raio de %.0f metros em torno do Totem da Guilda." % current_guild.get_territory_radius()
	vb.add_child(terr_lbl)

	var heraldry_lbl := Label.new()
	heraldry_lbl.text = "🎨 Cores Heráldicas: Primária [Cor 1] e Secundária [Cor 2]."
	vb.add_child(heraldry_lbl)

	var count_lbl := Label.new()
	count_lbl.text = "👥 Integrantes do Clã: %d membros." % current_guild.members.size()
	vb.add_child(count_lbl)

func _render_donations() -> void:
	if current_guild.level >= 3:
		var max_lbl := Label.new()
		max_lbl.text = "🏰 Sede no Nível Máximo (Cidadela de Pedra & Ferro)!"
		max_lbl.add_theme_color_override("font_color", ACCENT_COLOR)
		_content_box.add_child(max_lbl)
		return

	var next_lvl := current_guild.level + 1
	var reqs: Dictionary = _GuildData.LEVEL_UP_REQUIREMENTS.get(next_lvl, {})

	var header := Label.new()
	header.text = "📦 Evoluir para Nível %d (%s)" % [next_lvl, _level_name(next_lvl)]
	header.add_theme_color_override("font_color", ACCENT_COLOR)
	_content_box.add_child(header)

	var inv = player.get("inventory") if player else null

	for mat_id in reqs:
		var need: int = int(reqs[mat_id])
		var current: int = int(current_guild.donations.get(mat_id, 0))
		var mat_data := _MaterialData.of(mat_id)
		var have: int = inv.get_material_count(mat_id) if inv else 0

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var icon := Label.new()
		icon.text = mat_data.icon
		icon.add_theme_font_size_override("font_size", 20)
		row.add_child(icon)

		var v_info := VBoxContainer.new()
		v_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := Label.new()
		title.text = "%s (%d / %d) · Na mochila: %d" % [mat_data.display_name, current, need, have]
		v_info.add_child(title)

		var bar := ProgressBar.new()
		bar.max_value = need
		bar.value = current
		bar.custom_minimum_size = Vector2(0, 8)
		v_info.add_child(bar)
		row.add_child(v_info)

		var donate_btn := Button.new()
		donate_btn.text = "Doar"
		donate_btn.disabled = have <= 0 or current >= need
		var m_ref: StringName = StringName(mat_id)
		donate_btn.pressed.connect(func(): _donate_material(m_ref))
		row.add_child(donate_btn)

		_content_box.add_child(row)

func _donate_material(mat_id: StringName) -> void:
	var inv = player.get("inventory") if player else null
	if inv == null or inv.get_material_count(mat_id) < 1:
		return
	if inv.consume_materials({mat_id: 1}):
		current_guild.add_donation(mat_id, 1)
		_refresh_screen()

func _render_members() -> void:
	for username in current_guild.members:
		var role: int = int(current_guild.members[username])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var name_lbl := Label.new()
		name_lbl.text = "👤 %s" % username
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var role_lbl := Label.new()
		role_lbl.text = _GuildData.role_name(role)
		role_lbl.add_theme_color_override("font_color", ACCENT_COLOR if role == _GuildData.Role.LEADER else TEXT_COLOR)
		row.add_child(role_lbl)

		_content_box.add_child(row)

func _render_wardrobe() -> void:
	var intro := Label.new()
	intro.text = "Selecione a ocasião de vestimenta do clã (GDD-15 §4):"
	intro.add_theme_color_override("font_color", ACCENT_COLOR)
	_content_box.add_child(intro)

	var g_comp: _GuildComponent = player.get("guild") if player else null
	var cur_occ: _GuildData.Occasion = g_comp.active_occasion if g_comp else _GuildData.Occasion.PERSONAL

	var options := [
		{
			"occ": _GuildData.Occasion.PERSONAL,
			"icon": "🎒",
			"title": "Equipamento Pessoal Livre",
			"desc": "Seu equipamento individual forjado sem imposição de cores corporativas."
		},
		{
			"occ": _GuildData.Occasion.GALA,
			"icon": "🎩",
			"title": "Set de Gala do Clã",
			"desc": "Túnicas de seda e trajes nobres nas cores da guilda. Para recepções, banquetes e casamentos."
		},
		{
			"occ": _GuildData.Occasion.WAR,
			"icon": "⚔️",
			"title": "Set de Batalha do Clã",
			"desc": "Armadura de guerra com o Brasão bordado na Capa e gravado no Escudo e Peitoral."
		}
	]

	for opt in options:
		var card := PanelContainer.new()
		var is_active: bool = cur_occ == opt["occ"]
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.18, 0.15, 0.12) if is_active else Color(0.12, 0.11, 0.10)
		style.border_color = ACCENT_COLOR if is_active else Color(0.3, 0.3, 0.3)
		style.set_border_width_all(2 if is_active else 1)
		style.set_corner_radius_all(6)
		card.add_theme_stylebox_override("panel", style)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		var ic := Label.new()
		ic.text = opt["icon"]
		ic.add_theme_font_size_override("font_size", 28)
		row.add_child(ic)

		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tit := Label.new()
		tit.text = opt["title"] + (" (ATIVO)" if is_active else "")
		tit.add_theme_color_override("font_color", ACCENT_COLOR if is_active else TEXT_COLOR)
		vb.add_child(tit)
		var desc := Label.new()
		desc.text = opt["desc"]
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		vb.add_child(desc)
		row.add_child(vb)

		var btn := Button.new()
		btn.text = "Equipar" if not is_active else "Em Uso"
		btn.disabled = is_active
		var occ_ref = opt["occ"]
		btn.pressed.connect(func(): _set_uniform(occ_ref))
		row.add_child(btn)

		_content_box.add_child(card)

func _set_uniform(occ: _GuildData.Occasion) -> void:
	if player == null:
		return
	var g_comp: _GuildComponent = player.get("guild")
	if g_comp:
		g_comp.set_occasion(occ)
		_refresh_screen()
