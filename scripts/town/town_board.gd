class_name TownBoard
extends Control

## Quadro de Obras da Vila (GDD-08 §6.1): lista as obras, mostra a etapa atual e deixa doar
## materiais do inventário — por material ou "tudo o que falta e eu tenho".
## Doar dá Reputação da Vila (1 por unidade), guardada no CityHub.
## Aba Contratos (GDD-05 §5): entregar material comum por Dólares de Sucata.
## Modo Loja: a mesma tela vira a loja da Alquimista (o ralo de moeda do slice).

enum Mode { OBRAS, CONTRATOS, LOJA }

const PANEL_BG := Color(0.08, 0.075, 0.07, 0.96)
const TEXT := Color(0.92, 0.9, 0.86)
const TEXT_DIM := Color(0.6, 0.57, 0.52)
const GOLD := Color(0.95, 0.78, 0.35)

var city: Node  # CityHub
var player: Player

var mode: Mode = Mode.OBRAS

var _list: VBoxContainer
var _detail: VBoxContainer
var _rep_label: Label
var _money_label: Label
var _title: Label
var _hint: Label
var _tabs: HBoxContainer
var _selected: TownProject

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func open(p: Player) -> void:
	if mode == Mode.LOJA:
		mode = Mode.OBRAS
	_show(p)

func open_shop(p: Player) -> void:
	mode = Mode.LOJA
	_show(p)

func _show(p: Player) -> void:
	player = p
	visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _selected == null or _selected.is_complete():
		var open_projects := _projects().filter(func(pr): return not pr.is_complete())
		_selected = open_projects[0] if not open_projects.is_empty() else (_projects()[0] if not _projects().is_empty() else null)
	refresh()

func close() -> void:
	visible = false
	remove_from_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _projects() -> Array:
	return city.get_projects() if city else []

func refresh() -> void:
	if not visible:
		return
	for c in _list.get_children():
		c.queue_free()
	_rep_label.text = "⭐ Reputação: %d" % (city.reputation if city else 0)
	_money_label.text = "💰 %s" % WalletComponent.format(player.wallet.money if player and player.wallet else 0)
	_tabs.visible = mode != Mode.LOJA
	for i in _tabs.get_child_count():
		_style_button(_tabs.get_child(i), GOLD, i == mode)
	_list.visible = mode == Mode.OBRAS
	match mode:
		Mode.OBRAS:
			_title.text = "📜  Obras da Vila da Esperança"
			_hint.text = "A vila cresce com o que os andarilhos trazem. Cada obra tem 3 etapas; complete a etapa e a vila muda na hora."
			for pr in _projects():
				_list.add_child(_project_row(pr))
			_show_detail()
		Mode.CONTRATOS:
			_title.text = "📜  Contratos da Vila"
			_hint.text = "Entregue o material pedido e receba Dólares de Sucata. Cada contrato cumprido abre outro."
			_show_contracts()
		Mode.LOJA:
			_title.text = "⚗️  Loja da Alquimista"
			var off := roundi(city.shop_discount() * 100.0) if city else 0
			_hint.text = "Poções e mantimentos para a estrada. A loja não compra nada de volta." + ("  Desconto de reputação: −%d%%." % off if off > 0 else "  Reputação na vila dá desconto.")
			_show_shop()

# ---------------------------------------------------------------- doação

func _donate(material_id: StringName, amount: int) -> void:
	if _selected == null or player == null:
		return
	var n: int = city.donate(_selected, player, material_id, amount)
	if n > 0 and player.has_signal("posture_changed"):
		var data := MaterialData.of(material_id)
		player.posture_changed.emit("🏗️ Doou %d %s para %s" % [n, data.display_name, _selected.display_name])
	refresh()

func _donate_all() -> void:
	if _selected == null:
		return
	# Só a etapa atual: se ela fechar no meio, a próxima fica para outra doação
	var stage_at_start := _selected.stage
	for id in _selected.missing():
		if _selected.stage != stage_at_start:
			break
		_donate(id, _selected.missing().get(id, 0))

