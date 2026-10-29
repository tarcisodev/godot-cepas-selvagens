extends CanvasLayer
class_name WorldHUD

const _CustomCursor = preload("res://scripts/ui/custom_cursor.gd")

@export var day_night: Node3D
@export var player: CharacterBody3D

@onready var time_label: Label = get_node_or_null("MarginContainer/VBoxContainer/TimeLabel")
@onready var mode_label: Label = get_node_or_null("MarginContainer/VBoxContainer/ModeLabel")
@onready var tips_container: VBoxContainer = get_node_or_null("BottomMargin/TipsContainer")
@onready var health_bar: ProgressBar = get_node_or_null("MarginContainer/VBoxContainer/StatusBars/HealthBar")
@onready var ether_bar: ProgressBar = get_node_or_null("MarginContainer/VBoxContainer/StatusBars/EtherBar")
@onready var vigor_bar: ProgressBar = get_node_or_null("MarginContainer/VBoxContainer/StatusBars/VigorBar")
@onready var poise_bar: ProgressBar = get_node_or_null("MarginContainer/VBoxContainer/StatusBars/PoiseBar")
@onready var reticle: Control = get_node_or_null("Reticle")

const GLOBAL_THEME_PATH: String = "res://resources/ui/global_theme.tres"
const PANEL_BG_ALPHA: float = 0.62
const HUD_BAR_WIDTH: float = 220.0

const ACTION_SHORTCUTS: Array[Dictionary] = [
	{"id": &"map", "key": "(M)", "tooltip": "[M] Mapa", "hover": "🗺️ Mapa Mundial (M)", "color": Color(0.45, 0.86, 0.68)},
	{"id": &"central", "key": "(Tab)", "tooltip": "[TAB] Central", "hover": "⛺ Central do Andarilho (Tab)", "color": Color(0.96, 0.78, 0.36)},
	{"id": &"inventory", "key": "(I)", "tooltip": "[I] Mochila", "hover": "🎒 Mochila & Equipamentos (I)", "color": Color(0.88, 0.66, 0.42)},
	{"id": &"build", "key": "(B)", "tooltip": "[B] Construir", "hover": "🏗️ Modo Construção (B)", "color": Color(0.92, 0.56, 0.34)},
	{"id": &"cards", "key": "(K)", "tooltip": "[K] Cartas", "hover": "🃏 Álbum de Cartas (K)", "color": Color(0.76, 0.58, 0.96)},
	{"id": &"guide", "key": "(J)", "tooltip": "[J] Guia", "hover": "🧭 Guia & Tutorial (J)", "color": Color(0.46, 0.82, 0.96)},
	{"id": &"cosmetics", "key": "(F9)", "tooltip": "[F9] Cosméticos", "hover": "✨ Cosméticos (F9)", "color": Color(0.98, 0.64, 0.84)},
	{"id": &"feedback", "key": "(F8)", "tooltip": "[F8] Feedback", "hover": "💬 Mural de Feedback (F8)", "color": Color(0.64, 0.92, 0.54)},
	{"id": &"coop", "key": "(F7)", "tooltip": "[F7] Coop LAN", "hover": "🌐 Sala Coop LAN (F7)", "color": Color(0.48, 0.76, 0.98)},
	{"id": &"photo", "key": "(P)", "tooltip": "[P] Modo Foto", "hover": "📷 Modo Foto & Reconhecimento (P)", "color": Color(0.95, 0.82, 0.4)},
]

static var _icon_cache: Dictionary = {}

var tips_visible: bool = false
var current_posture: String = "Em Pé"
var current_view: String = "🌄 3ª Pessoa"

var explorer_card: PanelContainer
var quick_nav_panel: PanelContainer
var quick_nav_row: HBoxContainer
var shortcut_buttons: Array[TextureButton] = []
var expand_toggle_btn: TextureButton
var lock_toggle_btn: TextureButton
var is_ability_bar_expanded: bool = true
var is_hud_locked: bool = false

var _hover_banner: PanelContainer
var _hover_label: Label
var _health_text: Label
var _weather_node: Node

func _ready() -> void:
	CustomCursor.ensure_installed(get_tree())
	_apply_global_theme()
	_decorate_hud()

	if player and player.camera_rig:
		player.camera_rig.camera_mode_changed.connect(_on_camera_mode_changed)
	if player and player.has_signal("posture_changed"):
		player.posture_changed.connect(_on_posture_changed)
	if player and player.has_signal("aim_changed"):
		player.aim_changed.connect(_on_aim_changed)

	if player and "pools" in player and player.pools != null:
		player.pools.health_changed.connect(_on_health_changed)
		player.pools.ether_changed.connect(_on_ether_changed)
		player.pools.vigor_changed.connect(_on_vigor_changed)
		player.pools.poise_changed.connect(_on_poise_changed)
		if player.has_signal("oxygen_changed"):
			_build_oxygen_ui()
			player.oxygen_changed.connect(_on_oxygen_changed)
		if player.stats != null:
			_on_health_changed(player.pools.current_health, player.stats.get_stat(&"max_health"))
			_on_ether_changed(player.pools.current_ether, player.stats.get_stat(&"max_ether"))
			_on_vigor_changed(player.pools.current_vigor, player.stats.get_stat(&"max_vigor"))
			_on_poise_changed(player.pools.current_poise, player.stats.get_stat(&"max_poise"))

	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		gs.setting_changed.connect(_on_setting_changed)
	# Mantém as dicas de texto recolhidas por padrão para não poluir a tela ([F2] alterna; o [H] é o Apito de Osso)
	_set_tips_visible(false)

	_update_hud_status()

