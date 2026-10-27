class_name CardAlbum
extends CanvasLayer

## Interface do Álbum de Cartas Colecionáveis e Palco de Inspeção 3D (GDD-07 e B08).
## Permite navegar pelas cartas descobertas, inspecionar em 3D, girar, virar (flip) e ver dados táticos.

signal album_opened()
signal album_closed()

var is_open: bool:
	get: return visible

@export var collection_component: CardCollectionComponent

const SLOT_SIZE := Vector2(104, 150)
const CARD_BACK_TEXTURE: Texture2D = preload("res://assets/cards_3d/card_kit/Renders/0_CardBack.png")
const LOCKED_ART_SHADER: Shader = preload("res://materials/card_locked.gdshader")
const LOCKED_ACCENT := Color(0.32, 0.33, 0.4)
const GOLD := Color(0.95, 0.78, 0.35)
# Meia altura/largura que a câmera precisa enquadrar (carta + folga para tilt e flutuação)
const STAGE_FRAME_HALF := Vector2(1.55, 1.95)

var main_panel: Control
var progress_label: Label
var progress_bar: ProgressBar
var cards_grid: GridContainer
var filter_container: HBoxContainer
var close_button: Button

# Palco 3D
var viewport_container: SubViewportContainer
var stage_camera: Camera3D
var backdrop: MeshInstance3D
var card_3d_stage: Card3D
var rarity_ribbon: Label

# Ficha da carta
var card_title_label: Label
var chip_row: HFlowContainer
var stat_ether_label: Label
var stat_power_label: Label
var stat_poise_label: Label
var card_trait_name_label: Label
var card_trait_label: Label
var card_desc_label: Label
var card_lore_label: Label
var flip_button: Button

var rarity_bar: HBoxContainer
var sfx: CardAlbumSfx
var unlock_toast: CardUnlockToast

var _current_filter: String = "Todas"
## 0 = todas as raridades; senão um valor de CardData.Rarity
var _current_rarity: int = 0
var _rarity_group := ButtonGroup.new()
## Cartas descobertas que o jogador ainda não abriu no álbum (selo "NOVA")
var _unseen_ids: Dictionary = {}
var _selected_card: CardData = null
var _slot_buttons: Dictionary = {}
var _filter_group := ButtonGroup.new()
var _locked_art_material := ShaderMaterial.new()
var _is_dragging_3d: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("card_album")
	_setup_nodes()
	visible = false
	if close_button and not close_button.pressed.is_connected(close_album):
		close_button.pressed.connect(close_album)
	if flip_button and not flip_button.pressed.is_connected(_on_flip_pressed):
		flip_button.pressed.connect(_on_flip_pressed)
	if viewport_container:
		viewport_container.resized.connect(_fit_stage_camera)
		viewport_container.mouse_entered.connect(func(): card_3d_stage.set_hovered(true))
		viewport_container.mouse_exited.connect(_on_stage_mouse_exited)

	_setup_filters()
	_setup_rarity_filters()
	_fit_stage_camera()
	_connect_collection.call_deferred()

