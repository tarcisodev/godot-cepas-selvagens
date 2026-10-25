extends CanvasLayer
class_name WorldHUD

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

var tips_visible: bool = true
var current_posture: String = "Em Pé"
var current_view: String = "🌄 3ª Pessoa"

var _sky_slider_fill: ColorRect
var _sky_marker: Label
var _sky_track: Panel
var _health_text: Label
var _weather_node: Node

func _ready() -> void:
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
		_set_tips_visible(gs.get_value("video", "show_tips"))
		gs.setting_changed.connect(_on_setting_changed)
	else:
		_set_tips_visible(true)

	_update_hud_status()

## Estiliza o HUD com a identidade visual rústica/alquímica de Cepa Selvagem
func _decorate_hud() -> void:
	var margin := get_node_or_null("MarginContainer") as MarginContainer
	var vbox := get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
	if margin and vbox:
		var card := PanelContainer.new()
		card.name = "ExplorerCard"
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.08, 0.07, 0.86)
		sb.border_color = Color(0.76, 0.62, 0.34, 0.82)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(12)
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 8
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		card.add_theme_stylebox_override("panel", sb)
		margin.remove_child(vbox)
		margin.add_child(card)
		card.add_child(vbox)
		vbox.add_theme_constant_override("separation", 6)

		# Astrolábio visual silencioso (sem segundos piscando!)
		_sky_track = Panel.new()
		_sky_track.custom_minimum_size = Vector2(270, 12)
		var track_sb := StyleBoxFlat.new()
		track_sb.bg_color = Color(0.10, 0.14, 0.22, 0.9)
		track_sb.border_color = Color(0.45, 0.52, 0.42, 0.6)
		track_sb.set_border_width_all(1)
		track_sb.set_corner_radius_all(6)
		_sky_track.add_theme_stylebox_override("panel", track_sb)

		_sky_slider_fill = ColorRect.new()
		_sky_slider_fill.color = Color(0.92, 0.72, 0.30, 0.45)
		_sky_slider_fill.position = Vector2(1, 1)
		_sky_slider_fill.size = Vector2(80, 10)
		_sky_track.add_child(_sky_slider_fill)

		_sky_marker = Label.new()
		_sky_marker.text = "☀️"
		_sky_marker.add_theme_font_size_override("font_size", 11)
		_sky_marker.position = Vector2(0, -3)
		_sky_track.add_child(_sky_marker)

		vbox.add_child(_sky_track)
		if time_label:
			vbox.move_child(_sky_track, time_label.get_index() + 1)

	_style_bar(health_bar, Color(0.84, 0.22, 0.24), Color(0.20, 0.06, 0.07, 0.85), 14, true)
	_style_bar(ether_bar, Color(0.24, 0.62, 0.94), Color(0.06, 0.14, 0.22, 0.85), 9, false)
	_style_bar(vigor_bar, Color(0.26, 0.78, 0.46), Color(0.06, 0.18, 0.11, 0.85), 9, false)
	_style_bar(poise_bar, Color(0.92, 0.74, 0.26), Color(0.20, 0.16, 0.06, 0.85), 6, false)

	# Estiliza o painel de dicas inferior e cria barra rápida de atalhos
	if tips_container:
		var tip_lbl := tips_container.get_node_or_null("ControlsTip") as Label
		if tip_lbl:
			tip_lbl.text = "⚔️ Combate: Esq. Golpe/Combo  |  Dir. Bloqueio (Espada), Investida (Martelo) ou Mira Arcana (Cajado)  |  [C] Esquivar\n🌿 Mundo: [E] Interagir/Esfolar/Montar  |  [T] Tocha  |  [1][2][3] Consumíveis  |  [F] Roda  |  [H] Ocultar dicas"
			tip_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 0.90, 0.9))
			tip_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
			tip_lbl.add_theme_constant_override("outline_size", 4)

	_build_quick_nav_pills()

func _style_bar(bar: ProgressBar, fill_col: Color, bg_col: Color, height: float, show_hp_text: bool) -> void:
	if bar == null:
		return
	bar.modulate = Color(1, 1, 1, 1)
	bar.custom_minimum_size = Vector2(270, height)
	var bg := StyleBoxFlat.new()
	bg.bg_color = bg_col
	bg.border_color = Color(0.0, 0.0, 0.0, 0.6)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill_col
	fg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)

	if show_hp_text:
		_health_text = Label.new()
		_health_text.set_anchors_preset(Control.PRESET_FULL_RECT)
		_health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_health_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_health_text.add_theme_font_size_override("font_size", 11)
		_health_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_health_text.add_theme_constant_override("outline_size", 3)
		bar.add_child(_health_text)