## Garante que o tema global tenha StyleBoxFlat com leve transparência no fundo dos PanelContainers
func _apply_global_theme() -> void:
	if not is_inside_tree():
		return
	var root_win := get_tree().root
	if root_win.theme == null and ResourceLoader.exists(GLOBAL_THEME_PATH):
		root_win.theme = load(GLOBAL_THEME_PATH)
	if root_win.theme == null:
		root_win.theme = Theme.new()
	var global_sb := root_win.theme.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	if global_sb == null:
		global_sb = StyleBoxFlat.new()
		global_sb.border_color = Color(0.76, 0.62, 0.34, 0.82)
		global_sb.set_border_width_all(2)
		global_sb.set_corner_radius_all(12)
		root_win.theme.set_stylebox("panel", "PanelContainer", global_sb)
	global_sb.bg_color = Color(0.05, 0.08, 0.07, PANEL_BG_ALPHA)

## Estiliza o HUD enxuto e compacto
func _decorate_hud() -> void:
	var margin := get_node_or_null("MarginContainer") as MarginContainer
	var vbox := get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
	if margin and vbox:
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_top", 14)
		var card := PanelContainer.new()
		card.name = "ExplorerCard"
		explorer_card = card
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.08, 0.07, PANEL_BG_ALPHA)
		sb.border_color = Color(0.76, 0.62, 0.34, 0.72)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(10)
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 6
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", sb)
		margin.remove_child(vbox)
		margin.add_child(card)
		card.add_child(vbox)
		vbox.add_theme_constant_override("separation", 5)
		var status_bars := vbox.get_node_or_null("StatusBars") as VBoxContainer
		if status_bars:
			status_bars.add_theme_constant_override("separation", 4)

	if time_label:
		time_label.modulate = Color(1, 1, 1, 1)
		time_label.custom_minimum_size = Vector2(HUD_BAR_WIDTH, 0)
		time_label.clip_text = true
		var tls := LabelSettings.new()
		tls.font_size = 13
		tls.font_color = Color(0.98, 0.94, 0.82, 1.0)
		tls.outline_size = 3
		tls.outline_color = Color(0.02, 0.03, 0.04, 0.95)
		time_label.label_settings = tls

	if mode_label:
		mode_label.modulate = Color(1, 1, 1, 1)
		mode_label.custom_minimum_size = Vector2(HUD_BAR_WIDTH, 0)
		mode_label.clip_text = true
		var mls := LabelSettings.new()
		mls.font_size = 11
		mls.font_color = Color(0.82, 0.90, 0.85, 1.0)
		mls.outline_size = 3
		mls.outline_color = Color(0.02, 0.03, 0.04, 0.92)
		mode_label.label_settings = mls

	_style_bar(health_bar, Color(0.88, 0.22, 0.26, 1.0), Color(0.15, 0.04, 0.05, 0.95), 16, true, Color(0.32, 0.08, 0.10, 0.85), "❤️ Vida (PV): Integridade física. Zera = desmaio/morte.")
	_style_bar(ether_bar, Color(0.22, 0.62, 0.96, 1.0), Color(0.04, 0.10, 0.18, 0.95), 9, false, Color(0.08, 0.20, 0.34, 0.85), "🔷 Éter (PE): Energia arcana para feitiços e habilidades ativas.")
	_style_bar(vigor_bar, Color(0.25, 0.82, 0.48, 1.0), Color(0.04, 0.14, 0.08, 0.95), 9, false, Color(0.08, 0.26, 0.14, 0.85), "⚡ Vigor (ST): Estamina para correr, esquivar, golpear e nadar.")
	_style_bar(poise_bar, Color(0.92, 0.74, 0.24, 1.0), Color(0.14, 0.10, 0.04, 0.95), 7, false, Color(0.30, 0.22, 0.07, 0.85), "🛡️ Postura (EQ): Equilíbrio e estabilidade em combate. Evita atordoamento.")

	if tips_container:
		var tip_lbl := tips_container.get_node_or_null("ControlsTip") as Label
		if tip_lbl:
			tip_lbl.text = "⚔️ Combate: Esq. Golpe 1  |  Dir. Golpe 2  |  Esq.+Dir. Golpe Especial  |  [C] Esquivar  |  [Alt] Cursor livre"
			tip_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 0.90, 1.0))
			tip_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
			tip_lbl.add_theme_constant_override("outline_size", 3)

	_build_ability_bar()
	_build_quick_nav_pills()

func _style_bar(bar: ProgressBar, fill_col: Color, bg_col: Color, height: float, show_hp_text: bool, border_col: Color = Color.TRANSPARENT, tooltip: String = "") -> void:
	if bar == null:
		return
	bar.modulate = Color(1, 1, 1, 1)
	bar.self_modulate = Color(1, 1, 1, 1)
	bar.custom_minimum_size = Vector2(HUD_BAR_WIDTH, height)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if not tooltip.is_empty():
		bar.tooltip_text = tooltip

	var radius: int = 3

	var bg := StyleBoxFlat.new()
	bg.bg_color = bg_col
	bg.border_color = border_col if border_col != Color.TRANSPARENT else Color(0.14, 0.18, 0.16, 0.9)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(radius)

	var fg := StyleBoxFlat.new()
	fg.bg_color = fill_col
	# Sem borda superior nem traços estranhos no preenchimento
	fg.set_border_width_all(0)
	# Cantos esquerdos acompanham o raio da moldura; cantos direitos retos para corte limpo e preciso do medidor
	fg.corner_radius_top_left = maxi(1, radius - 1)
	fg.corner_radius_bottom_left = maxi(1, radius - 1)
	fg.corner_radius_top_right = 0
	fg.corner_radius_bottom_right = 0

	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)

	if show_hp_text:
		if _health_text == null:
			_health_text = Label.new()
			_health_text.name = "HealthText"
			_health_text.set_anchors_preset(Control.PRESET_FULL_RECT)
			_health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_health_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_health_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var hp_ls := LabelSettings.new()
			hp_ls.font_size = 11
			hp_ls.font_color = Color(1.0, 0.98, 0.94, 1.0)
			hp_ls.outline_size = 3
			hp_ls.outline_color = Color(0.04, 0.04, 0.05, 0.95)
			hp_ls.shadow_color = Color(0, 0, 0, 0.7)
			hp_ls.shadow_size = 1
			hp_ls.shadow_offset = Vector2(0, 1)
			_health_text.label_settings = hp_ls
			bar.add_child(_health_text)
		_health_text.text = "%.0f / %.0f" % [bar.value, bar.max_value]

