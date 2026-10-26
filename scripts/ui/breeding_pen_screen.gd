class_name BreedingPenScreen
extends Control

## Interface Gráfica do Cercado de Reprodução do Rancho (GDD-04 §2, GDD-08 §4).
## Permite ao jogador gerenciar Reprodutor (♂), Matriz (♀), abastecer o cocho com ração ou adubo,
## acompanhar a gestação com previsão genética e escolher o destino do filhote:
## 1. Abate cuidadoso (+1★ partes Íntegras)
## 2. Promover a montaria própria
## 3. Promover a nova matriz da próxima geração.

const _BreedingPen = preload("res://scripts/systems/breeding_pen.gd")
const _CreatureDNA = preload("res://scripts/data/creature_dna.gd")
const _Player = preload("res://scripts/player.gd")

var pen: _BreedingPen
var player: Node

const TEXT := Color(0.92, 0.92, 0.95)
const TEXT_DIM := Color(0.62, 0.64, 0.70)
const GOLD := Color(0.95, 0.78, 0.35)
const GREEN := Color(0.35, 0.85, 0.45)
const BLUE := Color(0.35, 0.65, 0.95)
const PINK := Color(0.95, 0.45, 0.70)
const PANEL_BG := Color(0.08, 0.08, 0.09, 0.95)

var _status_lbl: Label
var _feed_bar: ProgressBar
var _feed_lbl: Label
var _mutation_badge: Label
var _sire_panel: VBoxContainer
var _dam_panel: VBoxContainer
var _punnett_lbl: Label
var _gestation_bar: ProgressBar
var _gestation_lbl: Label
var _btn_breed: Button
var _offspring_box: VBoxContainer
var _gen_lbl: Label

func _ready() -> void:
	visible = false
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_build_ui()

func open(p_pen: _BreedingPen, p_player: Node) -> void:
	pen = p_pen
	player = p_player
	if pen:
		if not pen.gestation_progress.is_connected(_on_pen_progress):
			pen.gestation_progress.connect(_on_pen_progress)
		if not pen.offspring_born.is_connected(_on_offspring_born):
			pen.offspring_born.connect(_on_offspring_born)
		if not pen.status_message.is_connected(_set_status):
			pen.status_message.connect(_set_status)
	visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh()

func close() -> void:
	if not visible:
		return
	visible = false
	remove_from_group("open_menus")
	if is_inside_tree() and get_tree().get_nodes_in_group("open_menus").is_empty():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _on_pen_progress(progress_ratio: float, time_left: float) -> void:
	if not visible:
		return
	if _gestation_bar:
		_gestation_bar.value = progress_ratio * 100.0
	if _gestation_lbl:
		_gestation_lbl.text = "Gestação: %02d:%02d restantes (%.0f%%)" % [int(time_left) / 60, int(time_left) % 60, progress_ratio * 100.0]
	if _feed_bar and pen:
		_feed_bar.value = pen.feed_level
	if _feed_lbl and pen:
		_feed_lbl.text = "Cocho: %.0f / %.0f comida" % [pen.feed_level, pen.max_feed]

func _on_offspring_born(_dna: _CreatureDNA) -> void:
	if visible:
		_refresh()

func _set_status(msg: String) -> void:
	if _status_lbl:
		_status_lbl.text = msg

