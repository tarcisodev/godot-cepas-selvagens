class_name InventoryScreen
extends Control

## Tela de inventário ([I]): grade de pilhas de material (ADR-0005) com organizador automático
## (raridade, quantidade, peso, cor, nome), filtro por grupo e borda por raridade ou grupo.
## Monta a interface por código; lê o InventoryComponent do player e redesenha quando ele muda.

enum SortMode { RARIDADE, QUANTIDADE, PESO, COR, NOME }
enum BorderMode { RARIDADE, GRUPO }

const SORT_LABELS: Array[String] = ["★ Raridade", "# Quantidade", "⚖ Peso", "🎨 Cor", "Aa Nome"]
const BORDER_LABELS: Array[String] = ["Raridade", "Grupo"]
const COLUMNS: int = 6
const SLOT_SIZE: Vector2 = Vector2(108, 118)
const PANEL_BG := Color(0.07, 0.075, 0.09, 0.96)
const TEXT := Color(0.9, 0.9, 0.94)
const TEXT_DIM := Color(0.55, 0.57, 0.64)

@export var player: Player

## Escolhas da sessão (sobrevivem a fechar e abrir a tela)
static var sort_mode: SortMode = SortMode.RARIDADE
static var descending: bool = true
static var border_mode: BorderMode = BorderMode.RARIDADE
static var group_filter: int = -1  # -1 = todos; senão MaterialData.Category

var _inventory: InventoryComponent
var _grid: GridContainer
var _empty_hint: Label
var _weight_label: Label
var _count_label: Label
var _sort_bar: HBoxContainer
var _border_bar: HBoxContainer
var _group_bar: HBoxContainer
var _dir_button: Button
var _detail: VBoxContainer
var _selected_key: String = ""

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I:
		if visible or get_tree().get_nodes_in_group("open_menus").is_empty():
			toggle()
			get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	_bind_inventory()
	visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	refresh()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)

func close() -> void:
	visible = false
	remove_from_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _bind_inventory() -> void:
	if player == null and is_inside_tree():
		player = get_tree().get_first_node_in_group("player") as Player
	var inv: InventoryComponent = player.inventory if player else null
	if inv == _inventory:
		return
	if _inventory and _inventory.stacks_changed.is_connected(refresh):
		_inventory.stacks_changed.disconnect(refresh)
	_inventory = inv
	if _inventory:
		_inventory.stacks_changed.connect(refresh)

## Ordena pilhas pelo critério; empate cai no nome e depois na qualidade.
## `desc` = maior primeiro; no modo NOME, `desc` = A → Z.
static func sort_stacks(list: Array, mode: SortMode, desc: bool) -> Array:
	var out := list.duplicate()
	out.sort_custom(func(a, b):
		var na := MaterialData.of(a.id).display_name.to_lower()
		var nb := MaterialData.of(b.id).display_name.to_lower()
		if mode == SortMode.NOME:
			if na != nb:
				return (na < nb) if desc else (na > nb)
			return a.quality > b.quality
		var ka := _sort_key(a, mode)
		var kb := _sort_key(b, mode)
		if ka != kb:
			return (ka > kb) if desc else (ka < kb)
		if na != nb:
			return na < nb
		return a.quality > b.quality)
	return out

static func _sort_key(s: Dictionary, mode: SortMode) -> float:
	var data := MaterialData.of(s.id)
	match mode:
		SortMode.RARIDADE:
			return float(s.quality)
		SortMode.QUANTIDADE:
			return float(s.amount)
		SortMode.PESO:
			return data.unit_weight * s.amount
		_:
			# Cor: matiz (0 = vermelho … 1 = violeta) invertido para "maior primeiro" começar
			# no vermelho; cores apagadas (cinza, osso) vão para o fim do arco-íris
			return -(data.color.h if data.color.s > 0.18 else 1.0 + data.color.v)

static func stack_key(s: Dictionary) -> String:
	return "%s|%d|%s" % [s.id, s.quality, ",".join(s.traits)]