## Barra de Ações Minimalista: TextureButtons com a tecla entre parênteses "(M)" +
## banner instantâneo de hover + controles de Expansão (Tween) e Cadeado (Lock/Unlock).
func _build_quick_nav_pills() -> void:
	var nav_margin := MarginContainer.new()
	nav_margin.name = "QuickNavMargin"
	nav_margin.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	nav_margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	nav_margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	nav_margin.add_theme_constant_override("margin_right", 18)
	nav_margin.add_theme_constant_override("margin_bottom", 14)
	nav_margin.z_index = 15
	add_child(nav_margin)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.alignment = BoxContainer.ALIGNMENT_END
	outer_vbox.add_theme_constant_override("separation", 4)
	outer_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav_margin.add_child(outer_vbox)

	# Banner instantâneo de hover (aparece na hora ao passar o mouse sobre qualquer botão)
	_hover_banner = PanelContainer.new()
	_hover_banner.name = "HoverTooltipBanner"
	_hover_banner.visible = false
	_hover_banner.size_flags_horizontal = Control.SIZE_SHRINK_END
	_hover_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.04, 0.07, 0.06, 0.92)
	hsb.border_color = Color(0.92, 0.78, 0.38, 0.90)
	hsb.set_border_width_all(1)
	hsb.set_corner_radius_all(6)
	hsb.content_margin_left = 10
	hsb.content_margin_right = 10
	hsb.content_margin_top = 3
	hsb.content_margin_bottom = 3
	_hover_banner.add_theme_stylebox_override("panel", hsb)
	_hover_label = Label.new()
	_hover_label.add_theme_font_size_override("font_size", 12)
	_hover_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72, 1.0))
	_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_banner.add_child(_hover_label)
	outer_vbox.add_child(_hover_banner)

	var pill_panel := PanelContainer.new()
	pill_panel.name = "QuickNavPanel"
	quick_nav_panel = pill_panel
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.07, PANEL_BG_ALPHA)
	sb.border_color = Color(0.72, 0.58, 0.32, 0.72)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	pill_panel.add_theme_stylebox_override("panel", sb)
	outer_vbox.add_child(pill_panel)

	var row := HBoxContainer.new()
	row.name = "QuickNavRow"
	row.add_theme_constant_override("separation", 4)
	pill_panel.add_child(row)
	quick_nav_row = row

	shortcut_buttons.clear()
	for entry in ACTION_SHORTCUTS:
		var action_id: StringName = entry.id
		var col: Color = entry.color
		var key_str: String = str(entry.key)
		var hover_txt: String = str(entry.hover)
		var btn := _create_icon_button(action_id, col, Vector2(36, 38), str(entry.tooltip), key_str, hover_txt)
		btn.name = "Btn_" + String(action_id)
		btn.pressed.connect(_trigger_shortcut.bind(action_id))
		row.add_child(btn)
		shortcut_buttons.append(btn)

	# Controles de Expansão e Bloqueio na extremidade direita da barra de ações inferior
	expand_toggle_btn = _create_icon_button(&"expand_down", Color(0.95, 0.84, 0.48), Vector2(28, 38), "Recolher barra de habilidades", "▼", "🔽 Recolher barra de habilidades")
	expand_toggle_btn.name = "ExpandToggleButton"
	expand_toggle_btn.pressed.connect(toggle_ability_bar_expanded)
	row.add_child(expand_toggle_btn)

	lock_toggle_btn = _create_icon_button(&"unlock", Color(0.82, 0.88, 0.84), Vector2(28, 38), "Trancar painéis do HUD (ignorar mouse)", "🔓", "🔓 Trancar painéis do HUD")
	lock_toggle_btn.name = "LockToggleButton"
	lock_toggle_btn.pressed.connect(toggle_hud_lock)
	row.add_child(lock_toggle_btn)

func _create_icon_button(icon_id: StringName, color: Color, btn_size: Vector2, tooltip: String, key_badge: String = "", hover_desc: String = "") -> TextureButton:
	var btn := TextureButton.new()
	btn.custom_minimum_size = btn_size
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.tooltip_text = tooltip
	btn.texture_normal = _get_icon_texture(icon_id, color, false)
	btn.texture_hover = _get_icon_texture(icon_id, color.lightened(0.24), true)
	btn.texture_pressed = _get_icon_texture(icon_id, color.darkened(0.15), true)

	if not key_badge.is_empty():
		var badge := Label.new()
		badge.name = "KeyBadge"
		badge.text = key_badge
		badge.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		badge.offset_top = -12.0
		badge.offset_bottom = 1.0
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ls := LabelSettings.new()
		ls.font_size = 9
		ls.font_color = Color(0.98, 0.94, 0.78, 1.0)
		ls.outline_size = 3
		ls.outline_color = Color(0.0, 0.0, 0.0, 0.95)
		badge.label_settings = ls
		btn.add_child(badge)

	var desc := hover_desc if not hover_desc.is_empty() else tooltip
	btn.set_meta("hover_desc", desc)
	btn.mouse_entered.connect(func() -> void: _show_hover_banner(str(btn.get_meta("hover_desc", tooltip))))
	btn.mouse_exited.connect(_hide_hover_banner)
	return btn

func _show_hover_banner(text: String) -> void:
	if _hover_banner == null or _hover_label == null:
		return
	_hover_label.text = text
	_hover_banner.visible = not text.is_empty()

func _hide_hover_banner() -> void:
	if _hover_banner:
		_hover_banner.visible = false

## Alterna o estado expandido/recolhido da barra de habilidades inferior com animação suave via Tween
func toggle_ability_bar_expanded() -> void:
	set_ability_bar_expanded(not is_ability_bar_expanded, true)