func _build_ui() -> void:
	# Backdrop
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.04, 0.04, 0.05, 0.75)
	backdrop.set_anchors_preset(PRESET_FULL_RECT)
	backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close()
	)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(840, 580)
	panel.add_theme_stylebox_override("panel", _box(PANEL_BG, Color(GOLD.r, GOLD.g, GOLD.b, 0.35), 14, 1, Vector2(22, 18)))
	center.add_child(panel)

	var main_col := VBoxContainer.new()
	main_col.add_theme_constant_override("separation", 14)
	panel.add_child(main_col)

	# Header
	var header := HBoxContainer.new()
	main_col.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title_box)

	var title := Label.new()
	title.text = "🏡 Cercado de Reprodução — Criadouro do Rancho"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", GOLD)
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Genética Mendeliana · Sustento no Cocho · Abate Cuidadoso (+1★ Íntegro)"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", TEXT_DIM)
	title_box.add_child(subtitle)

	_gen_lbl = Label.new()
	_gen_lbl.text = "Geração 1"
	_gen_lbl.add_theme_font_size_override("font_size", 15)
	_gen_lbl.add_theme_color_override("font_color", GREEN)
	header.add_child(_gen_lbl)

	var btn_close := Button.new()
	btn_close.text = " ✕ "
	btn_close.add_theme_font_size_override("font_size", 16)
	btn_close.pressed.connect(close)
	header.add_child(btn_close)

	# Upper Section: Feeding Trough (Cocho)
	var trough_box := HBoxContainer.new()
	trough_box.add_theme_constant_override("separation", 12)
	main_col.add_child(trough_box)

	var t_icon := Label.new()
	t_icon.text = "🌾 Cocho:"
	t_icon.add_theme_font_size_override("font_size", 14)
	t_icon.add_theme_color_override("font_color", TEXT)
	trough_box.add_child(t_icon)

	_feed_bar = ProgressBar.new()
	_feed_bar.custom_minimum_size = Vector2(240, 20)
	_feed_bar.max_value = 100.0
	_feed_bar.show_percentage = false
	trough_box.add_child(_feed_bar)

	_feed_lbl = Label.new()
	_feed_lbl.text = "0 / 100 comida"
	_feed_lbl.add_theme_font_size_override("font_size", 13)
	_feed_lbl.add_theme_color_override("font_color", TEXT_DIM)
	trough_box.add_child(_feed_lbl)

	var btn_feed := Button.new()
	btn_feed.text = "➕ Abastecer Cocho"
	btn_feed.pressed.connect(_on_feed_clicked)
	trough_box.add_child(btn_feed)

	_mutation_badge = Label.new()
	_mutation_badge.text = "🧪 Adubo Ativo (+10% Mutação)"
	_mutation_badge.add_theme_font_size_override("font_size", 13)
	_mutation_badge.add_theme_color_override("font_color", GREEN)
	_mutation_badge.visible = false
	trough_box.add_child(_mutation_badge)

	# Middle Section: 3-column Grid (Sire | Center Breeding & Genetics | Dam)
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 14)
	grid.size_flags_vertical = SIZE_EXPAND_FILL
	main_col.add_child(grid)

	# 1. Sire Panel (♂ Reprodutor)
	var sire_card := PanelContainer.new()
	sire_card.size_flags_horizontal = SIZE_EXPAND_FILL
	sire_card.add_theme_stylebox_override("panel", _box(Color(BLUE.r, BLUE.g, BLUE.b, 0.08), Color(BLUE.r, BLUE.g, BLUE.b, 0.35), 10, 1, Vector2(14, 12)))
	grid.add_child(sire_card)

	_sire_panel = VBoxContainer.new()
	_sire_panel.add_theme_constant_override("separation", 8)
	sire_card.add_child(_sire_panel)

	# 2. Center Panel: Genetics & Gestation
	var center_card := PanelContainer.new()
	center_card.custom_minimum_size = Vector2(260, 0)
	center_card.add_theme_stylebox_override("panel", _box(Color(0.04, 0.04, 0.05, 0.6), Color(GOLD.r, GOLD.g, GOLD.b, 0.25), 10, 1, Vector2(14, 12)))
	grid.add_child(center_card)

	var center_col := VBoxContainer.new()
	center_col.add_theme_constant_override("separation", 10)
	center_card.add_child(center_col)

	var c_title := Label.new()
	c_title.text = "🧬 Herança Genética"
	c_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c_title.add_theme_font_size_override("font_size", 15)
	c_title.add_theme_color_override("font_color", GOLD)
	center_col.add_child(c_title)

	_punnett_lbl = Label.new()
	_punnett_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_punnett_lbl.add_theme_font_size_override("font_size", 12)
	_punnett_lbl.add_theme_color_override("font_color", TEXT_DIM)
	center_col.add_child(_punnett_lbl)

	_gestation_bar = ProgressBar.new()
	_gestation_bar.custom_minimum_size = Vector2(0, 18)
	_gestation_bar.max_value = 100.0
	_gestation_bar.show_percentage = false
	center_col.add_child(_gestation_bar)

	_gestation_lbl = Label.new()
	_gestation_lbl.text = "Gestação inativa"
	_gestation_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gestation_lbl.add_theme_font_size_override("font_size", 12)
	_gestation_lbl.add_theme_color_override("font_color", TEXT_DIM)
	center_col.add_child(_gestation_lbl)

	_btn_breed = Button.new()
	_btn_breed.text = "❤️ Iniciar Cruzamento"
	_btn_breed.pressed.connect(_on_breed_clicked)
	center_col.add_child(_btn_breed)

	# 3. Dam Panel (♀ Matriz)
	var dam_card := PanelContainer.new()
	dam_card.size_flags_horizontal = SIZE_EXPAND_FILL
	dam_card.add_theme_stylebox_override("panel", _box(Color(PINK.r, PINK.g, PINK.b, 0.08), Color(PINK.r, PINK.g, PINK.b, 0.35), 10, 1, Vector2(14, 12)))
	grid.add_child(dam_card)

	_dam_panel = VBoxContainer.new()
	_dam_panel.add_theme_constant_override("separation", 8)
	dam_card.add_child(_dam_panel)

	# Lower Section: Offspring Berth
	var off_card := PanelContainer.new()
	off_card.add_theme_stylebox_override("panel", _box(Color(0.06, 0.06, 0.07, 0.8), Color(GOLD.r, GOLD.g, GOLD.b, 0.3), 10, 1, Vector2(16, 10)))
	main_col.add_child(off_card)

	_offspring_box = VBoxContainer.new()
	_offspring_box.add_theme_constant_override("separation", 6)
	off_card.add_child(_offspring_box)

	# Footer Status
	_status_lbl = Label.new()
	_status_lbl.text = "Pronto para reprodução."
	_status_lbl.add_theme_font_size_override("font_size", 13)
	_status_lbl.add_theme_color_override("font_color", TEXT)
	main_col.add_child(_status_lbl)

