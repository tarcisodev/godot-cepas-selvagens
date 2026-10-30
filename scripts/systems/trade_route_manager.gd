class_name TradeRouteManager
extends Node

## Gerenciador Central de Rotas Comerciais e Logística de Fardos (GDD-05 §2, §5; GDD-11; GDD-08 §6).
## Controla oferta e demanda regional, cotação por distância, compra/venda de fardos,
## bloqueio de Viagem Rápida e geração de emboscadas ao cruzar áreas perigosas.

const _TradePackData = preload("res://scripts/data/trade_pack_data.gd")
const _WorldTradePack = preload("res://scripts/props/world_trade_pack.gd")
const _WalletComponent = preload("res://scripts/components/wallet_component.gd")
const _WorldSettlements = preload("res://scripts/world/world_settlements.gd")

signal pack_purchased(pack: _TradePackData, player: Node)
signal pack_sold(pack: _TradePackData, player: Node, profit: int)
signal pack_dropped(pack: _TradePackData, pos: Vector3)

## Cotações base de apetite regional e cotações dinâmicas atuais
var base_demand_rates: Dictionary = {}
var demand_rates: Dictionary = {}

func _ready() -> void:
	add_to_group("trade_route_manager")
	_init_demand_rates()

func _init_demand_rates() -> void:
	# Cotações base com variação de apetite regional
	for dest in _WorldSettlements.SETTLEMENTS:
		var d_id: StringName = dest["id"]
		for p_id in _TradePackData.DISPLAY_NAMES.keys():
			var key := "%s_%s" % [d_id, p_id]
			# Pescado é muito valorizado na serra; Madeira e minério são valorizados no porto
			var base_rate: float = 1.0
			if d_id == &"vigia_norte" and p_id == &"fardo_pescado":
				base_rate = 1.25
			elif d_id == &"porto_bruma" and p_id == &"fardo_madeira_nobre":
				base_rate = 1.25
			elif d_id == &"santuario_astral" and p_id == &"fardo_manufatura":
				base_rate = 1.20
			elif d_id == &"vila_esperanca" and p_id == &"fardo_astral":
				base_rate = 1.30
			base_demand_rates[key] = base_rate
			demand_rates[key] = base_rate