func set_ability_bar_expanded(expanded: bool, animate: bool = true) -> void:
	is_ability_bar_expanded = expanded
	if expand_toggle_btn:
		var icon_id: StringName = &"expand_down" if expanded else &"expand_up"
		var col := Color(0.95, 0.84, 0.48)
		expand_toggle_btn.texture_normal = _get_icon_texture(icon_id, col, false)
		expand_toggle_btn.texture_hover = _get_icon_texture(icon_id, col.lightened(0.24), true)
		var tip := "Recolher barra de habilidades" if expanded else "Expandir barra de habilidades"
		expand_toggle_btn.tooltip_text = tip
		expand_toggle_btn.set_meta("hover_desc", ("🔽 " if expanded else "🔼 ") + tip)
		var badge := expand_toggle_btn.get_node_or_null("KeyBadge") as Label
		if badge:
			badge.text = "▼" if expanded else "▲"
	if _ability_anchor == null:
		return
	var target_y: float = _ability_expanded_y if expanded else _ability_collapsed_y
	if _ability_bar_tween and _ability_bar_tween.is_valid():
		_ability_bar_tween.kill()
	if animate and is_inside_tree():
		_ability_bar_tween = create_tween()
		_ability_bar_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_ability_bar_tween.tween_property(_ability_anchor, "position:y", target_y, 0.25)
	else:
		_ability_anchor.position.y = target_y

## Alterna o cadeado (Lock/Unlock) que muda o mouse_filter dos painéis para MOUSE_FILTER_IGNORE
func toggle_hud_lock() -> void:
	set_hud_locked(not is_hud_locked)

func set_hud_locked(locked: bool) -> void:
	is_hud_locked = locked
	var panel_filter: Control.MouseFilter = Control.MOUSE_FILTER_IGNORE if locked else Control.MOUSE_FILTER_STOP
	for p in [explorer_card, quick_nav_panel, _horn_panel]:
		if p != null and is_instance_valid(p):
			p.mouse_filter = panel_filter
	for b in [health_bar, ether_bar, vigor_bar, poise_bar, _oxygen_bar]:
		if b != null and is_instance_valid(b):
			b.mouse_filter = panel_filter
	for p in _ability_panels:
		if p != null and is_instance_valid(p):
			p.mouse_filter = panel_filter
	for b in shortcut_buttons:
		if b != null and is_instance_valid(b):
			b.mouse_filter = panel_filter
	var obj := get_node_or_null("/root/Objectives")
	if obj and "panel_container" in obj and obj.panel_container != null and is_instance_valid(obj.panel_container):
		obj.panel_container.mouse_filter = panel_filter
	if lock_toggle_btn:
		var icon_id: StringName = &"lock" if locked else &"unlock"
		var col := Color(0.98, 0.76, 0.32) if locked else Color(0.82, 0.88, 0.84)
		lock_toggle_btn.texture_normal = _get_icon_texture(icon_id, col, false)
		lock_toggle_btn.texture_hover = _get_icon_texture(icon_id, col.lightened(0.24), true)
		var tip := "Destrancar painéis do HUD" if locked else "Trancar painéis do HUD (ignorar mouse)"
		lock_toggle_btn.tooltip_text = tip
		lock_toggle_btn.set_meta("hover_desc", ("🔒 " if locked else "🔓 ") + tip)
		lock_toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var badge := lock_toggle_btn.get_node_or_null("KeyBadge") as Label
		if badge:
			badge.text = "🔒" if locked else "🔓"

func _close_other_hud_menus(except_node: Node = null) -> void:
	if not is_inside_tree():
		return
	for n in get_tree().get_nodes_in_group("open_menus"):
		if n == except_node or not is_instance_valid(n):
			continue
		for method in ["close_map", "close_menu", "close", "close_album", "close_guide", "close_shop", "close_modal"]:
			if n.has_method(method):
				n.call(method)
				break

func _trigger_shortcut(action_id: StringName) -> void:
	if is_hud_locked:
		return
	match action_id:
		&"map":
			var m := get_node_or_null("WorldMapScreen")
			if m:
				if bool(m.get("is_open")) and m.has_method("close_map"):
					m.close_map()
				elif m.has_method("open_map"):
					_close_other_hud_menus(m)
					m.open_map(player)
		&"central":
			var am := get_node_or_null("ActionsMenu")
			if am and am.has_method("toggle_menu"):
				if not bool(am.get("is_open")):
					_close_other_hud_menus(am)
				am.toggle_menu()
		&"inventory":
			var inv := get_node_or_null("InventoryScreen")
			if inv:
				if inv.visible and inv.has_method("close"):
					inv.close()
				elif inv.has_method("open"):
					_close_other_hud_menus(inv)
					inv.open()
		&"build":
			_close_other_hud_menus()
			var bs := get_tree().get_first_node_in_group("building_system") if is_inside_tree() else null
			if bs and bs.has_method("set_building_mode"):
				bs.set_building_mode(not bool(bs.get("is_building")))
		&"cards":
			var album := get_node_or_null("CardAlbum")
			if album:
				if bool(album.get("is_open")) and album.has_method("close_album"):
					album.close_album()
				elif album.has_method("open_album"):
					_close_other_hud_menus(album)
					album.open_album()
		&"guide":
			var g := get_node_or_null("ExplorerGuide")
			if g:
				if bool(g.get("is_open")) and g.has_method("close_guide"):
					g.close_guide()
				elif g.has_method("open_guide"):
					_close_other_hud_menus(g)
					g.open_guide(player)
		&"cosmetics":
			var cs := get_node_or_null("CosmeticsShop")
			if cs:
				if bool(cs.get("is_open")) and cs.has_method("close_shop"):
					cs.close_shop()
				elif cs.has_method("open_shop"):
					_close_other_hud_menus(cs)
					cs.open_shop(player)
		&"feedback":
			var fb := get_node_or_null("FeedbackModal")
			if fb:
				if bool(fb.get("is_open")) and fb.has_method("close_modal"):
					fb.close_modal()
				elif fb.has_method("open_modal"):
					_close_other_hud_menus(fb)
					fb.open_modal()
		&"coop":
			var cp := get_node_or_null("CoopMenu")
			if cp:
				if bool(cp.get("is_open")) and cp.has_method("close_menu"):
					cp.close_menu()
				elif cp.has_method("open_menu"):
					_close_other_hud_menus(cp)
					cp.open_menu(player)
		&"photo":
			var ps := get_tree().get_first_node_in_group("photo_mode") if is_inside_tree() else null
			if ps == null:
				ps = get_node_or_null("PhotoModeScreen")
			if ps:
				if bool(ps.get("is_active")) and ps.has_method("close_photo_mode"):
					ps.close_photo_mode()
				elif ps.has_method("open_photo_mode"):
					_close_other_hud_menus(ps)
					ps.open_photo_mode(player as Player)

