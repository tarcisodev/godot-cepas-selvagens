class_name MarketScreen
extends Control

## Tela do Mercado da Vila (GDD-05 §6): fazer encomendas (comprar) e ordens de venda, ver as
## ordens abertas, cancelar e retirar o que a caravana deixou.

const PANEL_BG := Color(0.08, 0.075, 0.07, 0.96)
const TEXT := Color(0.92, 0.9, 0.86)
const TEXT_DIM := Color(0.6, 0.57, 0.52)
const GOLD := Color(0.95, 0.78, 0.35)
const BUY := Color(0.45, 0.75, 0.95)
const SELL := Color(0.55, 0.88, 0.55)
const RED := Color(0.9, 0.42, 0.38)

var city: Node  # CityHub
var player: Player

var _selling: bool = false
var _material: StringName = &"madeira"
var _money_label: Label
var _goods: GridContainer
var _form: VBoxContainer
var _form_head: VBoxContainer
var _form_foot: VBoxContainer
var _orders: VBoxContainer
var _qty: SpinBox
var _price: SpinBox
var _summary: Label
var _message: Label

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
	player = p
	visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_message.text = ""
	_reset_price()
	refresh()

func close() -> void:
	visible = false
	remove_from_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _market() -> VillageMarket:
	return city.market

func refresh() -> void:
	if not visible:
		return
	_money_label.text = "💰 %s" % WalletComponent.format(player.wallet.money if player and player.wallet else 0)
	_fill_goods()
	_fill_form()
	_fill_orders()

# ---------------------------------------------------------------- lado esquerdo: nova ordem

func _fill_goods() -> void:
	for c in _goods.get_children():
		c.queue_free()
	for id in VillageMarket.GOODS:
		var data := MaterialData.of(id)
		var have := player.inventory.get_material_count(id) if player and player.inventory else 0
		var b := Button.new()
		b.text = "%s %d" % [data.icon, have]
		b.tooltip_text = "%s · valor-base %s" % [data.display_name, WalletComponent.format(roundi(data.base_value))]
		b.custom_minimum_size = Vector2(66, 36)
		_style_button(b, data.color.lightened(0.2), id == _material)
		var mid: StringName = id
		b.pressed.connect(func(): _material = mid; _reset_price(); refresh())
		_goods.add_child(b)

func _fill_form() -> void:
	for box in [_form_head, _form_foot]:
		for c in box.get_children():
			c.queue_free()
	var data := MaterialData.of(_material)
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 6)
	for selling in [false, true]:
		var b := Button.new()
		b.text = "📦 Encomendar (comprar)" if not selling else "💰 Vender"
		_style_button(b, SELL if selling else BUY, selling == _selling)
		b.pressed.connect(func(): _selling = selling; _reset_price(); refresh())
		mode_row.add_child(b)
	_form_head.add_child(mode_row)
	_form_head.add_child(_label("%s  %s" % [data.icon, data.display_name], 18, TEXT))
	var have := player.inventory.get_material_count(_material) if player and player.inventory else 0
	var info := _label("Valor-base %s · você tem %d. %s" % [WalletComponent.format(roundi(data.base_value)), have,
		"A caravana traz se o seu preço cobrir o que ela pede (base × 0,9 a 1,5)." if not _selling else "A caravana compra se o seu preço couber no que ela paga (base × 0,7 a 1,3).", ], 12, TEXT_DIM, true)
	_form_head.add_child(info)
	var place := Button.new()
	place.text = "Fazer encomenda" if not _selling else "Pôr à venda"
	_style_button(place, SELL if _selling else BUY, true)
	place.pressed.connect(_place)
	_form_foot.add_child(place)
	_update_summary()

func _reset_price() -> void:
	if _price == null:
		return
	var base := maxf(1.0, MaterialData.of(_material).base_value)
	_price.value = ceili(base * (1.3 if not _selling else 1.0))

func _update_summary() -> void:
	var qty := int(_qty.value)
	var price := int(_price.value)
	var fee := VillageMarket.fee(qty, price)
	if _selling:
		_summary.text = "Taxa de listagem agora: %s · se vender tudo, recebe %s (−4%%)" % [WalletComponent.format(fee), WalletComponent.format(VillageMarket.after_tax(qty * price))]
	else:
		_summary.text = "Trava %s + taxa %s = %s" % [WalletComponent.format(qty * price), WalletComponent.format(fee), WalletComponent.format(qty * price + fee)]

func _place() -> void:
	var m := _market()
	var err: String
	if _selling:
		err = m.place_sell(player.inventory, player.wallet, _material, int(_qty.value), int(_price.value))
	else:
		err = m.place_buy(player.wallet, _material, int(_qty.value), int(_price.value))
	_message.text = err if err != "" else "✔ Ordem aberta. A caravana passa às 8h e às 17h."
	_message.add_theme_color_override("font_color", RED if err != "" else SELL)
	refresh()

# ---------------------------------------------------------------- lado direito: ordens e retirada