func _refresh() -> void:
	if pen == null:
		return
	
	if _gen_lbl:
		_gen_lbl.text = "Geração %d" % pen.generation
	if _feed_bar:
		_feed_bar.value = pen.feed_level
	if _feed_lbl:
		_feed_lbl.text = "%.0f / %.0f comida" % [pen.feed_level, pen.max_feed]
	if _mutation_badge:
		_mutation_badge.visible = pen.mutation_boost
	
	# Sire Panel
	_populate_breeder_panel(_sire_panel, pen.sire, true)
	
	# Dam Panel
	_populate_breeder_panel(_dam_panel, pen.dam, false)
	
	# Punnett & Gestation Status
	if pen.sire != null and pen.dam != null:
		var p: Dictionary = pen.punnett_square()
		var lines: Array[String] = []
		var porte_str: Array[String] = []
		for k in p.get("porte", {}):
			porte_str.append("%s: %.0f%%" % [k, p["porte"][k] * 100.0])
		lines.append("• Porte: " + ", ".join(porte_str))
		lines.append("• Chifre: %.0f%% com chifre" % (p.get("chifre", {}).get("com_chifre", 0.0) * 100.0))
		lines.append("• Pelagem: %.0f%% listrada" % (p.get("padrao", {}).get("listrado", 0.0) * 100.0))
		lines.append("• Mutação (*): %.0f%%" % (p.get("mutation_chance", 0.03) * 100.0))
		_punnett_lbl.text = "\n".join(lines)
	else:
		_punnett_lbl.text = "Selecione 1 Reprodutor (♂) e 1 Matriz (♀) da mesma espécie para ver a previsão genética de alelos."
	
	_btn_breed.disabled = not pen.can_start_breeding()
	if pen.is_pregnant:
		var prog := pen.gestation_time / pen.gestation_duration
		_gestation_bar.value = prog * 100.0
		var left := maxf(0.0, pen.gestation_duration - pen.gestation_time)
		_gestation_lbl.text = "Gestação: %02d:%02d restantes (%.0f%%)" % [int(left) / 60, int(left) % 60, prog * 100.0]
	else:
		_gestation_bar.value = 0.0
		_gestation_lbl.text = "Gestação inativa"
	
	# Offspring Section
	_populate_offspring_section()

func _populate_breeder_panel(container: VBoxContainer, dna: _CreatureDNA, is_male: bool) -> void:
	for c in container.get_children():
		c.queue_free()
	
	var title := Label.new()
	title.text = ("♂ Reprodutor (Macho)" if is_male else "♀ Matriz (Fêmea)")
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", BLUE if is_male else PINK)
	container.add_child(title)
	
	if dna != null:
		var info := Label.new()
		info.text = "%s (%s)\nPorte: %s (%d%%)\nChifre: %s · Pelagem: %s" % [
			dna.species_name(),
			"Adulto Fértil",
			"".join(dna.alleles.get("porte", [])),
			roundi(dna.size_factor() * 100.0),
			"Sim" if dna.has_horns() else "Não",
			"Listrada" if dna.is_striped() else "Lisa"
		]
		if dna.is_mutant():
			info.text += "\n✦ MUTANTE Iridescente"
		info.add_theme_font_size_override("font_size", 13)
		info.add_theme_color_override("font_color", TEXT)
		container.add_child(info)
		
		var btn_remove := Button.new()
		btn_remove.text = "Remover Matriz"
		btn_remove.pressed.connect(func():
			if is_male:
				var old := pen.remove_sire()
				if old and player and player.has_method("add_livestock"):
					player.add_livestock(old)
			else:
				var old := pen.remove_dam()
				if old and player and player.has_method("add_livestock"):
					player.add_livestock(old)
			_refresh()
		)
		container.add_child(btn_remove)
	else:
		var empty_lbl := Label.new()
		empty_lbl.text = "Vazio — Adicione animal do Rancho"
		empty_lbl.add_theme_font_size_override("font_size", 13)
		empty_lbl.add_theme_color_override("font_color", TEXT_DIM)
		container.add_child(empty_lbl)
		
		var btn_add := Button.new()
		btn_add.text = "➕ Escolher Matriz"
		btn_add.pressed.connect(func():
			_choose_from_livestock(is_male)
		)
		container.add_child(btn_add)