static func _get_icon_texture(icon_id: StringName, fg: Color, highlighted: bool) -> ImageTexture:
	var key := "%s_%s_%d" % [String(icon_id), fg.to_html(false), 1 if highlighted else 0]
	if _icon_cache.has(key):
		return _icon_cache[key]
	var w := 28
	var h := 34
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var bg := Color(0.15, 0.22, 0.19, 0.96) if highlighted else Color(0.07, 0.11, 0.09, 0.88)
	var rim := fg if highlighted else fg.darkened(0.22)
	for y in range(0, 26):
		for x in w:
			var dx := mini(x, w - 1 - x)
			var dy := mini(y, 25 - y)
			if dx + dy < 3:
				continue
			var is_border := x == 1 or x == w - 2 or y == 1 or y == 24 or (dx + dy == 3)
			if x >= 1 and x < w - 1 and y >= 1 and y < 25:
				img.set_pixel(x, y, rim if is_border else bg)
	_draw_glyph(img, icon_id, fg)
	var tex := ImageTexture.create_from_image(img)
	_icon_cache[key] = tex
	return tex

static func _draw_glyph(img: Image, icon_id: StringName, fg: Color) -> void:
	match icon_id:
		&"map":
			for y: int in range(6, 19):
				for x: int in [7, 8, 13, 14, 19, 20]:
					img.set_pixel(x, y, fg)
			for x: int in range(7, 21):
				img.set_pixel(x, 6, fg)
				img.set_pixel(x, 18, fg)
			for y: int in range(10, 16):
				for x: int in range(11, 17):
					if absi(x - 13) + absi(y - 12) <= 2:
						img.set_pixel(x, y, fg.lightened(0.25))
		&"central":
			for y: int in range(6, 19):
				var half: int = (y - 5) / 2
				for x: int in range(14 - half, 14 + half + 1):
					if x >= 6 and x < 22:
						var doorway: bool = y >= 13 and absi(x - 14) <= 2
						if not doorway:
							img.set_pixel(x, y, fg)
		&"inventory":
			for y: int in range(8, 19):
				for x: int in range(8, 20):
					if y == 8 or y == 18 or x == 8 or x == 19 or (y == 13 and x >= 11 and x <= 16):
						img.set_pixel(x, y, fg)
			for x: int in range(11, 17):
				img.set_pixel(x, 6, fg)
		&"build":
			for i: int in range(6, 19):
				img.set_pixel(i, i, fg)
				if i + 1 < 22:
					img.set_pixel(i + 1, i, fg)
			for y: int in range(5, 11):
				for x: int in range(14, 21):
					img.set_pixel(x, y, fg)
		&"cards":
			for y: int in range(6, 19):
				for x: int in range(8, 19):
					if x == 8 or x == 18 or y == 6 or y == 18:
						img.set_pixel(x, y, fg)
			for y: int in range(10, 16):
				for x: int in range(11, 17):
					if absi(x - 13) + absi(y - 12) <= 2:
						img.set_pixel(x, y, fg)
		&"guide":
			for y: int in range(5, 21):
				for x: int in range(6, 22):
					var d2: int = (x - 14) * (x - 14) + (y - 13) * (y - 13)
					if d2 >= 36 and d2 <= 52:
						img.set_pixel(x, y, fg)
					elif (x == 14 and absi(y - 13) <= 5) or (y == 13 and absi(x - 14) <= 5):
						img.set_pixel(x, y, fg)
		&"cosmetics":
			for i: int in range(-6, 7):
				img.set_pixel(14 + i, 13, fg)
				img.set_pixel(14, 13 + i, fg)
				if absi(i) <= 3:
					img.set_pixel(14 + i, 13 + i, fg)
					img.set_pixel(14 + i, 13 - i, fg)
		&"feedback":
			for y: int in range(6, 17):
				for x: int in range(6, 22):
					if y == 6 or y == 16 or x == 6 or x == 21 or (y in [9, 12] and x >= 9 and x <= 18):
						img.set_pixel(x, y, fg)
			img.set_pixel(10, 17, fg)
			img.set_pixel(9, 18, fg)
		&"coop":
			for y: int in range(5, 21):
				for x: int in range(6, 22):
					var d2: int = (x - 14) * (x - 14) + (y - 13) * (y - 13)
					if (d2 >= 36 and d2 <= 52) or (d2 < 52 and (x == 14 or y == 13)):
						img.set_pixel(x, y, fg)
		&"expand_down":
			for i: int in range(-5, 6):
				var dy: int = 5 - absi(i)
				img.set_pixel(14 + i, 8 + dy, fg)
				img.set_pixel(14 + i, 9 + dy, fg)
				img.set_pixel(14 + i, 13 + dy, fg)
		&"expand_up":
			for i: int in range(-5, 6):
				var dy: int = absi(i)
				img.set_pixel(14 + i, 8 + dy, fg)
				img.set_pixel(14 + i, 9 + dy, fg)
				img.set_pixel(14 + i, 13 + dy, fg)
		&"lock":
			for y: int in range(12, 19):
				for x: int in range(8, 20):
					img.set_pixel(x, y, fg)
			for y: int in range(7, 12):
				img.set_pixel(10, y, fg)
				img.set_pixel(17, y, fg)
			for x: int in range(10, 18):
				img.set_pixel(x, 7, fg)
		&"unlock":
			for y: int in range(12, 19):
				for x: int in range(8, 20):
					if y == 12 or y == 18 or x == 8 or x == 19:
						img.set_pixel(x, y, fg)
			for y: int in range(6, 12):
				img.set_pixel(10, y, fg)
			for x: int in range(10, 17):
				img.set_pixel(x, 6, fg)