# ---------------------------------------------------------------- montagem

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 580)
	panel.add_theme_stylebox_override("panel", _box(PANEL_BG, Color(GOLD.r, GOLD.g, GOLD.b, 0.25), 14, 1))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 12)
	margin.add_child(root_box)

	var header := HBoxContainer.new()
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", TEXT)
	header.add_child(_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	for tab_mode in [Mode.OBRAS, Mode.CONTRATOS]:
		var tab := Button.new()
		tab.text = "Obras" if tab_mode == Mode.OBRAS else "Contratos"
		tab.pressed.connect(func(): mode = tab_mode; refresh())
		_tabs.add_child(tab)
	header.add_child(_tabs)
	for text_color in [GOLD, Color(0.75, 0.95, 0.6)]:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(14, 0)
		header.add_child(gap)
		var l := Label.new()
		l.add_theme_color_override("font_color", text_color)
		l.add_theme_font_size_override("font_size", 15)
		header.add_child(l)
		if text_color == GOLD:
			_rep_label = l
		else:
			_money_label = l
	var close_btn := Button.new()
	close_btn.text = "  ✕  "
	_style_button(close_btn, Color(0.9, 0.4, 0.4), false)
	close_btn.pressed.connect(close)
	header.add_child(close_btn)
	root_box.add_child(header)

	_hint = Label.new()
	_hint.add_theme_color_override("font_color", TEXT_DIM)
	_hint.add_theme_font_size_override("font_size", 13)
	root_box.add_child(_hint)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root_box.add_child(body)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(330, 0)
	_list.add_theme_constant_override("separation", 8)
	body.add_child(_list)
	var detail_frame := PanelContainer.new()
	detail_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_frame.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.07), 10, 1))
	body.add_child(detail_frame)
	var dm := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		dm.add_theme_constant_override("margin_" + side, 18)
	detail_frame.add_child(dm)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 10)
	dm.add_child(_detail)

func _project_row(pr: TownProject) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 62)
	btn.focus_mode = Control.FOCUS_NONE
	var selected := pr == _selected
	var accent := Color(0.45, 0.85, 0.5) if pr.is_complete() else GOLD
	for st in ["normal", "pressed", "focus"]:
		btn.add_theme_stylebox_override(st, _box(Color(accent.r, accent.g, accent.b, 0.14 if selected else 0.04), Color(accent.r, accent.g, accent.b, 0.9 if selected else 0.3), 10, 2 if selected else 1))
	btn.add_theme_stylebox_override("hover", _box(Color(accent.r, accent.g, accent.b, 0.1), Color(accent.r, accent.g, accent.b, 0.7), 10, 1))
	btn.pressed.connect(func(): _selected = pr; refresh())

	var name_l := Label.new()
	name_l.text = "%s  %s" % [pr.icon, pr.display_name]
	name_l.add_theme_font_size_override("font_size", 16)
	name_l.add_theme_color_override("font_color", TEXT)
	name_l.position = Vector2(14, 8)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(name_l)

	var stage_l := Label.new()
	stage_l.text = "✅ Pronto" if pr.is_complete() else "%s · etapa %d de 3" % [pr.stage_name(), pr.stage + 1]
	stage_l.add_theme_font_size_override("font_size", 12)
	stage_l.add_theme_color_override("font_color", accent)
	stage_l.position = Vector2(14, 34)
	stage_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(stage_l)

	# Três barrinhas: uma por etapa
	for i in 3:
		var bar := ColorRect.new()
		var fill := 1.0 if i < pr.stage else (pr.stage_progress() if i == pr.stage else 0.0)
		bar.color = Color(1, 1, 1, 0.08)
		bar.size = Vector2(36, 6)
		bar.position = Vector2(200 + i * 40, 40)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(bar)
		var fill_rect := ColorRect.new()
		fill_rect.color = accent
		fill_rect.size = Vector2(36 * fill, 6)
		fill_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(fill_rect)
	return btn