func _build_quick_nav_pills() -> void:
	var nav_margin := MarginContainer.new()
	nav_margin.name = "QuickNavMargin"
	nav_margin.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	nav_margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	nav_margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	nav_margin.add_theme_constant_override("margin_right", 22)
	nav_margin.add_theme_constant_override("margin_bottom", 18)
	add_child(nav_margin)

	var pill_panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.07, 0.85)
	sb.border_color = Color(0.72, 0.58, 0.32, 0.78)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	pill_panel.add_theme_stylebox_override("panel", sb)
	nav_margin.add_child(pill_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	pill_panel.add_child(row)

	var shortcuts := [
		"⛺ [TAB] Central",
		"🎒 [I] Mochila",
		"🏗️ [B] Construir",
		"🃏 [K] Cartas",
		"🧭 [J] Guia",
		"✨ [F9] Cosméticos",
		"💬 [F8] Feedback",
		"🌐 [F7] Coop LAN",
	]
	for text in shortcuts:
		var l := Label.new()
		l.text = text
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Color(0.95, 0.88, 0.68))
		row.add_child(l)

var _last_zone: String = ""

func _process(_delta: float) -> void:
	if day_night and time_label:
		var hour: float = float(day_night.get("current_time_hours"))
		var period_desc: String = _get_period_description(hour)
		var weather_str: String = _get_weather_badge()
		var money_str := ""
		if player and player.wallet:
			money_str = "  ·  💰 %s" % WalletComponent.format(player.wallet.money)
		var moon_str: String = ("  ·  " + day_night.moon_phase_name()) if day_night.has_method("moon_phase_name") else ""
		# Sem segundos/minutos correndo: relógio poético contemplativo!
		time_label.text = "%s%s%s%s" % [period_desc, weather_str, moon_str, money_str]
		_update_sky_track(hour)

	if player and is_inside_tree():
		var zm := get_tree().get_first_node_in_group("zone_manager")
		var cur_zone: String = zm.get_zone_name_at(player.global_position) if zm and zm.has_method("get_zone_name_at") else ""
		if cur_zone != _last_zone:
			_last_zone = cur_zone
			_update_hud_status()

	_update_underwater_tint()
	_update_rest_label()
	_update_ability_bar()
	_update_boss_bar()

func _update_sky_track(hour: float) -> void:
	if _sky_track == null or _sky_slider_fill == null or _sky_marker == null:
		return
	var progress := clampf(hour / 24.0, 0.0, 1.0)
	var track_w: float = maxf(260.0, _sky_track.size.x - 4.0)
	_sky_slider_fill.size.x = maxf(6.0, track_w * progress)
	var is_day := hour >= 5.5 and hour < 18.5
	_sky_slider_fill.color = Color(0.95, 0.74, 0.28, 0.55) if is_day else Color(0.32, 0.52, 0.92, 0.55)
	_sky_marker.text = "☀️" if is_day else "🪐"
	_sky_marker.position.x = clampf(track_w * progress - 7.0, 2.0, track_w - 12.0)

func _get_weather_badge() -> String:
	if _weather_node == null and is_inside_tree():
		_weather_node = get_tree().get_first_node_in_group("weather")
	if _weather_node == null:
		return ""
	var rain_val := float(_weather_node.get("rain")) if "rain" in _weather_node else 0.0
	var clouds_val := float(_weather_node.get("clouds")) if "clouds" in _weather_node else 0.0
	if rain_val > 0.15:
		return "  ·  🌧️ Chuva"
	elif clouds_val > 0.55:
		return "  ·  ⛅ Nublado"
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
		_rest_label.add_theme_font_size_override("font_size", 14)
		_rest_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
		_rest_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		_rest_label.add_theme_constant_override("outline_size", 4)
		box.add_child(_rest_label)
		var bars := box.get_node_or_null("StatusBars")
		if bars:
			box.move_child(_rest_label, bars.get_index() + 1)
	_rest_label.text = text
	_rest_label.visible = not text.is_empty()

# ---------------------------------------------------------------- fôlego e embaixo d'água

var _oxygen_bar: ProgressBar
var _underwater_tint: ColorRect

## Barra de fôlego (só aparece quando o ar não está cheio) e um véu azul com a câmera na água
func _build_oxygen_ui() -> void:
	var bars := health_bar.get_parent() if health_bar else get_node_or_null("MarginContainer/VBoxContainer/StatusBars")
	if bars:
		_oxygen_bar = ProgressBar.new()
		_oxygen_bar.name = "OxygenBar"
		_oxygen_bar.modulate = Color(0.55, 0.85, 1.0, 0.95)
		_oxygen_bar.custom_minimum_size = Vector2(270, 6)
		_oxygen_bar.show_percentage = false
		_oxygen_bar.max_value = Player.OXYGEN_MAX
		_oxygen_bar.value = Player.OXYGEN_MAX
		_oxygen_bar.visible = false
		bars.add_child(_oxygen_bar)
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
		_oxygen_bar.modulate = Color(1.0, 0.35, 0.3) if current < max_val * 0.25 else Color(0.55, 0.85, 1.0, 0.95)

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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
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
	current_view = "👁 1ª Pessoa" if is_first_person else "🌄 3ª Pessoa"
	_update_hud_status()