var _last_zone: String = ""

func _process(_delta: float) -> void:
	if day_night and time_label:
		var hour: float = float(day_night.get("current_time_hours"))
		var period_desc: String = _get_period_description(hour)
		var weather_str: String = _get_weather_badge()
		var money_str := ""
		if player and player.wallet:
			money_str = "  ·  💰 %s" % WalletComponent.format(player.wallet.money)
		time_label.text = "%s%s%s" % [period_desc, weather_str, money_str]

	if player and is_inside_tree():
		var zm := get_tree().get_first_node_in_group("zone_manager")
		var cur_zone: String = zm.get_zone_name_at(player.global_position) if zm and zm.has_method("get_zone_name_at") else ""
		if cur_zone != _last_zone:
			_last_zone = cur_zone
			_update_hud_status()

	_update_underwater_tint()
	_update_rest_label()
	_update_food_buff_label()
	_update_horn_hud()
	_update_ability_bar()
	_update_boss_bar()

func _get_weather_badge() -> String:
	if _weather_node == null and is_inside_tree():
		_weather_node = get_tree().get_first_node_in_group("weather")
	if _weather_node == null:
		return ""
	var rain_val := float(_weather_node.get("rain")) if "rain" in _weather_node else 0.0
	var clouds_val := float(_weather_node.get("clouds")) if "clouds" in _weather_node else 0.0
	if rain_val > 0.15:
		return " · 🌧️"
	elif clouds_val > 0.55:
		return " · ⛅"
	return ""

# ---------------------------------------------------------------- descanso (GDD-10 §10)

var _rest_label: Label

## Linha abaixo das barras: onde está descansando, quanto a Vida volta e o tempo do Descansado
func _update_rest_label() -> void:
	var rest: RestComponent = player.get("rest") if player else null
	var text := rest.status_text() if rest else ""
	if _rest_label == null:
		if text.is_empty():
			return
		var box := get_node_or_null("MarginContainer/ExplorerCard/VBoxContainer")
		if box == null:
			box = get_node_or_null("MarginContainer/VBoxContainer")
		if box == null:
			return
		_rest_label = Label.new()
		_rest_label.name = "RestLabel"
		_rest_label.custom_minimum_size = Vector2(HUD_BAR_WIDTH, 0)
		_rest_label.clip_text = true
		_rest_label.add_theme_font_size_override("font_size", 11)
		_rest_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
		_rest_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		_rest_label.add_theme_constant_override("outline_size", 3)
		box.add_child(_rest_label)
		var bars := box.get_node_or_null("StatusBars")
		if bars:
			box.move_child(_rest_label, bars.get_index() + 1)
	_rest_label.text = text
	_rest_label.visible = not text.is_empty()

var _food_buff_label: Label

## Linha abaixo das barras: buff gastronômico da refeição ativa com ícone e tempo restante (GDD-13 §4 e §5)
func _update_food_buff_label() -> void:
	var food_comp: Node = player.get("food_buff") if player else null
	var has_buff: bool = food_comp != null and bool(food_comp.has_buff())
	if _food_buff_label == null:
		if not has_buff:
			return
		var box := get_node_or_null("MarginContainer/ExplorerCard/VBoxContainer")
		if box == null:
			box = get_node_or_null("MarginContainer/VBoxContainer")
		if box == null:
			return
		_food_buff_label = Label.new()
		_food_buff_label.name = "FoodBuffLabel"
		_food_buff_label.custom_minimum_size = Vector2(HUD_BAR_WIDTH, 0)
		_food_buff_label.clip_text = true
		_food_buff_label.add_theme_font_size_override("font_size", 11)
		_food_buff_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.55))
		_food_buff_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		_food_buff_label.add_theme_constant_override("outline_size", 3)
		box.add_child(_food_buff_label)
		var bars := box.get_node_or_null("StatusBars")
		if bars:
			box.move_child(_food_buff_label, bars.get_index() + 2)
	if has_buff:
		var bname: String = food_comp.active_buff_name
		var time_str: String = food_comp.get_formatted_time_left()
		var icon: String = food_comp.active_buff_icon
		_food_buff_label.text = "%s %s (%s)" % [icon, bname, time_str]
		_food_buff_label.visible = true
	elif _food_buff_label:
		_food_buff_label.visible = false

var _horn_panel: PanelContainer
var _horn_notes_label: Label
var _horn_buffs_label: Label

## Partitura musical e melodias ativas do Berrante de Caça (Hunting Horn) — versão compacta
func _update_horn_hud() -> void:
	var horn: HuntingHornComponent = player.get("hunting_horn") if player else null
	var ws: WeaponStyle = player.get("weapon_style") if player else null
	var has_horn: bool = ws != null and ws.id == &"hunting_horn"
	var buffs_str: String = horn.active_buffs_text() if horn else ""
	if not has_horn and buffs_str.is_empty():
		if _horn_panel:
			_horn_panel.visible = false
		return
	if _horn_panel == null:
		var box := get_node_or_null("MarginContainer/ExplorerCard/VBoxContainer")
		if box == null:
			box = get_node_or_null("MarginContainer/VBoxContainer")
		if box == null:
			return
		_horn_panel = PanelContainer.new()
		_horn_panel.name = "HornPanel"
		_horn_panel.tooltip_text = "Melodias (Mouse 1 + Mouse 2): 🎵 Marcha (+Vel/−Carga) · 🎵🎶 Fúria (+Dano) · 🎵🎶🎼 Baluarte (+Def/Vigor) · 🎼/Bis Cura"
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.06, 0.04, PANEL_BG_ALPHA)
		sb.border_color = Color(0.92, 0.72, 0.30, 0.65)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		_horn_panel.add_theme_stylebox_override("panel", sb)
		if is_hud_locked:
			_horn_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 1)
		_horn_panel.add_child(vbox)
		_horn_notes_label = Label.new()
		_horn_notes_label.custom_minimum_size = Vector2(HUD_BAR_WIDTH - 16.0, 0)
		_horn_notes_label.clip_text = true
		_horn_notes_label.add_theme_font_size_override("font_size", 11)
		_horn_notes_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
		vbox.add_child(_horn_notes_label)
		_horn_buffs_label = Label.new()
		_horn_buffs_label.custom_minimum_size = Vector2(HUD_BAR_WIDTH - 16.0, 0)
		_horn_buffs_label.clip_text = true
		_horn_buffs_label.add_theme_font_size_override("font_size", 11)
		_horn_buffs_label.add_theme_color_override("font_color", Color(0.55, 0.98, 0.78))
		vbox.add_child(_horn_buffs_label)
		box.add_child(_horn_panel)
	_horn_panel.visible = true
	_horn_notes_label.visible = has_horn
	if has_horn and horn:
		_horn_notes_label.text = horn.notes_text()
	_horn_buffs_label.visible = not buffs_str.is_empty()
	_horn_buffs_label.text = "🎶 " + buffs_str