func refresh() -> void:
	if _grid == null:
		return
	for c in _grid.get_children():
		c.queue_free()
	var all: Array = _inventory.get_stacks() if _inventory else []
	var shown: Array = all.filter(func(s): return group_filter < 0 or MaterialData.of(s.id).category == group_filter)
	shown = sort_stacks(shown, sort_mode, descending)
	for s in shown:
		_grid.add_child(_make_slot(s))
	_empty_hint.visible = shown.is_empty()
	_empty_hint.text = "Nada aqui ainda.\nColete recursos com [E] pelo vale." if all.is_empty() else "Nenhum item neste grupo."
	_weight_label.text = "⚖ %.1f kg" % (_inventory.get_total_weight() if _inventory else 0.0)
	_count_label.text = "%d pilhas" % all.size()
	_refresh_bars(all)
	var still_there := shown.filter(func(s): return stack_key(s) == _selected_key)
	_show_detail(still_there[0] if not still_there.is_empty() else (shown[0] if not shown.is_empty() else {}))

# ---------------------------------------------------------------- montagem

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1060, 640)
	panel.add_theme_stylebox_override("panel", _box(PANEL_BG, Color(1, 1, 1, 0.08), 14, 1))
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 12)
	margin.add_child(root_box)

	root_box.add_child(_build_header())
	root_box.add_child(_build_toolbar())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root_box.add_child(body)

	var grid_frame := PanelContainer.new()
	grid_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_frame.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.25), Color(1, 1, 1, 0.05), 10, 1))
	body.add_child(grid_frame)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_frame.add_child(scroll)

	var grid_margin := MarginContainer.new()
	grid_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		grid_margin.add_theme_constant_override("margin_" + side, 12)
	scroll.add_child(grid_margin)

	var stack_box := VBoxContainer.new()
	grid_margin.add_child(stack_box)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	stack_box.add_child(_grid)

	_empty_hint = Label.new()
	_empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_hint.custom_minimum_size = Vector2(0, 200)
	_empty_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_hint.add_theme_color_override("font_color", TEXT_DIM)
	stack_box.add_child(_empty_hint)

	body.add_child(_build_detail_panel())

func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var title := Label.new()
	title.text = "🎒  Inventário"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", TEXT)
	row.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_count_label = _chip_label("", TEXT_DIM)
	row.add_child(_count_label)
	_weight_label = _chip_label("", Color(0.95, 0.85, 0.6))
	row.add_child(_weight_label)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.tooltip_text = "Fechar [I] / [Esc]"
	_style_pill(close_btn, Color(0.9, 0.4, 0.4), false)
	close_btn.pressed.connect(close)
	row.add_child(close_btn)
	return row

func _build_toolbar() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	row1.add_child(_caption("Organizar"))
	_sort_bar = HBoxContainer.new()
	_sort_bar.add_theme_constant_override("separation", 6)
	row1.add_child(_sort_bar)
	for i in SORT_LABELS.size():
		var b := Button.new()
		b.text = SORT_LABELS[i]
		b.pressed.connect(func(): sort_mode = i as SortMode; refresh())
		_sort_bar.add_child(b)
	_dir_button = Button.new()
	_dir_button.tooltip_text = "Inverter a ordem"
	_dir_button.pressed.connect(func(): descending = not descending; refresh())
	row1.add_child(_dir_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(spacer)
	row1.add_child(_caption("Borda"))
	_border_bar = HBoxContainer.new()
	_border_bar.add_theme_constant_override("separation", 6)
	row1.add_child(_border_bar)
	for i in BORDER_LABELS.size():
		var b := Button.new()
		b.text = BORDER_LABELS[i]
		b.pressed.connect(func(): border_mode = i as BorderMode; refresh())
		_border_bar.add_child(b)
	box.add_child(row1)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	row2.add_child(_caption("Grupo"))
	_group_bar = HBoxContainer.new()
	_group_bar.add_theme_constant_override("separation", 6)
	row2.add_child(_group_bar)
	for cat in [-1] + Array(MaterialData.Category.values()):
		var b := Button.new()
		b.set_meta("cat", cat)
		b.pressed.connect(func(): group_filter = cat; refresh())
		_group_bar.add_child(b)
	box.add_child(row2)
	return box

func _build_detail_panel() -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(290, 0)
	frame.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.06), 10, 1))
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 16)
	frame.add_child(m)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 8)
	m.add_child(_detail)
	return frame