## Resolve os nós sob demanda: os testes chamam a API antes do _ready rodar
func _setup_nodes() -> void:
	if main_panel == null:
		main_panel = get_node_or_null("MainPanel") as Control
	if progress_label == null:
		progress_label = get_node_or_null("%ProgressLabel") as Label
	if progress_bar == null:
		progress_bar = get_node_or_null("%ProgressBar") as ProgressBar
	if cards_grid == null:
		cards_grid = get_node_or_null("%CardsGrid") as GridContainer
	if filter_container == null:
		filter_container = get_node_or_null("%FilterBar") as HBoxContainer
	if close_button == null:
		close_button = get_node_or_null("%CloseButton") as Button
	if viewport_container == null:
		viewport_container = get_node_or_null("%ViewportContainer") as SubViewportContainer
	if stage_camera == null:
		stage_camera = get_node_or_null("%Camera3D") as Camera3D
	if backdrop == null:
		backdrop = get_node_or_null("%Backdrop") as MeshInstance3D
	if card_3d_stage == null:
		card_3d_stage = get_node_or_null("%ViewportContainer/SubViewport/Card3D") as Card3D
	if rarity_ribbon == null:
		rarity_ribbon = get_node_or_null("%RarityRibbon") as Label
	if card_title_label == null:
		card_title_label = get_node_or_null("%TitleLabel") as Label
	if chip_row == null:
		chip_row = get_node_or_null("%ChipRow") as HFlowContainer
	if stat_ether_label == null:
		stat_ether_label = get_node_or_null("%EtherValue") as Label
	if stat_power_label == null:
		stat_power_label = get_node_or_null("%PowerValue") as Label
	if stat_poise_label == null:
		stat_poise_label = get_node_or_null("%PoiseValue") as Label
	if card_trait_name_label == null:
		card_trait_name_label = get_node_or_null("%TraitName") as Label
	if card_trait_label == null:
		card_trait_label = get_node_or_null("%TraitLabel") as Label
	if card_desc_label == null:
		card_desc_label = get_node_or_null("%DescLabel") as Label
	if card_lore_label == null:
		card_lore_label = get_node_or_null("%LoreLabel") as Label
	if flip_button == null:
		flip_button = get_node_or_null("%FlipButton") as Button
	if rarity_bar == null:
		rarity_bar = get_node_or_null("%RarityBar") as HBoxContainer
	if sfx == null:
		sfx = get_node_or_null("%Sfx") as CardAlbumSfx
	if unlock_toast == null:
		unlock_toast = get_node_or_null("%UnlockToast") as CardUnlockToast
	if _locked_art_material.shader == null:
		_locked_art_material.shader = LOCKED_ART_SHADER

func _setup_filters() -> void:
	if filter_container == null:
		return

	for child in filter_container.get_children():
		if child is Button:
			var btn := child as Button
			var category: String = btn.get_meta("category", btn.text)
			btn.set_meta("category", category)
			_style_filter_pill(btn, _filter_group, GOLD, category == _current_filter)
			var cb = _on_filter_button_pressed.bind(category)
			if not btn.pressed.is_connected(cb):
				btn.pressed.connect(cb)
				btn.pressed.connect(_play.bind(&"filter"))

## Pílulas de raridade criadas em código: "Todas" + uma por raridade, na cor da raridade
func _setup_rarity_filters() -> void:
	if rarity_bar == null or rarity_bar.get_child_count() > 0:
		return
	var options: Array = [[0, "Todas", Color(0.75, 0.78, 0.9)]]
	for r in [CardData.Rarity.COMMON, CardData.Rarity.UNCOMMON, CardData.Rarity.RARE, CardData.Rarity.LEGENDARY]:
		var probe := CardData.new()
		probe.rarity = r
		options.append([r, probe.get_rarity_name(), probe.get_rarity_color()])
	for opt in options:
		var btn := Button.new()
		btn.text = ("  %s  " % opt[1]) if opt[0] == 0 else ("  %s %s  " % ["◆".repeat(opt[0]), opt[1]])
		btn.set_meta("rarity", opt[0])
		_style_filter_pill(btn, _rarity_group, opt[2], opt[0] == _current_rarity)
		if opt[0] != 0:
			btn.add_theme_color_override("font_color", (opt[2] as Color).darkened(0.1))
		btn.pressed.connect(_on_rarity_button_pressed.bind(opt[0]))
		btn.pressed.connect(_play.bind(&"filter"))
		rarity_bar.add_child(btn)

func _style_filter_pill(btn: Button, group: ButtonGroup, accent: Color, pressed: bool) -> void:
	btn.toggle_mode = true
	btn.button_group = group
	btn.button_pressed = pressed
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 30)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(0.72, 0.74, 0.8))
	btn.add_theme_color_override("font_hover_color", Color(0.95, 0.95, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.1, 0.08, 0.04))
	btn.add_theme_color_override("font_hover_pressed_color", Color(0.1, 0.08, 0.04))
	btn.add_theme_stylebox_override("normal", _pill_style(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.08)))
	btn.add_theme_stylebox_override("hover", _pill_style(Color(1, 1, 1, 0.09), Color(1, 1, 1, 0.18)))
	btn.add_theme_stylebox_override("pressed", _pill_style(accent, accent))
	btn.add_theme_stylebox_override("hover_pressed", _pill_style(accent.lightened(0.1), accent))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

