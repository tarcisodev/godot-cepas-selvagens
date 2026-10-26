class_name BlackMarketScreen
extends Control

## Interface Gráfica do Mercado Negro Clandestino (GDD-05 §3).
## Permite ao jogador cumprir ordens de compra sistêmicas (moeda $S garantida) e
## vender equipamentos forjados que entram no cofre de Loot Orgânico para abastecer baús dos ermos.

const _BlackMarketSystem = preload("res://scripts/systems/black_market_system.gd")
const _ForgedItem = preload("res://scripts/data/forged_item.gd")
const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const _WalletComponent = preload("res://scripts/components/wallet_component.gd")
const _MaterialData = preload("res://scripts/data/material_data.gd")

var player: Node
var market_system: _BlackMarketSystem

var _active_tab: int = 0 # 0 = Ordens Sistêmicas, 1 = Venda de Equipamentos
var _content_box: VBoxContainer
var _wallet_label: Label
var _organic_status_label: Label
var _feedback_label: Label
var _btn_tab_orders: Button
var _btn_tab_gear: Button

func _ready() -> void:
	visible = false
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_build_ui()

func open(p_player: Node, p_system: _BlackMarketSystem = null) -> void:
	player = p_player
	market_system = p_system if p_system else _BlackMarketSystem.get_instance(get_tree())
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

func _build_ui() -> void:
	# Fundo escurecido
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.04, 0.03, 0.06, 0.75)
	backdrop.set_anchors_preset(PRESET_FULL_RECT)
	backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close()
	)
	add_child(backdrop)

	# Painel central
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 520)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.11, 0.96)
	sb.border_color = Color(0.55, 0.35, 0.75, 0.8)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 14)
	panel.add_child(main_vbox)

	# Cabeçalho
	var header := HBoxContainer.new()
	main_vbox.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title_box)

	var title := Label.new()
	title.text = "🕶️ MERCADO NEGRO CLANDESTINO"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.85, 0.65, 1.0))
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Ordens Sistêmicas dos Ermos & Circulação de Itens Criados por Jogadores"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.62, 0.72))
	title_box.add_child(subtitle)

	_wallet_label = Label.new()
	_wallet_label.text = "Saldo: 0 $S"
	_wallet_label.add_theme_font_size_override("font_size", 16)
	_wallet_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	header.add_child(_wallet_label)

	var close_btn := Button.new()
	close_btn.text = " ✕ "
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	# Abas
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	main_vbox.add_child(tabs)

	_btn_tab_orders = Button.new()
	_btn_tab_orders.text = "📜 Ordens Sistêmicas de Compra"
	_btn_tab_orders.pressed.connect(func(): _switch_tab(0))
	tabs.add_child(_btn_tab_orders)

	_btn_tab_gear = Button.new()
	_btn_tab_gear.text = "🗡️ Vender Equipamento Forjado"
	_btn_tab_gear.pressed.connect(func(): _switch_tab(1))
	tabs.add_child(_btn_tab_gear)

	# Área rolável de conteúdo
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(710, 310)
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	_content_box = VBoxContainer.new()
	_content_box.size_flags_horizontal = SIZE_EXPAND_FILL
	_content_box.add_theme_constant_override("separation", 10)
	scroll.add_child(_content_box)

	# Rodapé
	var footer := HBoxContainer.new()
	main_vbox.add_child(footer)

	_organic_status_label = Label.new()
	_organic_status_label.text = "Fluxo dos Ermos: 0 peças em circulação"
	_organic_status_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_organic_status_label.add_theme_font_size_override("font_size", 12)
	_organic_status_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.85))
	footer.add_child(_organic_status_label)

	_feedback_label = Label.new()
	_feedback_label.text = ""
	_feedback_label.add_theme_font_size_override("font_size", 12)
	_feedback_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	footer.add_child(_feedback_label)

func _switch_tab(idx: int) -> void:
	_active_tab = idx
	_refresh()

func _refresh() -> void:
	if not visible:
		return

	# Atualiza carteira
	var wallet: _WalletComponent = _get_wallet(player)
	if wallet and _wallet_label:
		_wallet_label.text = "Saldo: %d $S" % wallet.money

	# Atualiza status de circulação orgânica
	if market_system and _organic_status_label:
		var pool_size: int = market_system.organic_loot_pool.size()
		var shredded: int = market_system.total_items_shredded
		_organic_status_label.text = "📦 Fluxo Orgânico: %d peças nos Baús do Ermo | Trituradas: %d" % [pool_size, shredded]

	# Atualiza botões de aba
	_btn_tab_orders.modulate = Color(1.2, 1.2, 1.2) if _active_tab == 0 else Color(0.7, 0.7, 0.7)
	_btn_tab_gear.modulate = Color(1.2, 1.2, 1.2) if _active_tab == 1 else Color(0.7, 0.7, 0.7)

	for child in _content_box.get_children():
		child.queue_free()

	if _active_tab == 0:
		_build_orders_tab()
	else:
		_build_gear_tab()