func _show_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var pr := _selected
	if pr == null:
		return
	var title := Label.new()
	title.text = "%s  %s" % [pr.icon, pr.display_name]
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", TEXT)
	_detail.add_child(title)
	var purpose := Label.new()
	purpose.text = pr.purpose
	purpose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	purpose.add_theme_color_override("font_color", TEXT_DIM)
	purpose.add_theme_font_size_override("font_size", 14)
	_detail.add_child(purpose)

	var steps := HBoxContainer.new()
	steps.add_theme_constant_override("separation", 8)
	for i in 3:
		var done := i < pr.stage
		var current := i == pr.stage
		var chip := Label.new()
		chip.text = "%s %s" % ["✔" if done else ("●" if current else "○"), TownProject.STAGE_NAMES[i]]
		var c := Color(0.45, 0.85, 0.5) if done else (GOLD if current else TEXT_DIM)
		chip.add_theme_color_override("font_color", c)
		chip.add_theme_font_size_override("font_size", 13)
		chip.add_theme_stylebox_override("normal", _box(Color(c.r, c.g, c.b, 0.1), Color(c.r, c.g, c.b, 0.4), 10, 1, Vector2(10, 3)))
		steps.add_child(chip)
	_detail.add_child(steps)
	_detail.add_child(HSeparator.new())

	if pr.is_complete():
		var done_l := Label.new()
		done_l.text = "✅ Obra concluída. Obrigado, andarilho!"
		done_l.add_theme_color_override("font_color", Color(0.45, 0.85, 0.5))
		done_l.add_theme_font_size_override("font_size", 16)
		_detail.add_child(done_l)
		return

	var inv: InventoryComponent = player.inventory if player else null
	var costs := pr.current_costs()
	for id in costs:
		_detail.add_child(_material_row(pr, id, costs[id], inv))

	var all_btn := Button.new()
	all_btn.text = "Doar tudo o que falta e eu tenho"
	var can_any := false
	for id in pr.missing():
		if inv and inv.get_material_count(id) > 0:
			can_any = true
	all_btn.disabled = not can_any
	_style_button(all_btn, GOLD, true)
	all_btn.pressed.connect(_donate_all)
	_detail.add_child(all_btn)

func _material_row(pr: TownProject, id: StringName, need: int, inv: InventoryComponent) -> Control:
	var data := MaterialData.of(id)
	var have := inv.get_material_count(id) if inv else 0
	var got: int = mini(int(pr.deposited.get(id, 0)), need)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var icon := Label.new()
	icon.text = data.icon
	icon.add_theme_font_size_override("font_size", 24)
	icon.custom_minimum_size = Vector2(34, 0)
	row.add_child(icon)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	var name_l := Label.new()
	name_l.text = data.display_name
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.add_theme_color_override("font_color", TEXT)
	top.add_child(name_l)
	var count_l := Label.new()
	count_l.text = "%d / %d" % [got, need]
	count_l.add_theme_color_override("font_color", Color(0.45, 0.85, 0.5) if got >= need else TEXT)
	top.add_child(count_l)
	col.add_child(top)
	var bar := ProgressBar.new()
	bar.max_value = need
	bar.value = got
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.add_theme_stylebox_override("background", _box(Color(1, 1, 1, 0.07), Color(0, 0, 0, 0), 4, 0))
	bar.add_theme_stylebox_override("fill", _box(data.color.lightened(0.15), Color(0, 0, 0, 0), 4, 0))
	col.add_child(bar)
	var have_l := Label.new()
	have_l.text = "Você tem %d" % have
	have_l.add_theme_font_size_override("font_size", 12)
	have_l.add_theme_color_override("font_color", TEXT_DIM if have > 0 else Color(0.85, 0.45, 0.4))
	col.add_child(have_l)
	row.add_child(col)

	var left := need - got
	var one := Button.new()
	one.text = "+1"
	one.disabled = left <= 0 or have <= 0
	_style_button(one, data.color.lightened(0.2), false)
	one.pressed.connect(func(): _donate(id, 1))
	row.add_child(one)
	var max_btn := Button.new()
	max_btn.text = "Doar %d" % mini(left, have) if left > 0 and have > 0 else "Doar"
	max_btn.disabled = left <= 0 or have <= 0
	_style_button(max_btn, data.color.lightened(0.2), false)
	max_btn.pressed.connect(func(): _donate(id, left))
	row.add_child(max_btn)
	return row