func _fill_orders() -> void:
	for c in _orders.get_children():
		c.queue_free()
	var m := _market()
	_orders.add_child(_label("Suas ordens (%d/%d)" % [m.orders.size(), VillageMarket.MAX_ORDERS], 16, TEXT))
	if m.orders.is_empty():
		_orders.add_child(_label("Nenhuma ordem aberta.", 13, TEXT_DIM))
	for i in m.orders.size():
		var o: Dictionary = m.orders[i]
		var data := MaterialData.of(o.id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := _label(data.icon, 22, TEXT)
		row.add_child(icon)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var buying: bool = o.kind == "buy"
		col.add_child(_label("%s %s" % ["Encomenda:" if buying else "Venda:", data.display_name], 14, BUY if buying else SELL))
		col.add_child(_label("%d de %d · %s cada" % [o.filled, o.qty, WalletComponent.format(o.price)], 12, TEXT_DIM))
		row.add_child(col)
		var cancel := Button.new()
		cancel.text = "Cancelar"
		_style_button(cancel, RED, false)
		var index: int = i
		cancel.pressed.connect(func(): m.cancel(index); refresh())
		row.add_child(cancel)
		_orders.add_child(row)
	_orders.add_child(HSeparator.new())
	_orders.add_child(_label("A receber", 16, TEXT))
	var parts: Array[String] = []
	if m.pending_money > 0:
		parts.append(WalletComponent.format(m.pending_money))
	for e in m.pending_items:
		parts.append("%d %s %s" % [e.n, MaterialData.of(e.id).icon, "★".repeat(e.q)])
	_orders.add_child(_label(", ".join(parts) if not parts.is_empty() else "Nada por enquanto.", 13, GOLD if not parts.is_empty() else TEXT_DIM, true))
	var take := Button.new()
	take.text = "Retirar tudo"
	take.disabled = not m.has_pending()
	_style_button(take, GOLD, true)
	take.pressed.connect(func():
		if m.collect(player.inventory, player.wallet) > 0:
			player.posture_changed.emit("🏪 Retirou o que estava no Mercado")
		refresh())
	_orders.add_child(take)
	_orders.add_child(_label("🐪 A caravana passa às 8h e às 17h. Taxas: listagem 2% (não volta se cancelar) e 4% sobre cada venda.", 12, TEXT_DIM, true))

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
	panel.custom_minimum_size = Vector2(1000, 600)
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
	var title := _label("🏪  Mercado da Vila", 24, TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_money_label = _label("", 15, Color(0.75, 0.95, 0.6))
	header.add_child(_money_label)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(14, 0)
	header.add_child(gap)
	var close_btn := Button.new()
	close_btn.text = "  ✕  "
	_style_button(close_btn, RED, false)
	close_btn.pressed.connect(close)
	header.add_child(close_btn)
	root_box.add_child(header)
	root_box.add_child(_label("Sem leilão global: cada cidade tem seu mercado. Trave o dinheiro numa encomenda ou deixe seus itens à venda; a caravana atende quando passa.", 13, TEXT_DIM, true))

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	root_box.add_child(body)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	body.add_child(left)
	_goods = GridContainer.new()
	_goods.columns = 7
	_goods.add_theme_constant_override("h_separation", 6)
	_goods.add_theme_constant_override("v_separation", 6)
	left.add_child(_goods)
	_form = VBoxContainer.new()
	_form.add_theme_constant_override("separation", 8)
	left.add_child(_form)
	_form_head = VBoxContainer.new()
	_form_head.add_theme_constant_override("separation", 8)
	_form.add_child(_form_head)
	_qty = _spin(1, VillageMarket.MAX_QTY, 5, "Quantidade")
	_price = _spin(1, 999, 3, "Preço por unidade ($S)")
	_summary = _label("", 13, GOLD, true)
	_form.add_child(_summary)
	_form_foot = VBoxContainer.new()
	_form.add_child(_form_foot)
	_message = _label("", 13, RED, true)
	_form.add_child(_message)

	var right_frame := PanelContainer.new()
	right_frame.custom_minimum_size = Vector2(380, 0)
	right_frame.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.07), 10, 1, Vector2(14, 12)))
	body.add_child(right_frame)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_frame.add_child(scroll)
	_orders = VBoxContainer.new()
	_orders.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_orders.add_theme_constant_override("separation", 8)
	scroll.add_child(_orders)

func _spin(lo: int, hi: int, value: int, caption: String) -> SpinBox:
	var row := HBoxContainer.new()
	var l := _label(caption, 14, TEXT)
	l.custom_minimum_size = Vector2(190, 0)
	row.add_child(l)
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.value = value
	s.rounded = true
	s.custom_minimum_size = Vector2(120, 0)
	s.value_changed.connect(func(_v): _update_summary())
	row.add_child(s)
	_form.add_child(row)
	return s

func _label(text: String, size: int, color: Color, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 200.0
	return l

func _style_button(btn: Button, accent: Color, filled: bool) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 14)
	var fg := Color(0.12, 0.09, 0.05) if filled else TEXT
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		btn.add_theme_color_override(c, fg)
	btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.43, 0.4))
	var bg := accent if filled else Color(accent.r, accent.g, accent.b, 0.12)
	btn.add_theme_stylebox_override("normal", _box(bg, accent, 10, 1, Vector2(12, 6)))
	btn.add_theme_stylebox_override("hover", _box(bg.lightened(0.12), accent, 10, 1, Vector2(12, 6)))
	btn.add_theme_stylebox_override("pressed", _box(bg.darkened(0.1), accent, 10, 1, Vector2(12, 6)))
	btn.add_theme_stylebox_override("disabled", _box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.08), 10, 1, Vector2(12, 6)))

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