func _refresh_bars(all: Array) -> void:
	for i in _sort_bar.get_child_count():
		_style_pill(_sort_bar.get_child(i), Color(0.95, 0.78, 0.35), i == sort_mode)
	_dir_button.text = "↓ Maior primeiro" if descending else "↑ Menor primeiro"
	if sort_mode == SortMode.NOME:
		_dir_button.text = "↓ A → Z" if descending else "↑ Z → A"
	elif sort_mode == SortMode.COR:
		_dir_button.text = "↓ Vermelho → Violeta" if descending else "↑ Violeta → Vermelho"
	_style_pill(_dir_button, Color(0.7, 0.75, 0.9), false)
	for i in _border_bar.get_child_count():
		_style_pill(_border_bar.get_child(i), Color(0.6, 0.8, 1.0), i == border_mode)
	for b in _group_bar.get_children():
		var cat: int = b.get_meta("cat")
		var n := all.filter(func(s): return cat < 0 or MaterialData.of(s.id).category == cat).size()
		b.text = "%s  %d" % ["Todos" if cat < 0 else MaterialData.category_name(cat), n]
		var accent := Color(0.75, 0.78, 0.9) if cat < 0 else MaterialData.category_color(cat)
		_style_pill(b, accent, cat == group_filter)

# ---------------------------------------------------------------- slot e detalhe

func _make_slot(s: Dictionary) -> Button:
	var data := MaterialData.of(s.id)
	var rarity := MaterialData.rarity_color(s.quality)
	var group := MaterialData.category_color(data.category)
	var accent := rarity if border_mode == BorderMode.RARIDADE else group
	var selected := stack_key(s) == _selected_key

	var btn := Button.new()
	btn.custom_minimum_size = SLOT_SIZE
	btn.focus_mode = Control.FOCUS_NONE
	btn.tooltip_text = "%s · %s · %d un." % [data.display_name, MaterialData.rarity_name(s.quality), s.amount]
	for st in ["normal", "pressed", "focus"]:
		btn.add_theme_stylebox_override(st, _slot_box(accent, selected, false))
	btn.add_theme_stylebox_override("hover", _slot_box(accent, selected, true))
	btn.pressed.connect(func(): _selected_key = stack_key(s); refresh())

	# Faixa do outro critério no topo: grupo quando a borda é raridade, e vice-versa
	var band := ColorRect.new()
	band.color = group if border_mode == BorderMode.RARIDADE else rarity
	band.position = Vector2(10, 7)
	band.size = Vector2(SLOT_SIZE.x - 20, 3)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(band)

	var disc := Panel.new()
	disc.add_theme_stylebox_override("panel", _box(Color(data.color.r, data.color.g, data.color.b, 0.35), Color(data.color.r, data.color.g, data.color.b, 0.6), 30, 1))
	disc.position = Vector2(SLOT_SIZE.x * 0.5 - 30, 18)
	disc.size = Vector2(60, 60)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(disc)

	var icon := Label.new()
	icon.text = data.icon
	icon.add_theme_font_size_override("font_size", 32)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.position = disc.position
	icon.size = disc.size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)

	var stars := Label.new()
	stars.text = "★".repeat(s.quality)
	stars.add_theme_font_size_override("font_size", 12)
	stars.add_theme_color_override("font_color", rarity)
	stars.position = Vector2(9, SLOT_SIZE.y - 24)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(stars)

	var qty := Label.new()
	qty.text = "×%d" % s.amount
	qty.add_theme_font_size_override("font_size", 15)
	qty.add_theme_color_override("font_color", TEXT)
	qty.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	qty.add_theme_constant_override("outline_size", 4)
	qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	qty.position = Vector2(0, SLOT_SIZE.y - 27)
	qty.size = Vector2(SLOT_SIZE.x - 10, 20)
	qty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(qty)

	if not s.traits.is_empty():
		var badge := Label.new()
		badge.text = "✦"
		badge.tooltip_text = ", ".join(s.traits.map(func(t): return MaterialData.trait_name(t)))
		badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
		badge.position = Vector2(SLOT_SIZE.x - 22, 12)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(badge)
	return btn