## Liga o anúncio de cartas novas à coleção do jogador
func _connect_collection() -> void:
	_resolve_collection()
	if collection_component and not collection_component.card_discovered.is_connected(_on_card_discovered):
		collection_component.card_discovered.connect(_on_card_discovered)

func _resolve_collection() -> void:
	if collection_component == null:
		var player = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
		if player != null:
			collection_component = player.get_node_or_null("CardCollectionComponent") as CardCollectionComponent

func _on_card_discovered(card: CardData) -> void:
	_unseen_ids[card.id] = true
	_setup_nodes()
	if unlock_toast:
		unlock_toast.announce(card)
	if visible:
		refresh_collection()

func _play(id: StringName) -> void:
	if sfx:
		sfx.play(id)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		close_album()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_K or event.physical_keycode == KEY_K:
			toggle_album()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE and visible and card_3d_stage != null:
			_flip_card()
			get_viewport().set_input_as_handled()

func toggle_album() -> void:
	if visible:
		close_album()
	else:
		open_album()

func open_album() -> void:
	_setup_nodes()
	visible = true
	add_to_group("open_menus")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_connect_collection()
	refresh_collection()
	_play(&"open")
	album_opened.emit()
	if main_panel and main_panel.is_inside_tree():
		main_panel.modulate.a = 0.0
		main_panel.create_tween().tween_property(main_panel, "modulate:a", 1.0, 0.18)

func close_album() -> void:
	if visible:
		_play(&"close")
	visible = false
	remove_from_group("open_menus")
	if is_inside_tree() and get_tree().get_nodes_in_group("open_menus").is_empty():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	album_closed.emit()

## Atualiza a grade de cartas e métricas de progresso
func refresh_collection() -> void:
	_setup_nodes()
	_resolve_collection()

	# Atualiza contador de progresso
	var progress = collection_component.get_progress() if collection_component else { "unlocked": 0, "total": CardDatabase.get_total_count(), "percent": 0.0 }
	if progress_label:
		progress_label.text = "Coleção  %d / %d  ·  %.0f%%" % [progress["unlocked"], progress["total"], progress["percent"]]
	if progress_bar:
		progress_bar.value = float(progress["percent"]) / 100.0

	var all_cards = CardDatabase.get_all_cards()
	_update_filter_counts(all_cards)
	_update_rarity_counts(all_cards)

	# Reconstrói a grade
	if cards_grid == null:
		return

	for child in cards_grid.get_children():
		cards_grid.remove_child(child)
		child.free()
	_slot_buttons.clear()

	var first_unlocked: CardData = null

	for card in all_cards:
		if _current_filter != "Todas" and card.category.to_lower() != _current_filter.to_lower():
			continue
		if _current_rarity != 0 and card.rarity != _current_rarity:
			continue

		var is_unlocked: bool = _is_unlocked(card)
		var btn = _create_card_slot_button(card, is_unlocked)
		cards_grid.add_child(btn)
		_slot_buttons[card.id] = btn

		if is_unlocked and first_unlocked == null:
			first_unlocked = card

	if _slot_buttons.is_empty():
		cards_grid.add_child(_make_empty_hint())

	# Mantém a seleção atual se ela continua na grade; senão pega a primeira desbloqueada
	if _selected_card != null and _slot_buttons.has(_selected_card.id) and _is_unlocked(_selected_card):
		_highlight_slot(_selected_card.id)
	elif first_unlocked != null:
		select_card(first_unlocked)

func _is_unlocked(card: CardData) -> bool:
	return collection_component != null and collection_component.is_card_unlocked(card.id)