# ---------------------------------------------------------------- fôlego e embaixo d'água

var _oxygen_bar: ProgressBar
var _underwater_tint: ColorRect

## Barra de fôlego (só aparece quando o ar não está cheio) e um véu azul com a câmera na água
func _build_oxygen_ui() -> void:
	var bars := health_bar.get_parent() if health_bar else get_node_or_null("MarginContainer/VBoxContainer/StatusBars")
	if bars:
		_oxygen_bar = ProgressBar.new()
		_oxygen_bar.name = "OxygenBar"
		_oxygen_bar.show_percentage = false
		_oxygen_bar.max_value = Player.OXYGEN_MAX
		_oxygen_bar.value = Player.OXYGEN_MAX
		_oxygen_bar.visible = false
		bars.add_child(_oxygen_bar)
		_style_bar(_oxygen_bar, Color(0.35, 0.88, 0.95, 1.0), Color(0.03, 0.12, 0.16, 0.95), 7, false, Color(0.06, 0.24, 0.28, 0.85), "🫧 Oxigênio: Fôlego restante submerso.")
	_underwater_tint = ColorRect.new()
	_underwater_tint.color = Color(0.05, 0.25, 0.32, 0.45)
	_underwater_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_underwater_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_underwater_tint.visible = false
	add_child(_underwater_tint)
	move_child(_underwater_tint, 0)

func _on_oxygen_changed(current: float, max_val: float) -> void:
	if _oxygen_bar:
		_oxygen_bar.max_value = max_val
		_oxygen_bar.value = current
		_oxygen_bar.visible = current < max_val
		_oxygen_bar.tooltip_text = "🫧 Fôlego: %.0f / %.0f" % [ceilf(current), max_val]
		_oxygen_bar.modulate = Color(1.0, 0.35, 0.3) if current < max_val * 0.25 else Color(1, 1, 1, 1)

func _update_underwater_tint() -> void:
	if _underwater_tint == null or not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	var under := false
	if cam:
		var p := cam.global_position
		under = p.y < RiverSystem.get_water_height(p.z) - 0.05 and RiverSystem.get_distance_to_river(p.x, p.z) < RiverSystem.get_water_half_width(p.z)
	_underwater_tint.visible = under

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		var gs = get_node_or_null("/root/GameSettings")
		if gs:
			gs.set_value("video", "show_tips", not tips_visible)
			gs.save()
		else:
			_set_tips_visible(not tips_visible)

func _on_setting_changed(section: String, key: String, value: Variant) -> void:
	if section == "video" and key == "show_tips":
		_set_tips_visible(value)

func _set_tips_visible(show: bool) -> void:
	tips_visible = show
	if tips_container:
		tips_container.visible = show

func _on_camera_mode_changed(is_first_person: bool) -> void:
	current_view = "👁 1ªP" if is_first_person else "🌄 3ªP"
	_update_hud_status()

func _on_posture_changed(posture: String) -> void:
	current_posture = posture
	_update_hud_status()

func _on_aim_changed(is_aiming: bool) -> void:
	if reticle:
		reticle.visible = is_aiming

func _update_hud_status() -> void:
	if mode_label == null:
		return
	var zone_clean := _last_zone.replace(" (Zona Segura)", "").replace(" (Zona de Pouso)", "")
	var parts: Array[String] = []
	if not zone_clean.is_empty():
		parts.append("📍 " + zone_clean)
	if not current_posture.is_empty() and current_posture != "Em Pé":
		parts.append(current_posture)
	if parts.is_empty():
		parts.append("📍 Fronteira Selvagem")
	mode_label.text = " · ".join(parts)

func _get_period_description(hour: float) -> String:
	if hour >= 5.0 and hour < 7.0:
		return "🌅 Alvorada"
	elif hour >= 7.0 and hour < 11.5:
		return "☀️ Manhã"
	elif hour >= 11.5 and hour < 15.5:
		return "🌞 Meio-dia"
	elif hour >= 15.5 and hour < 18.0:
		return "🌤️ Tarde"
	elif hour >= 18.0 and hour < 20.0:
		return "🌇 Crepúsculo"
	elif hour >= 20.0 or hour < 1.0:
		return "🪐 Noite"
	else:
		return "🌌 Madrugada"

func _on_health_changed(current: float, max_val: float) -> void:
	if health_bar:
		health_bar.max_value = max_val
		health_bar.value = current
		health_bar.tooltip_text = "❤️ Vida: %.0f / %.0f (PV)" % [ceilf(current), max_val]
	if _health_text:
		_health_text.text = "%.0f / %.0f" % [ceilf(current), max_val]

func _on_ether_changed(current: float, max_val: float) -> void:
	if ether_bar:
		ether_bar.max_value = max_val
		ether_bar.value = current
		ether_bar.tooltip_text = "🔷 Éter: %.0f / %.0f (PE)" % [ceilf(current), max_val]

