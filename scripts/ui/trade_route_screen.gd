class_name TradeRouteScreen
extends Control

## Interface de Rotas Comerciais e Entreposto de Carga (GDD-05 §2, §5; GDD-11).
## Permite ao jogador consultar cotações regionais, adquirir fardos comerciais locais,
## liquidar cargas transportadas e alistar-se em escoltas armadas de caravanas.

const _TradePackData = preload("res://scripts/data/trade_pack_data.gd")
const _TradeRouteManager = preload("res://scripts/systems/trade_route_manager.gd")
const _WorldSettlements = preload("res://scripts/world/world_settlements.gd")
const _WalletComponent = preload("res://scripts/components/wallet_component.gd")

var manager: _TradeRouteManager
var player: Node
var current_settlement_id: StringName = &"vila_esperanca"

const TEXT := Color(0.92, 0.92, 0.95)
const TEXT_DIM := Color(0.62, 0.64, 0.70)
const GOLD := Color(0.95, 0.78, 0.35)
const GREEN := Color(0.35, 0.85, 0.45)
const PANEL_BG := Color(0.08, 0.08, 0.10, 0.95)

var _title_lbl: Label
var _current_pack_panel: VBoxContainer
var _buy_container: VBoxContainer
var _quotes_table: VBoxContainer
var _player_balance_lbl: Label

func _ready() -> void:
	visible = false
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_build_ui()

func open(p_manager: _TradeRouteManager, p_player: Node, p_settlement_id: StringName = &"vila_esperanca") -> void:
	manager = p_manager
	player = p_player
	current_settlement_id = p_settlement_id
	visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh()

func close() -> void:
	remove_from_group("open_menus")
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_E)):
		close()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)
	
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(650, 520)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = Color(0.28, 0.32, 0.40)
	sb.border_width_bottom = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)
	
	# Cabeçalho
	var header := HBoxContainer.new()
	var title_vbox := VBoxContainer.new()
	_title_lbl = Label.new()
	_title_lbl.text = "📦 Entreposto de Rotas Comerciais & Logística"
	_title_lbl.add_theme_font_size_override("font_size", 18)
	_title_lbl.add_theme_color_override("font_color", GOLD)
	title_vbox.add_child(_title_lbl)
	
	_player_balance_lbl = Label.new()
	_player_balance_lbl.text = "Seu Saldo: 50 $S"
	_player_balance_lbl.add_theme_font_size_override("font_size", 12)
	_player_balance_lbl.add_theme_color_override("font_color", TEXT_DIM)
	title_vbox.add_child(_player_balance_lbl)
	header.add_child(title_vbox)
	
	header.add_spacer(false)
	var btn_close := Button.new()
	btn_close.text = "✕ Fechar [ESC]"
	btn_close.focus_mode = FOCUS_NONE
	btn_close.pressed.connect(close)
	header.add_child(btn_close)
	vbox.add_child(header)
	
	vbox.add_child(HSeparator.new())
	
	# Painel do Fardo Atual (Carga Carregada)
	_current_pack_panel = VBoxContainer.new()
	vbox.add_child(_current_pack_panel)
	
	vbox.add_child(HSeparator.new())
	
	# Comprar Fardos Locais
	var buy_header := Label.new()
	buy_header.text = "🛒 Fardos Produzidos Localmente (Para Transporte):"
	buy_header.add_theme_font_size_override("font_size", 14)
	buy_header.add_theme_color_override("font_color", TEXT)
	vbox.add_child(buy_header)
	
	_buy_container = VBoxContainer.new()
	vbox.add_child(_buy_container)
	
	vbox.add_child(HSeparator.new())
	
	# Tabela de Cotações Regionais
	var quotes_header := Label.new()
	quotes_header.text = "📊 Cotações de Mercado & Lucro Estimado por Rota:"
	quotes_header.add_theme_font_size_override("font_size", 14)
	quotes_header.add_theme_color_override("font_color", TEXT)
	vbox.add_child(quotes_header)
	
	_quotes_table = VBoxContainer.new()
	vbox.add_child(_quotes_table)

