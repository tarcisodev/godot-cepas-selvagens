class_name CostelariaEconomy
extends RefCounted

## Comércio da Costelária (B38, GDD-17 §4). Tudo vira ao amanhecer pelo relógio único
## (ADR-0006): estoque das lojas, bolsa do dia dos compradores, vendas da cidade e as
## encomendas. No online é estado do servidor (ADR-0002), igual para todos.
##
## - Loja: estoque por item, preço fixo com desconto da Reputação da Costelária.
## - Comprador: paga valor-base × 0,6 na 1ª unidade e 3% a menos a cada unidade daquele
##   material vendida no dia por qualquer jogador; para quando a bolsa do dia acaba.
## - Encomendas: 2 por dia no Comprador de Partes, com ★ mínima e prêmio acima da tabela.
## - Feira do Ventre: oferta rara sorteada pelo dia; compra qualquer coisa pela metade.

const _MaterialData = preload("res://scripts/data/material_data.gd")
const _Cast = preload("res://scripts/costelaria/costelaria_cast.gd")

const PURSE_PER_DAY: int = 300
const NIGHT_PURSE_PER_DAY: int = 200
const BUY_RATIO: float = 0.6
const NIGHT_BUY_RATIO: float = 0.5
const DECAY_PER_UNIT: float = 0.03
const STOCK_PER_ITEM: int = 6
const ORDERS_PER_DAY: int = 2
const ORDER_BONUS: float = 2.2
const ORDER_REPUTATION: int = 5
const NIGHT_MARKUP: float = 1.6
const NIGHT_OFFER_SIZE: int = 3
const NIGHT_POOL: Array[StringName] = [&"mega_pocao", &"quartzo_lume", &"chifre_rinolito", &"oleo_peixe", &"placa_carapaca", &"banquete_viagem", &"pena_penacho"]
const ORDER_NPC: StringName = &"seu_graxa"
const NIGHT_NPC: StringName = &"mascate_sombra"

## Dia de jogo do último amanhecer processado
var day: int = -1
## npc → {item: unidades}
var stock: Dictionary = {}
## npc → $S que ainda pode pagar hoje
var purse: Dictionary = {}
## material → unidades vendidas hoje para compradores (a cidade inteira)
var sold_today: Dictionary = {}
## [{"material", "amount", "min_q", "reward", "done"}]
var orders: Array[Dictionary] = []
## item → preço da Feira do Ventre hoje
var night_offer: Dictionary = {}
## Reputação da Costelária (encomendas e Compêndio); desconto −1% a cada 25, até −10%
var reputation: int = 0

## Vira o dia se `p_day` passou do último amanhecer
func ensure_day(p_day: int) -> void:
	if p_day == day:
		return
	day = p_day
	sold_today.clear()
	stock.clear()
	purse.clear()
	for c in _Cast.CAST:
		var sells: Dictionary = c.get("sells", {})
		if not sells.is_empty():
			var s := {}
			for item in sells:
				s[item] = STOCK_PER_ITEM
			stock[c["id"]] = s
		if not c.get("buys", []).is_empty():
			purse[c["id"]] = PURSE_PER_DAY
	purse[NIGHT_NPC] = NIGHT_PURSE_PER_DAY
	_roll_night_offer()
	_roll_orders()

func discount() -> float:
	return minf(0.10, floorf(reputation / 25.0) * 0.01)

# ---------------------------------------------------------------- lojas

## {item: preço} que o NPC vende hoje (o Mascate muda todo dia)
func catalog(npc_id: StringName) -> Dictionary:
	if npc_id == NIGHT_NPC:
		return night_offer
	return _Cast.by_id(npc_id).get("sells", {})

func price(npc_id: StringName, item: StringName) -> int:
	var base: int = catalog(npc_id).get(item, 0)
	return maxi(1, roundi(base * (1.0 - discount())))

func stock_of(npc_id: StringName, item: StringName) -> int:
	return int(stock.get(npc_id, {}).get(item, 0))

## Compra 1 unidade; devolve "" se deu certo, senão o motivo
func buy(npc_id: StringName, item: StringName, player: Node) -> String:
	if not catalog(npc_id).has(item):
		return "Não vendo isso."
	if stock_of(npc_id, item) <= 0:
		return "Acabou por hoje. Amanhã chega mais."
	var wallet: WalletComponent = player.get("wallet") if player else null
	var inv: InventoryComponent = player.get("inventory") if player else null
	if wallet == null or inv == null:
		return "Sem bolsa."
	if not wallet.spend(price(npc_id, item)):
		return "Faltou dinheiro."
	stock[npc_id][item] -= 1
	inv.add_material(item, 1)
	return ""

# ---------------------------------------------------------------- compradores

func buys(npc_id: StringName) -> Array:
	return _Cast.by_id(npc_id).get("buys", [])