func _build_orders_tab() -> void:
	if market_system == null or market_system.systemic_orders.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Nenhuma ordem de compra ativa no momento."
		_content_box.add_child(empty_lbl)
		return

	for order in market_system.systemic_orders:
		var row := PanelContainer.new()
		var row_sb := StyleBoxFlat.new()
		row_sb.bg_color = Color(0.12, 0.11, 0.16, 0.8)
		row_sb.corner_radius_top_left = 6
		row_sb.corner_radius_top_right = 6
		row_sb.corner_radius_bottom_left = 6
		row_sb.corner_radius_bottom_right = 6
		row_sb.content_margin_left = 12
		row_sb.content_margin_right = 12
		row_sb.content_margin_top = 8
		row_sb.content_margin_bottom = 8
		row.add_theme_stylebox_override("panel", row_sb)
		_content_box.add_child(row)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 14)
		row.add_child(hbox)

		var icon := Label.new()
		icon.text = order.get("icon", "📦")
		icon.add_theme_font_size_override("font_size", 24)
		hbox.add_child(icon)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = SIZE_EXPAND_FILL
		hbox.add_child(info)

		var t := Label.new()
		t.text = str(order.get("title", "Ordem Clandestina"))
		t.add_theme_font_size_override("font_size", 14)
		t.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
		info.add_child(t)

		var d := Label.new()
		d.text = str(order.get("description", ""))
		d.add_theme_font_size_override("font_size", 11)
		d.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		info.add_child(d)

		var pay_lbl := Label.new()
		pay_lbl.text = "+%d $S" % int(order.get("reward_money", 0))
		pay_lbl.add_theme_font_size_override("font_size", 16)
		pay_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		hbox.add_child(pay_lbl)

		var can_deliver: bool = market_system.can_fulfill_order(order.id, player)
		var deliver_btn := Button.new()
		deliver_btn.text = " Entregar "
		deliver_btn.disabled = not can_deliver
		var ord_id: String = order.id
		deliver_btn.pressed.connect(func(): _deliver_order(ord_id))
		hbox.add_child(deliver_btn)

func _build_gear_tab() -> void:
	var inv: _InventoryComponent = _get_inventory(player)
	if inv == null or inv.items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Você não possui peças de equipamento forjadas na mochila para vender."
		empty_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		_content_box.add_child(empty_lbl)
		return

	for item in inv.items:
		var row := PanelContainer.new()
		var row_sb := StyleBoxFlat.new()
		row_sb.bg_color = Color(0.12, 0.11, 0.16, 0.8)
		row_sb.corner_radius_top_left = 6
		row_sb.corner_radius_top_right = 6
		row_sb.corner_radius_bottom_left = 6
		row_sb.corner_radius_bottom_right = 6
		row_sb.content_margin_left = 12
		row_sb.content_margin_right = 12
		row_sb.content_margin_top = 8
		row_sb.content_margin_bottom = 8
		row.add_theme_stylebox_override("panel", row_sb)
		_content_box.add_child(row)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 14)
		row.add_child(hbox)

		var icon := Label.new()
		icon.text = "🗡️" if item.is_weapon() else "🛡️"
		icon.add_theme_font_size_override("font_size", 22)
		hbox.add_child(icon)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = SIZE_EXPAND_FILL
		hbox.add_child(info)

		var t := Label.new()
		var stars: String = "★".repeat(clampi(item.quality, 1, 5))
		t.text = "%s (%s)" % [item.display_name, stars]
		t.add_theme_font_size_override("font_size", 14)
		t.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0))
		info.add_child(t)

		var details := Label.new()
		var traits_str: String = ", ".join(item.trait_names()) if not item.traits.is_empty() else "Nenhum"
		details.text = "Família: %s · Traits: %s · Durabilidade: %d%%" % [item.family_name(), traits_str, int(item.durability)]
		details.add_theme_font_size_override("font_size", 11)
		details.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
		info.add_child(details)

		var payout: int = market_system.calculate_gear_payout(item)
		var pay_lbl := Label.new()
		pay_lbl.text = "+%d $S" % payout
		pay_lbl.add_theme_font_size_override("font_size", 16)
		pay_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		hbox.add_child(pay_lbl)

		var sell_btn := Button.new()
		sell_btn.text = " Vender para o Ermo "
		var item_ref: _ForgedItem = item
		sell_btn.pressed.connect(func(): _sell_gear_piece(item_ref))
		hbox.add_child(sell_btn)

func _deliver_order(order_id: String) -> void:
	if market_system == null:
		return
	var res := market_system.fulfill_order(order_id, player)
	if res.success:
		_show_feedback("Ordem cumprida! +%d $S" % int(res.payout), Color(0.4, 0.9, 0.5))
	else:
		_show_feedback(res.message, Color(0.9, 0.4, 0.4))
	_refresh()

func _sell_gear_piece(item: _ForgedItem) -> void:
	if market_system == null:
		return
	var res := market_system.sell_gear(player, item)
	if res.success:
		_show_feedback("Peça vendida! +%d $S adicionados à carteira." % int(res.payout), Color(0.4, 0.9, 0.5))
	else:
		_show_feedback(res.message, Color(0.9, 0.4, 0.4))
	_refresh()

func _show_feedback(msg: String, col: Color) -> void:
	if _feedback_label:
		_feedback_label.text = msg
		_feedback_label.add_theme_color_override("font_color", col)

func _get_inventory(node: Node) -> _InventoryComponent:
	if node == null:
		return null
	if "inventory" in node and node.inventory is _InventoryComponent:
		return node.inventory as _InventoryComponent
	if node.has_node("InventoryComponent"):
		return node.get_node("InventoryComponent") as _InventoryComponent
	for child in node.get_children():
		if child is _InventoryComponent:
			return child as _InventoryComponent
	return null

func _get_wallet(node: Node) -> _WalletComponent:
	if node == null:
		return null
	if "wallet" in node and node.wallet is _WalletComponent:
		return node.wallet as _WalletComponent
	if node.has_node("WalletComponent"):
		return node.get_node("WalletComponent") as _WalletComponent
	for child in node.get_children():
		if child is _WalletComponent:
			return child as _WalletComponent
	return null