func _update_filter_counts(all_cards: Array[CardData]) -> void:
	if filter_container == null:
		return
	for child in filter_container.get_children():
		if not child is Button:
			continue
		var category: String = child.get_meta("category", child.text)
		var total := 0
		var owned := 0
		for card in all_cards:
			if category == "Todas" or card.category.to_lower() == category.to_lower():
				total += 1
				if _is_unlocked(card):
					owned += 1
		child.text = "  %s  %d/%d  " % [category, owned, total]

func _update_rarity_counts(all_cards: Array[CardData]) -> void:
	if rarity_bar == null:
		return
	for btn in rarity_bar.get_children():
		var r: int = btn.get_meta("rarity", 0)
		var total := 0
		var owned := 0
		for card in all_cards:
			if r == 0 or card.rarity == r:
				total += 1
				if _is_unlocked(card):
					owned += 1
		btn.tooltip_text = "%d de %d descobertas" % [owned, total]

func _make_empty_hint() -> Label:
	var lbl := Label.new()
	lbl.text = "Nenhuma carta\nnesta combinação\nde filtros."
	lbl.custom_minimum_size = SLOT_SIZE
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.52, 0.6))
	return lbl

func _create_card_slot_button(card: CardData, is_unlocked: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = SLOT_SIZE
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.set_meta("card_id", card.id)

	var accent: Color = card.get_rarity_color() if is_unlocked else LOCKED_ACCENT
	btn.set_meta("accent", accent)
	_apply_slot_style(btn, accent, false)

	# Arte da carta (render 2D do kit, ou verso escurecido se ainda não descoberta)
	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 6
	art.offset_top = 6
	art.offset_right = -6
	art.offset_bottom = -24
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(art)

	var caption := Label.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_top = -22
	caption.offset_bottom = -4
	caption.offset_left = 4
	caption.offset_right = -4
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.add_theme_font_size_override("font_size", 11)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(caption)

	if is_unlocked:
		btn.tooltip_text = "%s\n%s • %s" % [card.title, card.get_rarity_name(), card.get_element_name()]
		caption.text = card.title
		caption.add_theme_color_override("font_color", Color(0.9, 0.9, 0.94))
		art.texture = _load_render(card)
		btn.pressed.connect(func():
			_play(&"select")
			select_card(card))
		if _unseen_ids.has(card.id):
			btn.add_child(_make_new_badge())
	else:
		btn.tooltip_text = "Carta não descoberta"
		caption.text = "? ? ?"
		caption.add_theme_color_override("font_color", Color(0.45, 0.46, 0.52))
		art.texture = CARD_BACK_TEXTURE
		art.material = _locked_art_material
		var lock := Label.new()
		lock.text = "🔒"
		lock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lock.offset_bottom = -18
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock.add_theme_font_size_override("font_size", 26)
		lock.modulate = Color(1, 1, 1, 0.7)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(lock)
		btn.pressed.connect(func():
			_play(&"locked")
			_show_locked_details(card))

	btn.mouse_entered.connect(_on_slot_hover.bind(btn, true))
	btn.mouse_exited.connect(_on_slot_hover.bind(btn, false))
	return btn

## Selo dourado "NOVA" no canto da carta, pulsando até ela ser aberta
func _make_new_badge() -> Control:
	var badge := PanelContainer.new()
	badge.name = "NewBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(SLOT_SIZE.x - 46, -7)
	var style := _pill_style(GOLD, GOLD.lightened(0.3))
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	style.shadow_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.5)
	style.shadow_size = 6
	badge.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = "NOVA"
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.12, 0.08, 0.02))
	badge.add_child(lbl)
	if is_inside_tree():
		var t := badge.create_tween().set_loops()
		t.tween_property(badge, "modulate", Color(1.25, 1.2, 1.0), 0.6).set_trans(Tween.TRANS_SINE)
		t.tween_property(badge, "modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)
	return badge

func _load_render(card: CardData) -> Texture2D:
	if not card.render_path.is_empty() and ResourceLoader.exists(card.render_path):
		return load(card.render_path) as Texture2D
	return CARD_BACK_TEXTURE

func _on_slot_hover(btn: Button, hovered: bool) -> void:
	if not is_instance_valid(btn) or not btn.is_inside_tree():
		return
	btn.pivot_offset = btn.size * 0.5
	if hovered:
		_play(&"hover")
	var t := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2.ONE * (1.06 if hovered else 1.0), 0.16)