func _on_vigor_changed(current: float, max_val: float) -> void:
	if vigor_bar:
		vigor_bar.max_value = max_val
		vigor_bar.value = current
		vigor_bar.tooltip_text = "⚡ Vigor: %.0f / %.0f (ST)" % [ceilf(current), max_val]

func _on_poise_changed(current: float, max_val: float) -> void:
	if poise_bar:
		poise_bar.max_value = max_val
		poise_bar.value = current
		poise_bar.tooltip_text = "🛡️ Postura: %.0f / %.0f (EQ)" % [ceilf(current), max_val]

# ---------------------------------------------------------------- habilidades de armadura (GDD-12 §6.3)

var _ability_anchor: Control
var _ability_box: HBoxContainer
var _ability_panels: Array[PanelContainer] = []
var _ability_labels: Dictionary = {}
var _carry_label: Label
var _ability_expanded_y: float = 0.0
var _ability_collapsed_y: float = 95.0
var _ability_bar_tween: Tween

func _build_ability_bar() -> void:
	if _ability_box != null:
		return
	var anchor := Control.new()
	anchor.name = "AbilityBar"
	anchor.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	anchor.position.y -= 52.0
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)
	_ability_anchor = anchor
	_ability_expanded_y = anchor.position.y
	_ability_collapsed_y = _ability_expanded_y + 95.0

	var col := VBoxContainer.new()
	col.position = Vector2(-180, 0)
	col.custom_minimum_size = Vector2(360, 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(col)
	_ability_box = HBoxContainer.new()
	_ability_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_ability_box.add_theme_constant_override("separation", 6)
	col.add_child(_ability_box)
	_ability_panels.clear()
	for slot in ForgedItem.ARMOR_SLOTS:
		var panel := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.08, 0.07, PANEL_BG_ALPHA)
		sb.border_color = Color(0.68, 0.56, 0.30, 0.60)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(7)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		panel.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 12)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(96, 0)
		l.text = "(%s) —" % ArmorAbilities.KEY_NAMES[slot]
		l.modulate = Color(1, 1, 1, 0.35)
		panel.add_child(l)
		_ability_box.add_child(panel)
		_ability_panels.append(panel)
		_ability_labels[slot] = l
	_carry_label = Label.new()
	_carry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_carry_label.add_theme_font_size_override("font_size", 12)
	_carry_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.35))
	_carry_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_carry_label.add_theme_constant_override("outline_size", 3)
	col.add_child(_carry_label)

## Três quadros embaixo, no centro: (4) cabeça · (5) peito · (R) botas, com a recarga.
## Abaixo deles, o peso da mochila quando passa do limite.
func _update_ability_bar() -> void:
	var abilities: ArmorAbilityComponent = player.get("armor_abilities") if player else null
	if abilities == null:
		return
	if _ability_box == null:
		_build_ability_bar()
	for slot in _ability_labels:
		var l: Label = _ability_labels[slot]
		var id := abilities.ability_in(slot)
		if id == &"":
			l.text = "(%s) —" % ArmorAbilities.KEY_NAMES[slot]
			l.modulate = Color(1, 1, 1, 0.35)
			continue
		var info := ArmorAbilities.info(id)
		var cd := abilities.cooldown_left(id)
		l.text = "(%s) %s %s%s" % [ArmorAbilities.KEY_NAMES[slot], info.icon, info.name, (" %.0fs" % ceilf(cd)) if cd > 0.0 else ""]
		l.modulate = Color(1, 1, 1, 0.5) if cd > 0.0 else Color(1, 1, 1, 1)
	var inv: InventoryComponent = player.get("inventory")
	if inv and _carry_label:
		var ratio := inv.carry_ratio()
		_carry_label.visible = ratio > 1.0
		if ratio > 1.0:
			_carry_label.text = "🎒 %.0f / %.0f kg%s" % [inv.get_total_weight(), inv.carry_capacity(), " · sem correr nem esquivar" if ratio > Player.OVERLOAD_HARD else " · pesado"]

# ---------------------------------------------------------------- barra do boss (GDD-12 §9)

var _boss_root: VBoxContainer
var _boss_name: Label
var _boss_health: ProgressBar
var _boss_poise: ProgressBar

## Barra no topo enquanto um boss está lutando com você (`boss_bar_info()` com "engaged")
func _update_boss_bar() -> void:
	var info := {}
	if is_inside_tree():
		for b in get_tree().get_nodes_in_group("boss"):
			if b.has_method("boss_bar_info"):
				var i: Dictionary = b.boss_bar_info()
				if i.get("engaged", false):
					info = i
					break
	if _boss_root == null:
		if info.is_empty():
			return
		var anchor := Control.new()
		anchor.name = "BossBar"
		anchor.set_anchors_preset(Control.PRESET_CENTER_TOP)
		anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(anchor)
		_boss_root = VBoxContainer.new()
		_boss_root.position = Vector2(-260, 18)
		_boss_root.custom_minimum_size = Vector2(520, 0)
		_boss_root.add_theme_constant_override("separation", 3)
		anchor.add_child(_boss_root)
		_boss_name = Label.new()
		_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_boss_name.add_theme_font_size_override("font_size", 18)
		_boss_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_boss_name.add_theme_constant_override("outline_size", 5)
		_boss_root.add_child(_boss_name)
		_boss_health = _boss_progress(Color(0.75, 0.16, 0.12), 14)
		_boss_poise = _boss_progress(Color(0.95, 0.75, 0.25), 6)
	_boss_root.visible = not info.is_empty()
	if info.is_empty():
		return
	_boss_name.text = str(info.get("name", ""))
	_boss_health.max_value = float(info.get("max_health", 1.0))
	_boss_health.value = float(info.get("health", 0.0))
	_boss_poise.max_value = float(info.get("max_poise", 1.0))
	_boss_poise.value = float(info.get("poise", 0.0))

func _boss_progress(color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(520, height)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	_boss_root.add_child(bar)
	return bar