func _choose_from_livestock(is_male: bool) -> void:
	if player == null or not ("livestock" in player):
		_set_status("❌ Você não possui animais no Rancho. Capture com laço/sedativo!")
		return
	
	var list: Array = player.livestock
	var candidate: _CreatureDNA = null
	var candidate_idx: int = -1
	for i in list.size():
		var d := list[i] as _CreatureDNA
		if is_male and pen.can_set_sire(d):
			candidate = d
			candidate_idx = i
			break
		elif not is_male and pen.can_set_dam(d):
			candidate = d
			candidate_idx = i
			break
	
	if candidate != null:
		player.remove_livestock(candidate_idx)
		if is_male:
			pen.set_sire(candidate)
		else:
			pen.set_dam(candidate)
		_refresh()
	else:
		_set_status("❌ Nenhum %s compatível encontrado no seu Rancho" % ("macho" if is_male else "fêmea"))

func _populate_offspring_section() -> void:
	for c in _offspring_box.get_children():
		c.queue_free()
	
	if pen.offspring != null:
		var off: _CreatureDNA = pen.offspring
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		_offspring_box.add_child(row)
		
		var info_box := VBoxContainer.new()
		info_box.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(info_box)
		
		var title := Label.new()
		title.text = "✨ Filhote Nascido: %s (%s)" % [off.species_name(), "Macho" if off.is_male() else "Fêmea"]
		title.add_theme_font_size_override("font_size", 15)
		title.add_theme_color_override("font_color", GOLD)
		info_box.add_child(title)
		
		var traits_str: Array[String] = ["100% Íntegro (+1★)"]
		if off.is_mutant(): traits_str.append("✦ Iridescente")
		if off.size_factor() >= 1.0: traits_str.append("Denso (TT)")
		if off.mount_speed_factor() >= 1.0: traits_str.append("Veloz")
		if off.has_horns(): traits_str.append("Chifre Maciço")
		
		var sub := Label.new()
		sub.text = "Porte: %s (%d%%) · Traits cultivados: %s" % ["".join(off.alleles.get("porte", [])), roundi(off.size_factor() * 100.0), ", ".join(traits_str)]
		sub.add_theme_font_size_override("font_size", 13)
		sub.add_theme_color_override("font_color", TEXT)
		info_box.add_child(sub)
		
		# 3 Action Buttons (GDD-04 §2)
		var btn_box := HBoxContainer.new()
		btn_box.add_theme_constant_override("separation", 10)
		row.add_child(btn_box)
		
		var btn_slaughter := Button.new()
		btn_slaughter.text = "🔪 Abate Cuidadoso (+1★)"
		btn_slaughter.pressed.connect(func():
			pen.harvest_offspring(player)
			_refresh()
		)
		btn_box.add_child(btn_slaughter)
		
		var btn_mount := Button.new()
		btn_mount.text = "🐎 Promover a Montaria"
		btn_mount.pressed.connect(func():
			pen.promote_offspring_to_mount(player)
			_refresh()
		)
		btn_box.add_child(btn_mount)
		
		var btn_keep := Button.new()
		btn_keep.text = "👑 Nova Matriz Reprodutiva"
		btn_keep.pressed.connect(func():
			pen.promote_offspring_to_breeder()
			_refresh()
		)
		btn_box.add_child(btn_keep)
	elif pen.is_pregnant:
		var prog_lbl := Label.new()
		prog_lbl.text = "⏳ Gestação em andamento... O casal de reprodutores está se alimentando do cocho."
		prog_lbl.add_theme_font_size_override("font_size", 13)
		prog_lbl.add_theme_color_override("font_color", TEXT_DIM)
		_offspring_box.add_child(prog_lbl)
	else:
		var empty_lbl := Label.new()
		empty_lbl.text = "Nenhum filhote no cercado no momento. Defina o casal de reprodutores e inicie o cruzamento."
		empty_lbl.add_theme_font_size_override("font_size", 13)
		empty_lbl.add_theme_color_override("font_color", TEXT_DIM)
		_offspring_box.add_child(empty_lbl)

func _on_feed_clicked() -> void:
	if pen and player:
		pen.feed(player)
		_refresh()

func _on_breed_clicked() -> void:
	if pen:
		pen.start_breeding()
		_refresh()

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