func _apply_slot_style(btn: Button, accent: Color, selected: bool) -> void:
	var normal := _slot_style(accent, selected, false)
	var hover := _slot_style(accent, selected, true)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _slot_style(accent: Color, selected: bool, hovered: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(accent.r, accent.g, accent.b, 0.16 if selected else (0.1 if hovered else 0.05))
	s.set_corner_radius_all(10)
	s.set_border_width_all(2 if selected else 1)
	s.border_width_bottom = 3
	s.border_color = Color(accent.r, accent.g, accent.b, 1.0 if selected else (0.75 if hovered else 0.35))
	if selected or hovered:
		s.shadow_color = Color(accent.r, accent.g, accent.b, 0.35 if selected else 0.2)
		s.shadow_size = 10 if selected else 6
	return s

func _highlight_slot(card_id: StringName) -> void:
	for id in _slot_buttons:
		var btn: Button = _slot_buttons[id]
		_apply_slot_style(btn, btn.get_meta("accent", LOCKED_ACCENT), id == card_id)

## Exibe os dados da carta selecionada no palco 3D e nos painéis
func select_card(card: CardData) -> void:
	_setup_nodes()
	_selected_card = card
	_highlight_slot(card.id)
	if _unseen_ids.erase(card.id) and _slot_buttons.has(card.id):
		var badge: Node = (_slot_buttons[card.id] as Node).get_node_or_null("NewBadge")
		if badge:
			badge.queue_free()
	if card_3d_stage:
		card_3d_stage.reset_orientation()
		card_3d_stage.display_card(card)
	_set_stage_tint(card.get_element_color())

	var rarity_color := card.get_rarity_color()
	if rarity_ribbon:
		rarity_ribbon.text = "%s  %s  %s" % [_rarity_pips(card.rarity), card.get_rarity_name().to_upper(), _rarity_pips(card.rarity)]
		rarity_ribbon.add_theme_color_override("font_color", rarity_color)

	if card_title_label:
		card_title_label.text = card.title
		card_title_label.add_theme_color_override("font_color", rarity_color.lightened(0.15))

	_set_chips([
		[card.category, Color(0.75, 0.78, 0.9)],
		[card.get_element_name(), card.get_element_color()],
		[card.get_rarity_name(), rarity_color],
	])

	_set_stats(str(card.ether_cost), str(card.power), str(card.poise))

	if card_trait_name_label:
		card_trait_name_label.text = "✦ " + card.trait_name
	if card_trait_label:
		card_trait_label.text = card.trait_description
	if card_desc_label:
		card_desc_label.text = card.description
	if card_lore_label:
		card_lore_label.text = "“%s”" % card.flavor_lore
	if flip_button:
		flip_button.disabled = false

func _show_locked_details(card: CardData) -> void:
	_setup_nodes()
	_selected_card = null
	_highlight_slot(card.id)
	if card_3d_stage:
		card_3d_stage.reset_orientation()
		card_3d_stage.display_card(null)
	_set_stage_tint(Color(0.35, 0.36, 0.42))

	if rarity_ribbon:
		rarity_ribbon.text = "NÃO DESCOBERTA"
		rarity_ribbon.add_theme_color_override("font_color", Color(0.55, 0.56, 0.62))

	if card_title_label:
		card_title_label.text = "??? (Não Descoberta)"
		card_title_label.add_theme_color_override("font_color", Color(0.55, 0.56, 0.62))

	_set_chips([[card.category, Color(0.75, 0.78, 0.9)], ["Desconhecida", Color(0.5, 0.5, 0.55)]])
	_set_stats("?", "?", "?")

	if card_trait_name_label:
		card_trait_name_label.text = "✦ Trait oculto"
	if card_trait_label:
		card_trait_label.text = "Descubra a carta para revelar seu efeito no duelo."
	if card_desc_label:
		card_desc_label.text = "Derrote monstros, quebre partes anatômicas ou cultive espécimes para catalogar este exemplar."
	if card_lore_label:
		card_lore_label.text = ""
	if flip_button:
		flip_button.disabled = true

func _set_stats(ether: String, power: String, poise: String) -> void:
	if stat_ether_label:
		stat_ether_label.text = ether
	if stat_power_label:
		stat_power_label.text = power
	if stat_poise_label:
		stat_poise_label.text = poise

## Recria as etiquetas (categoria, elemento, raridade) da ficha. Cada item: [texto, cor]
func _set_chips(items: Array) -> void:
	if chip_row == null:
		return
	for child in chip_row.get_children():
		chip_row.remove_child(child)
		child.free()
	for item in items:
		var color: Color = item[1]
		var chip := PanelContainer.new()
		var style := _pill_style(Color(color.r, color.g, color.b, 0.12), Color(color.r, color.g, color.b, 0.5))
		chip.add_theme_stylebox_override("panel", style)
		var lbl := Label.new()
		lbl.text = item[0]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", color.lightened(0.2))
		chip.add_child(lbl)
		chip_row.add_child(chip)

func _pill_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(12)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s

func _rarity_pips(rarity: int) -> String:
	return "✦".repeat(rarity)

func _set_stage_tint(color: Color) -> void:
	if backdrop == null or not (backdrop.mesh is QuadMesh):
		return
	var mat := (backdrop.mesh as QuadMesh).material as ShaderMaterial
	if mat == null:
		return
	var from: Color = mat.get_shader_parameter("tint")
	if is_inside_tree():
		create_tween().tween_method(func(c: Color): mat.set_shader_parameter("tint", c), from, color, 0.35)
	else:
		mat.set_shader_parameter("tint", color)

## Afasta a câmera para a carta inteira caber no palco, qualquer que seja a proporção
func _fit_stage_camera() -> void:
	if stage_camera == null or viewport_container == null:
		return
	var size := viewport_container.size
	if size.x < 1.0 or size.y < 1.0:
		return
	var aspect := size.x / size.y
	var half_fov := deg_to_rad(stage_camera.fov * 0.5)
	var needed_half_h := maxf(STAGE_FRAME_HALF.y, STAGE_FRAME_HALF.x / aspect)
	stage_camera.position = Vector3(0.0, 0.0, needed_half_h / tan(half_fov))

func _on_filter_button_pressed(category: String) -> void:
	_current_filter = category
	_sync_pill(filter_container, "category", category)
	refresh_collection()

## Mantém a pílula ativa coerente quando o filtro muda por código (o ButtonGroup solta as outras)
func _sync_pill(bar: Container, meta: String, value: Variant) -> void:
	if bar == null:
		return
	for btn in bar.get_children():
		if btn is Button and btn.has_meta(meta) and btn.get_meta(meta) == value and not btn.button_pressed:
			btn.button_pressed = true

func _on_rarity_button_pressed(rarity: int) -> void:
	_current_rarity = rarity
	_sync_pill(rarity_bar, "rarity", rarity)
	refresh_collection()

func _on_flip_pressed() -> void:
	_flip_card()

func _flip_card() -> void:
	if card_3d_stage == null or (flip_button and flip_button.disabled):
		return
	_play(&"flip")
	card_3d_stage.toggle_flip()

func _on_stage_mouse_exited() -> void:
	_is_dragging_3d = false
	if card_3d_stage:
		card_3d_stage.set_hovered(false)

func _on_viewport_gui_input(event: InputEvent) -> void:
	if card_3d_stage == null:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging_3d = event.pressed
			_last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_flip_card()

	elif event is InputEventMouseMotion:
		if _is_dragging_3d:
			var delta: Vector2 = event.position - _last_mouse_pos
			card_3d_stage.add_manual_orbit(delta.x, delta.y)
			_last_mouse_pos = event.position
		else:
			# Tilt holográfico baseado na posição do mouse dentro do container
			var size: Vector2 = viewport_container.size if viewport_container else Vector2(300, 300)
			var norm: Vector2 = ((event.position / size) * 2.0) - Vector2.ONE
			card_3d_stage.set_tilt_normalized(norm)