func _show_detail(s: Dictionary) -> void:
	for c in _detail.get_children():
		c.queue_free()
	if s.is_empty():
		_selected_key = ""
		_detail.add_child(_caption("Selecione um item"))
		return
	_selected_key = stack_key(s)
	var data := MaterialData.of(s.id)
	var rarity := MaterialData.rarity_color(s.quality)

	var icon := Label.new()
	icon.text = data.icon
	icon.add_theme_font_size_override("font_size", 56)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.add_child(icon)

	var name_l := Label.new()
	name_l.text = data.display_name
	name_l.add_theme_font_size_override("font_size", 20)
	name_l.add_theme_color_override("font_color", rarity.lightened(0.15))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(name_l)

	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 6)
	chips.add_child(_chip_label("%s %s" % ["★".repeat(s.quality), MaterialData.rarity_name(s.quality)], rarity))
	chips.add_child(_chip_label(MaterialData.category_name(data.category), MaterialData.category_color(data.category)))
	_detail.add_child(chips)

	_detail.add_child(HSeparator.new())
	_detail.add_child(_stat_row("Quantidade", "%d" % s.amount))
	_detail.add_child(_stat_row("Peso unitário", "%.2f kg" % data.unit_weight))
	_detail.add_child(_stat_row("Peso da pilha", "%.1f kg" % (data.unit_weight * s.amount)))
	if not s.traits.is_empty():
		_detail.add_child(_stat_row("Traits", ", ".join(s.traits.map(func(t): return MaterialData.trait_name(t)))))

	# Pinhão-Lume: escolhe qual genoma a roda rápida planta com [G] (GDD-10 §9)
	if data.tool_action == &"plantar" and player:
		var chosen: bool = player.get_meta("seed_traits", []) == s.traits
		var seed_btn := Button.new()
		seed_btn.text = "Plantar este com [G]" if not chosen else "Escolhido para plantar"
		_style_pill(seed_btn, MaterialData.category_color(MaterialData.Category.PLANTA), not chosen)
		seed_btn.pressed.connect(func():
			player.set_meta("seed_traits", s.traits.duplicate())
			seed_btn.text = "Escolhido para plantar")
		_detail.add_child(seed_btn)

	if data.is_consumable():
		_detail.add_child(_stat_row("Efeito", data.effect_text()))
		var use_btn := Button.new()
		use_btn.text = "Usar  (%s)" % data.effect_text()
		_style_pill(use_btn, MaterialData.category_color(MaterialData.Category.CONSUMIVEL), true)
		use_btn.disabled = player == null or player.pools == null
		use_btn.pressed.connect(func():
			if not _inventory.use_item(s, player.pools):
				use_btn.text = "Já está cheio")
		_detail.add_child(use_btn)

	_detail.add_child(HSeparator.new())
	var desc := Label.new()
	desc.text = data.description if not data.description.is_empty() else "Sem descrição."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", TEXT_DIM)
	desc.add_theme_font_size_override("font_size", 14)
	_detail.add_child(desc)

# ---------------------------------------------------------------- estilos

func _stat_row(label: String, value: String) -> Control:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", TEXT_DIM)
	l.add_theme_font_size_override("font_size", 14)
	row.add_child(l)
	var v := Label.new()
	v.text = value
	v.add_theme_color_override("font_color", TEXT)
	v.add_theme_font_size_override("font_size", 14)
	row.add_child(v)
	return row

func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", TEXT_DIM)
	l.custom_minimum_size = Vector2(78, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func _chip_label(text: String, accent: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", accent)
	l.add_theme_stylebox_override("normal", _box(Color(accent.r, accent.g, accent.b, 0.12), Color(accent.r, accent.g, accent.b, 0.4), 10, 1, Vector2(10, 3)))
	return l

func _style_pill(btn: Button, accent: Color, active: bool) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 13)
	var fg := Color(0.1, 0.08, 0.05) if active else Color(0.78, 0.8, 0.86)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		btn.add_theme_color_override(c, fg)
	var bg := accent if active else Color(1, 1, 1, 0.05)
	var border := accent if active else Color(accent.r, accent.g, accent.b, 0.35)
	btn.add_theme_stylebox_override("normal", _box(bg, border, 12, 1, Vector2(12, 5)))
	btn.add_theme_stylebox_override("pressed", _box(bg, border, 12, 1, Vector2(12, 5)))
	btn.add_theme_stylebox_override("hover", _box(accent.lightened(0.1) if active else Color(1, 1, 1, 0.1), accent, 12, 1, Vector2(12, 5)))

func _slot_box(accent: Color, selected: bool, hovered: bool) -> StyleBoxFlat:
	var s := _box(Color(accent.r, accent.g, accent.b, 0.16 if selected else (0.1 if hovered else 0.05)), Color(accent.r, accent.g, accent.b, 1.0 if selected else (0.85 if hovered else 0.55)), 10, 3 if selected else 2)
	s.border_width_bottom = 4
	s.shadow_color = Color(accent.r, accent.g, accent.b, 0.35 if selected else 0.12)
	s.shadow_size = 8 if selected else 3
	return s

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