func _on_posture_changed(posture: String) -> void:
	current_posture = posture
	_update_hud_status()

func _on_aim_changed(is_aiming: bool) -> void:
	if reticle:
		reticle.visible = is_aiming

func _update_hud_status() -> void:
	if mode_label:
		var sg := get_node_or_null("/root/SaveGame")
		var cname := str(sg.get("character_name")) if sg else ""
		var name_prefix := ("👤 " + cname + "  |  ") if not cname.is_empty() else ""
		var zone_str := ("  |  📍 " + _last_zone) if not _last_zone.is_empty() else ""
		mode_label.text = "%s%s  |  %s%s" % [name_prefix, current_view, current_posture, zone_str]

func _get_period_description(hour: float) -> String:
	if hour >= 5.0 and hour < 7.0:
		return "🌅 Alvorada Dourada"
	elif hour >= 7.0 and hour < 11.5:
		return "☀️ Manhã Clara"
	elif hour >= 11.5 and hour < 15.5:
		return "🌞 Sol a Pino"
	elif hour >= 15.5 and hour < 18.0:
		return "🌤️ Tarde Serena"
	elif hour >= 18.0 and hour < 20.0:
		return "🌇 Crepúsculo Âmbar"
	elif hour >= 20.0 or hour < 1.0:
		return "🪐 Noite Estrelada"
	else:
		return "🌌 Madrugada Silenciosa"

func _on_health_changed(current: float, max_val: float) -> void:
	if health_bar:
		health_bar.max_value = max_val
		health_bar.value = current
	if _health_text:
		_health_text.text = "❤️ %.0f / %.0f" % [ceilf(current), max_val]

func _on_ether_changed(current: float, max_val: float) -> void:
	if ether_bar:
		ether_bar.max_value = max_val
		ether_bar.value = current

func _on_vigor_changed(current: float, max_val: float) -> void:
	if vigor_bar:
		vigor_bar.max_value = max_val
		vigor_bar.value = current

func _on_poise_changed(current: float, max_val: float) -> void:
	if poise_bar:
		poise_bar.max_value = max_val
		poise_bar.value = current

# ---------------------------------------------------------------- habilidades de armadura (GDD-12 §6.3)

var _ability_box: HBoxContainer
var _ability_labels: Dictionary = {}
var _carry_label: Label

## Três quadros embaixo, no centro: [4] cabeça · [5] peito · [R] botas, com a recarga.
## Abaixo deles, o peso da mochila quando passa do limite.
func _update_ability_bar() -> void:
	var abilities: ArmorAbilityComponent = player.get("armor_abilities") if player else null
	if abilities == null:
		return
	if _ability_box == null:
		var anchor := Control.new()
		anchor.name = "AbilityBar"
		anchor.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		anchor.position.y -= 70.0
		anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(anchor)
		var col := VBoxContainer.new()
		col.position = Vector2(-210, 0)
		col.custom_minimum_size = Vector2(420, 0)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		anchor.add_child(col)
		_ability_box = HBoxContainer.new()
		_ability_box.alignment = BoxContainer.ALIGNMENT_CENTER
		_ability_box.add_theme_constant_override("separation", 8)
		col.add_child(_ability_box)
		for slot in ForgedItem.ARMOR_SLOTS:
			var panel := PanelContainer.new()
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.05, 0.08, 0.07, 0.78)
			sb.border_color = Color(0.68, 0.56, 0.30, 0.65)
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(8)
			sb.content_margin_left = 10
			sb.content_margin_right = 10
			sb.content_margin_top = 4
			sb.content_margin_bottom = 4
			panel.add_theme_stylebox_override("panel", sb)
			var l := Label.new()
			l.add_theme_font_size_override("font_size", 14)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.custom_minimum_size = Vector2(120, 0)
			panel.add_child(l)
			_ability_box.add_child(panel)
			_ability_labels[slot] = l
		_carry_label = Label.new()
		_carry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_carry_label.add_theme_font_size_override("font_size", 14)
		_carry_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.35))
		_carry_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		_carry_label.add_theme_constant_override("outline_size", 4)
		col.add_child(_carry_label)
	for slot in _ability_labels:
		var l: Label = _ability_labels[slot]
		var id := abilities.ability_in(slot)
		if id == &"":
			l.text = "[%s] —" % ArmorAbilities.KEY_NAMES[slot]
			l.modulate = Color(1, 1, 1, 0.35)
			continue
		var info := ArmorAbilities.info(id)
		var cd := abilities.cooldown_left(id)
		l.text = "[%s] %s %s%s" % [ArmorAbilities.KEY_NAMES[slot], info.icon, info.name, ("  %.0f s" % ceilf(cd)) if cd > 0.0 else ""]
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