# ---------------------------------------------------------------- contratos e loja

func _show_contracts() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var inv: InventoryComponent = player.inventory if player else null
	for i in city.contracts.size():
		var c: Dictionary = city.contracts[i]
		var data := MaterialData.of(c.id)
		var have := inv.get_material_count(c.id) if inv else 0
		var row := _item_row(data, "Entregar %d × %s" % [c.amount, data.display_name], "Você tem %d" % have, have >= c.amount)
		row.add_child(_value_label("+%s" % WalletComponent.format(c.reward), Color(0.75, 0.95, 0.6)))
		var btn := Button.new()
		btn.text = "Entregar"
		btn.disabled = have < c.amount
		_style_button(btn, GOLD, true)
		var index: int = i
		var reward: int = c.reward
		btn.pressed.connect(func(): _deliver(index, reward))
		row.add_child(btn)
		_detail.add_child(row)
		_detail.add_child(HSeparator.new())

func _deliver(index: int, reward: int) -> void:
	if city.deliver_contract(index, player) and player.has_signal("posture_changed"):
		player.posture_changed.emit("💰 Contrato cumprido: +%s" % WalletComponent.format(reward))
	refresh()

func _show_shop() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var money: int = player.wallet.money if player and player.wallet else 0
	for id in CityHub.SHOP_PRICES:
		var data := MaterialData.of(id)
		var price: int = city.shop_price(id)
		var have := player.inventory.get_material_count(id) if player and player.inventory else 0
		var row := _item_row(data, data.display_name, "%s · você tem %d" % [data.effect_text(), have], true)
		row.add_child(_value_label(WalletComponent.format(price), TEXT if money >= price else Color(0.85, 0.45, 0.4)))
		var btn := Button.new()
		btn.text = "Comprar"
		btn.disabled = money < price
		_style_button(btn, GOLD, true)
		var item_id: StringName = id
		btn.pressed.connect(func(): _buy(item_id, price))
		row.add_child(btn)
		_detail.add_child(row)
		_detail.add_child(HSeparator.new())

func _buy(item_id: StringName, price: int) -> void:
	var data := MaterialData.of(item_id)
	if city.buy(item_id, player) and player.has_signal("posture_changed"):
		player.posture_changed.emit("%s Comprou %s por %s" % [data.icon, data.display_name, WalletComponent.format(price)])
	refresh()

func _item_row(data: MaterialData, title: String, sub: String, ok: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var icon := Label.new()
	icon.text = data.icon
	icon.add_theme_font_size_override("font_size", 28)
	icon.custom_minimum_size = Vector2(40, 0)
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := Label.new()
	t.text = title
	t.add_theme_color_override("font_color", TEXT)
	t.add_theme_font_size_override("font_size", 16)
	col.add_child(t)
	var st := Label.new()
	st.text = sub
	st.add_theme_color_override("font_color", TEXT_DIM if ok else Color(0.85, 0.45, 0.4))
	st.add_theme_font_size_override("font_size", 12)
	col.add_child(st)
	row.add_child(col)
	return row

func _value_label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 16)
	l.custom_minimum_size = Vector2(80, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l

func _style_button(btn: Button, accent: Color, filled: bool) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 14)
	var fg := Color(0.12, 0.09, 0.05) if filled else TEXT
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		btn.add_theme_color_override(c, fg)
	btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.43, 0.4))
	var bg := accent if filled else Color(accent.r, accent.g, accent.b, 0.12)
	btn.add_theme_stylebox_override("normal", _box(bg, accent, 10, 1, Vector2(14, 6)))
	btn.add_theme_stylebox_override("hover", _box(bg.lightened(0.12), accent, 10, 1, Vector2(14, 6)))
	btn.add_theme_stylebox_override("pressed", _box(bg.darkened(0.1), accent, 10, 1, Vector2(14, 6)))
	btn.add_theme_stylebox_override("disabled", _box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.08), 10, 1, Vector2(14, 6)))

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