## Quanto o NPC paga agora por 1 unidade (0 = não compra)
func offer(npc_id: StringName, material: StringName) -> int:
	var base := _MaterialData.of(material).base_value
	if npc_id == NIGHT_NPC:
		return maxi(1, roundi(base * NIGHT_BUY_RATIO))
	if not buys(npc_id).has(material):
		return 0
	var n: int = sold_today.get(material, 0)
	return maxi(1, roundi(base * BUY_RATIO * pow(1.0 - DECAY_PER_UNIT, n)))

func purse_of(npc_id: StringName) -> int:
	return int(purse.get(npc_id, 0))

## Vende 1 unidade (a pior ★ primeiro); "" se deu certo, senão o motivo
func sell(npc_id: StringName, material: StringName, player: Node) -> String:
	var pay := offer(npc_id, material)
	if pay <= 0:
		return "Isso eu não compro."
	if purse_of(npc_id) < pay:
		return "Minha bolsa de hoje acabou. Volte amanhã."
	var wallet: WalletComponent = player.get("wallet") if player else null
	var inv: InventoryComponent = player.get("inventory") if player else null
	if wallet == null or inv == null:
		return "Sem bolsa."
	var stacks := inv.get_stacks(material)
	if stacks.is_empty() or not inv.consume_stack(stacks[0], 1):
		return "Você não tem isso."
	purse[npc_id] = purse_of(npc_id) - pay
	if npc_id != NIGHT_NPC:
		sold_today[material] = int(sold_today.get(material, 0)) + 1
	wallet.add(pay)
	return ""

# ---------------------------------------------------------------- encomendas

## Entrega a encomenda `index` com pilhas de ★ ≥ mínima; "" se deu certo
func deliver(index: int, player: Node) -> String:
	if index < 0 or index >= orders.size():
		return "Essa encomenda não existe."
	var o: Dictionary = orders[index]
	if o["done"]:
		return "Alguém já entregou essa."
	var inv: InventoryComponent = player.get("inventory") if player else null
	var wallet: WalletComponent = player.get("wallet") if player else null
	if inv == null or wallet == null:
		return "Sem bolsa."
	var good: Array[Dictionary] = []
	var have := 0
	for s in inv.get_stacks(o["material"]):
		if int(s.quality) >= int(o["min_q"]):
			good.append(s)
			have += int(s.amount)
	if have < int(o["amount"]):
		return "Preciso de %d com %d★ ou mais." % [o["amount"], o["min_q"]]
	var left: int = o["amount"]
	for s in good:
		var take := mini(left, int(s.amount))
		inv.consume_stack(s, take)
		left -= take
		if left <= 0:
			break
	o["done"] = true
	wallet.add(int(o["reward"]))
	reputation += ORDER_REPUTATION
	return ""

func _roll_orders() -> void:
	orders.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("costelaria_encomendas_%d" % day)
	var pool: Array = buys(ORDER_NPC).duplicate()
	for i in ORDERS_PER_DAY:
		if pool.is_empty():
			break
		var material: StringName = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		var amount := rng.randi_range(1, 3)
		orders.append({"material": material, "amount": amount, "min_q": rng.randi_range(2, 3),
			"reward": maxi(5, roundi(_MaterialData.of(material).base_value * amount * ORDER_BONUS)), "done": false})

func _roll_night_offer() -> void:
	night_offer.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("costelaria_ventre_%d" % day)
	var pool := NIGHT_POOL.duplicate()
	var s := {}
	for i in NIGHT_OFFER_SIZE:
		var item: StringName = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		night_offer[item] = maxi(2, roundi(_MaterialData.of(item).base_value * NIGHT_MARKUP))
		s[item] = 2
	stock[NIGHT_NPC] = s

# ---------------------------------------------------------------- save

func get_state() -> Dictionary:
	var o: Array = []
	for e in orders:
		o.append({"material": String(e["material"]), "amount": e["amount"], "min_q": e["min_q"], "reward": e["reward"], "done": e["done"]})
	return {"day": day, "reputation": reputation, "stock": _str_keys(stock), "purse": _str_keys(purse), "sold": _str_keys(sold_today), "orders": o}

func apply_state(data: Dictionary) -> void:
	reputation = int(data.get("reputation", 0))
	var saved_day := int(data.get("day", -1))
	if saved_day < 0:
		return
	day = -1
	ensure_day(saved_day)
	for npc in data.get("stock", {}):
		var items: Dictionary = data["stock"][npc]
		var s := {}
		for item in items:
			s[StringName(item)] = int(items[item])
		stock[StringName(npc)] = s
	for npc in data.get("purse", {}):
		purse[StringName(npc)] = int(data["purse"][npc])
	for m in data.get("sold", {}):
		sold_today[StringName(m)] = int(data["sold"][m])
	for i in mini(orders.size(), data.get("orders", []).size()):
		orders[i]["done"] = bool(data["orders"][i].get("done", false))

static func _str_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		var v = d[k]
		out[String(k)] = _str_keys(v) if v is Dictionary else v
	return out