## Retorna a lista de fardos comerciais disponíveis para compra no assentamento
func get_available_packs_at(settlement_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p_id in _TradePackData.NATIVE_ORIGINS.keys():
		if _TradePackData.NATIVE_ORIGINS[p_id] == settlement_id:
			out.append({
				"id": p_id,
				"name": _TradePackData.DISPLAY_NAMES[p_id],
				"price": _TradePackData.BASE_BUY_PRICES.get(p_id, 25),
				"origin_id": settlement_id
			})
	return out

## Retorna o fardo comercial atualmente carregado pelo jogador (ou null)
static func get_carried_pack(player: Node) -> _TradePackData:
	if player and player.has_meta("carrying_trade_pack"):
		return player.get_meta("carrying_trade_pack") as _TradePackData
	return null

## Compra um fardo no entreposto de origem
func buy_trade_pack(player: Node, pack_id: StringName, settlement_id: StringName, quality: int = 1) -> _TradePackData:
	if player == null:
		return null
	
	# Verifica se já está carregando carga
	if get_carried_pack(player) != null:
		_notify(player, "⚠️ Você já está carregando um Fardo Comercial nas costas!")
		return null
	
	var price: int = _TradePackData.BASE_BUY_PRICES.get(pack_id, 25)
	var wallet := _get_wallet(player)
	if wallet == null or wallet.money < price:
		_notify(player, "❌ Saldo insuficiente em Dólares de Sucata (%d $S necessários)." % price)
		return null
	
	wallet.spend(price)
	
	var origin_pos := _get_settlement_pos(settlement_id)
	var pack := _TradePackData.new(pack_id, settlement_id, origin_pos, quality)
	player.set_meta("carrying_trade_pack", pack)
	
	_notify(player, "📦 %s adquirido! Leve-o a outro assentamento para lucrar." % pack.pack_name)
	pack_purchased.emit(pack, player)
	return pack

## Vende e liquida o fardo comercial no entreposto de destino
func sell_trade_pack(player: Node, destination_id: StringName) -> Dictionary:
	if player == null:
		return { "success": false, "reason": "Jogador nulo" }
	
	var pack := get_carried_pack(player)
	if pack == null:
		_notify(player, "⚠️ Nenhum Fardo Comercial para entregar.")
		return { "success": false, "reason": "Sem fardo" }
	
	var dest_pos := _get_settlement_pos(destination_id)
	var demand_mult := get_demand_multiplier(destination_id, pack.id)
	
	var sale_price := pack.calculate_sale_value(destination_id, dest_pos, demand_mult)
	var profit := sale_price - pack.base_buy_price
	
	# Reputação concedida por abastecer o entreposto (1 a cada 5 $S de lucro)
	var rep_earned := maxi(1, int(float(profit) / 5.0)) if profit > 0 else 0
	
	var wallet := _get_wallet(player)
	if wallet:
		wallet.add(sale_price)
	
	# Atualiza o mercado local (oferta recebida reduz levemente o multiplicador de demanda)
	var key := "%s_%s" % [destination_id, pack.id]
	if demand_rates.has(key):
		demand_rates[key] = maxf(0.70, demand_rates[key] - 0.05)
	
	player.set_meta("carrying_trade_pack", null)
	
	if profit > 0:
		_notify(player, "💰 Fardo entregue com sucesso! +%d $S (Lucro líquido: +%d $S) e +%d Reputação." % [sale_price, profit, rep_earned])
	else:
		_notify(player, "↩️ Fardo devolvido à origem. Reembolsado: %d $S." % sale_price)
	
	if profit > 0:
		EventBusAutoload.report(player, &"caravana", {"money": profit})
	pack_sold.emit(pack, player, profit)
	return {
		"success": true,
		"sale_price": sale_price,
		"profit": profit,
		"reputation": rep_earned
	}

## Derruba o fardo no chão do mundo físico (ao cair em combate ou descarregar voluntariamente)
func drop_trade_pack(player: Node, world_node: Node = null) -> _WorldTradePack:
	if player == null:
		return null
	var pack := get_carried_pack(player)
	if pack == null:
		return null
	
	player.set_meta("carrying_trade_pack", null)
	
	var prop := _WorldTradePack.new()
	prop.set_pack(pack)
	if player is Node3D:
		prop.position = (player as Node3D).global_position
	
	var target_parent: Node = world_node
	if target_parent == null and player.is_inside_tree():
		target_parent = player.get_tree().current_scene
	if target_parent:
		target_parent.add_child(prop)
	
	_notify(player, "📦 Fardo Comercial derrubado no chão!")
	pack_dropped.emit(pack, prop.position)
	return prop

## Valida se o jogador pode usar Viagem Rápida (bloqueada se estiver com fardo pesado)
static func can_player_fast_travel(player: Node) -> bool:
	if player == null:
		return true
	return get_carried_pack(player) == null

## Cotação em tempo real de uma rota comercial específica
func get_market_quote(pack_id: StringName, from_id: StringName, to_id: StringName) -> Dictionary:
	var from_pos := _get_settlement_pos(from_id)
	var to_pos := _get_settlement_pos(to_id)
	var dummy_pack := _TradePackData.new(pack_id, from_id, from_pos, 1)
	
	var demand := get_demand_multiplier(to_id, pack_id)
	var sale_val := dummy_pack.calculate_sale_value(to_id, to_pos, demand)
	var buy_val := dummy_pack.base_buy_price
	var profit := sale_val - buy_val
	var dist := from_pos.distance_to(to_pos)
	
	return {
		"pack_id": pack_id,
		"from_id": from_id,
		"to_id": to_id,
		"distance": dist,
		"buy_price": buy_val,
		"sale_price": sale_val,
		"profit": profit,
		"demand": demand
	}

func get_demand_multiplier(dest_id: StringName, pack_id: StringName) -> float:
	var key := "%s_%s" % [dest_id, pack_id]
	return float(demand_rates.get(key, 1.0))

## Recupera demanda ao longo do tempo em direção à cotação base da região
func advance_time(hours: float) -> void:
	for key in demand_rates.keys():
		var cur: float = demand_rates[key]
		var base_val: float = float(base_demand_rates.get(key, 1.0))
		demand_rates[key] = move_toward(cur, base_val, 0.02 * hours)

func _get_settlement_pos(s_id: StringName) -> Vector3:
	for s in _WorldSettlements.SETTLEMENTS:
		if s["id"] == s_id:
			return s["pos"]
	return Vector3.ZERO

func _get_wallet(player: Node) -> _WalletComponent:
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

func _notify(player: Node, msg: String) -> void:
	if player and player.has_signal("posture_changed"):
		player.posture_changed.emit(msg)