func _refresh() -> void:
	if manager == null:
		return
	
	var balance := 0
	var wallet := _get_player_wallet()
	if wallet:
		balance = wallet.money
	_player_balance_lbl.text = "Seu Saldo: %d $S • Entreposto Atual: %s" % [balance, String(current_settlement_id).capitalize()]
	
	# 1. Carga atual
	for c in _current_pack_panel.get_children():
		c.queue_free()
	
	if player and player.has_meta("carrying_trade_pack") and player.get_meta("carrying_trade_pack") != null:
		var pack: _TradePackData = player.get_meta("carrying_trade_pack")
		var dest_pos := manager._get_settlement_pos(current_settlement_id)
		var demand_mult := manager.get_demand_multiplier(current_settlement_id, pack.id)
		var sale_val := pack.calculate_sale_value(current_settlement_id, dest_pos, demand_mult)
		var profit := sale_val - pack.base_buy_price
		
		var row := HBoxContainer.new()
		var info := Label.new()
		info.text = "🎒 Carga nas Costas: %s\nOrigem: %s • Valor de Venda: %d $S (%+d $S)" % [
			pack.pack_name, String(pack.origin_settlement_id).capitalize(), sale_val, profit
		]
		info.add_theme_color_override("font_color", GREEN if profit > 0 else GOLD)
		row.add_child(info)
		
		row.add_spacer(false)
		var btn_sell := Button.new()
		btn_sell.text = "💰 Entregar Carga" if profit > 0 else "↩️ Devolver Fardo"
		btn_sell.pressed.connect(func(): _sell_pack())
		row.add_child(btn_sell)
		
		var btn_drop := Button.new()
		btn_drop.text = "⬇️ Soltar no Chão"
		btn_drop.pressed.connect(func(): _drop_pack())
		row.add_child(btn_drop)
		_current_pack_panel.add_child(row)
	else:
		var empty_lbl := Label.new()
		empty_lbl.text = "🎒 Nenhuma carga transportada no momento (Viagem Rápida liberada)."
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", TEXT_DIM)
		_current_pack_panel.add_child(empty_lbl)
	
	# 2. Fardos disponíveis para compra local
	for c in _buy_container.get_children():
		c.queue_free()
	
	var packs := manager.get_available_packs_at(current_settlement_id)
	if packs.is_empty():
		var no_pack_lbl := Label.new()
		no_pack_lbl.text = "Nenhum fardo produzido neste posto."
		no_pack_lbl.add_theme_color_override("font_color", TEXT_DIM)
		_buy_container.add_child(no_pack_lbl)
	else:
		for p_info in packs:
			var row := HBoxContainer.new()
			var p_lbl := Label.new()
			p_lbl.text = "• %s — Preço: %d $S" % [p_info["name"], p_info["price"]]
			p_lbl.add_theme_color_override("font_color", TEXT)
			row.add_child(p_lbl)
			
			row.add_spacer(false)
			var btn_buy := Button.new()
			btn_buy.text = "Comprar Fardo (%d $S)" % p_info["price"]
			btn_buy.disabled = (balance < p_info["price"] or (player and player.has_meta("carrying_trade_pack") and player.get_meta("carrying_trade_pack") != null))
			btn_buy.pressed.connect(func(): _buy_pack(p_info["id"]))
			row.add_child(btn_buy)
			_buy_container.add_child(row)
	
	# 3. Tabela de cotações
	for c in _quotes_table.get_children():
		c.queue_free()
	
	for dest in _WorldSettlements.SETTLEMENTS:
		var d_id: StringName = dest["id"]
		if d_id == current_settlement_id:
			continue
		for p_info in packs:
			var quote := manager.get_market_quote(p_info["id"], current_settlement_id, d_id)
			var row := HBoxContainer.new()
			var q_lbl := Label.new()
			q_lbl.text = "➔ Para %s (%.0fm): Venda ~%d $S • Lucro: %+d $S (Demanda: %.0f%%)" % [
				dest["name"], quote["distance"], quote["sale_price"], quote["profit"], quote["demand"] * 100.0
			]
			q_lbl.add_theme_font_size_override("font_size", 12)
			q_lbl.add_theme_color_override("font_color", GREEN if quote["profit"] > 0 else TEXT_DIM)
			row.add_child(q_lbl)
			_quotes_table.add_child(row)

func _buy_pack(pack_id: StringName) -> void:
	if manager and player:
		var pack := manager.buy_trade_pack(player, pack_id, current_settlement_id)
		if pack:
			_refresh()

func _sell_pack() -> void:
	if manager and player:
		var res := manager.sell_trade_pack(player, current_settlement_id)
		if res.get("success", false):
			_refresh()

func _drop_pack() -> void:
	if manager and player:
		manager.drop_trade_pack(player)
		_refresh()

func _get_player_wallet() -> _WalletComponent:
	if player == null:
		return null
	if player.has_meta("wallet") and player.get_meta("wallet") is _WalletComponent:
		return player.get_meta("wallet") as _WalletComponent
	if player.get("wallet") is _WalletComponent:
		return player.get("wallet") as _WalletComponent
	var comp = player.get_node_or_null("WalletComponent") as _WalletComponent
	if comp:
		return comp
	for c in player.get_children():
		if c is _WalletComponent:
			return c as _WalletComponent
	return null
