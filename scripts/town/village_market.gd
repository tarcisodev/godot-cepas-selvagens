class_name VillageMarket
extends RefCounted

## Mercado da Vila (GDD-05 §2 e §6): encomendas (ordens de compra) e ordens de venda.
## No slice a caravana mercante atende as ordens às 8h e às 17h; no online, os jogadores.
## Dinheiro e itens das ordens ficam travados aqui; o que a caravana entrega fica "a receber".

signal changed()

const MAX_ORDERS: int = 6
const MAX_QTY: int = 20
const LISTING_FEE: float = 0.02
const SALE_TAX: float = 0.04
const CARAVAN_HOURS: Array[int] = [8, 17]
## O que a caravana pede (compra do jogador) e paga (venda do jogador), × valor-base
const ASK_RANGE: Vector2 = Vector2(0.9, 1.5)
const BID_RANGE: Vector2 = Vector2(0.7, 1.3)
const SUPPLY_RANGE: Vector2i = Vector2i(2, 8)
const DEMAND_RANGE: Vector2i = Vector2i(1, 6)
## Materiais que circulam no mercado (os de coleta e de caça; consumíveis ficam com a Alquimista)
const GOODS: Array[StringName] = [
	&"madeira", &"galho", &"folha", &"fibra", &"pedra", &"frutinha", &"besouro", &"ossos", &"erva", &"mel",
	&"couro_trotador", &"pele_saltarelo", &"pena_penacho", &"tendao_elastico", &"placa_carapaca", &"chifre_galhado", &"chifre_rinolito",
]

## [{"kind": "buy"|"sell", "id", "qty", "filled", "price", "escrow": [{q, traits, n}] (venda)}]
var orders: Array[Dictionary] = []
## A receber: dinheiro e itens [{id, q, traits, n}]
var pending_money: int = 0
var pending_items: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

func _init(p_seed: int = 0) -> void:
	if p_seed != 0:
		_rng.seed = p_seed
	else:
		_rng.randomize()

static func fee(qty: int, price: int) -> int:
	return maxi(1, ceili(qty * price * LISTING_FEE))

static func after_tax(gross: int) -> int:
	return gross - ceili(gross * SALE_TAX)

## Encomenda: trava qty × preço + taxa de listagem. Devolve "" ou o motivo.
func place_buy(wallet: WalletComponent, id: StringName, qty: int, price: int) -> String:
	var err := _check(id, qty, price)
	if err != "":
		return err
	var total := qty * price + fee(qty, price)
	if wallet == null or not wallet.spend(total):
		return "Falta dinheiro (%s com a taxa)" % WalletComponent.format(total)
	orders.append({"kind": "buy", "id": id, "qty": qty, "filled": 0, "price": price, "escrow": []})
	changed.emit()
	return ""

## Ordem de venda: tira os itens do inventário (pior ★ primeiro) e cobra a taxa de listagem.
func place_sell(inv: InventoryComponent, wallet: WalletComponent, id: StringName, qty: int, price: int) -> String:
	var err := _check(id, qty, price)
	if err != "":
		return err
	if inv == null or inv.get_material_count(id) < qty:
		return "Você não tem %d %s" % [qty, MaterialData.of(id).display_name]
	if wallet == null or not wallet.spend(fee(qty, price)):
		return "Falta dinheiro para a taxa (%s)" % WalletComponent.format(fee(qty, price))
	var escrow: Array[Dictionary] = []
	var left := qty
	for stack in inv.get_stacks(id):
		var n := mini(left, int(stack.amount))
		escrow.append({"q": int(stack.quality), "traits": Array(stack.get("traits", [])).duplicate(), "n": n, "memory": Dictionary(stack.get("memory", {})).duplicate(true)})
		inv.consume_stack(stack, n)
		left -= n
		if left == 0:
			break
	orders.append({"kind": "sell", "id": id, "qty": qty, "filled": 0, "price": price, "escrow": escrow})
	changed.emit()
	return ""

## Cancela: devolve o que sobrou da ordem para o "a receber" (a taxa de listagem não volta)
func cancel(index: int) -> bool:
	if index < 0 or index >= orders.size():
		return false
	var o: Dictionary = orders[index]
	var left: int = o.qty - o.filled
	if o.kind == "buy":
		pending_money += left * int(o.price)
	else:
		for e in o.escrow:
			if e.n > 0:
				pending_items.append({"id": o.id, "q": e.q, "traits": e.traits, "n": e.n, "memory": e.get("memory", {})})
	orders.remove_at(index)
	changed.emit()
	return true

## Retira tudo o que está a receber para a carteira e o inventário. Devolve quantas coisas vieram.
func collect(inv: InventoryComponent, wallet: WalletComponent) -> int:
	var n := 0
	if pending_money > 0 and wallet:
		wallet.add(pending_money)
		pending_money = 0
		n += 1
	if inv:
		for e in pending_items:
			inv.add_material(e.id, e.n, e.q, e.traits, e.get("memory", {}))
			n += 1
		pending_items.clear()
	if n > 0:
		changed.emit()
	return n

func has_pending() -> bool:
	return pending_money > 0 or not pending_items.is_empty()

## Passagem da caravana: atende encomendas que pagam o que ela pede e compra o que cabe no
## que ela paga, em lotes limitados. Devolve as linhas do que aconteceu (para o aviso no HUD).
func caravan_visit() -> Array[String]:
	var report: Array[String] = []
	var demand := {}
	for i in range(orders.size() - 1, -1, -1):
		var o: Dictionary = orders[i]
		var data := MaterialData.of(o.id)
		var base := maxf(1.0, data.base_value)
		var left: int = o.qty - o.filled
		if o.kind == "buy":
			var ask := ceili(base * _rng.randf_range(ASK_RANGE.x, ASK_RANGE.y))
			if o.price < ask:
				continue
			var n := mini(left, _rng.randi_range(SUPPLY_RANGE.x, SUPPLY_RANGE.y))
			o.filled += n
			var q := 1 + int(_rng.randf() < 0.35) + int(_rng.randf() < 0.1)
			pending_items.append({"id": o.id, "q": q, "traits": [], "n": n})
			report.append("📦 A caravana trouxe %d %s" % [n, data.display_name])
		else:
			var bid := floori(base * _rng.randf_range(BID_RANGE.x, BID_RANGE.y))
			if not demand.has(o.id):
				demand[o.id] = _rng.randi_range(DEMAND_RANGE.x, DEMAND_RANGE.y)
			if o.price > bid or demand[o.id] <= 0:
				continue
			var n := mini(left, int(demand[o.id]))
			demand[o.id] -= n
			o.filled += n
			_take_escrow(o, n)
			var gain := after_tax(n * int(o.price))
			pending_money += gain
			report.append("💰 A caravana comprou %d %s (+%s)" % [n, data.display_name, WalletComponent.format(gain)])
		if o.filled >= o.qty:
			orders.remove_at(i)
	if not report.is_empty():
		changed.emit()
	return report

func get_state() -> Dictionary:
	var saved_orders := []
	for o in orders:
		var d := o.duplicate(true)
		d.id = String(o.id)
		saved_orders.append(d)
	var items := []
	for e in pending_items:
		items.append({"id": String(e.id), "q": e.q, "traits": e.traits.map(func(t): return String(t)), "n": e.n, "memory": e.get("memory", {})})
	return {"orders": saved_orders, "money": pending_money, "items": items}

func apply_state(d: Dictionary) -> void:
	orders.clear()
	for o in d.get("orders", []):
		var escrow: Array = []
		for e in o.get("escrow", []):
			escrow.append({"q": int(e.q), "traits": Array(e.get("traits", [])).map(func(t): return StringName(t)), "n": int(e.n), "memory": e.get("memory", {})})
		orders.append({"kind": str(o.kind), "id": StringName(o.id), "qty": int(o.qty), "filled": int(o.filled), "price": int(o.price), "escrow": escrow})
	pending_money = int(d.get("money", 0))
	pending_items.clear()
	for e in d.get("items", []):
		pending_items.append({"id": StringName(e.id), "q": int(e.q), "traits": Array(e.get("traits", [])).map(func(t): return StringName(t)), "n": int(e.n), "memory": e.get("memory", {})})
	changed.emit()

func _check(id: StringName, qty: int, price: int) -> String:
	if orders.size() >= MAX_ORDERS:
		return "Limite de %d ordens abertas" % MAX_ORDERS
	if not GOODS.has(id):
		return "O Mercado não negocia isso"
	if qty < 1 or qty > MAX_QTY:
		return "Quantidade de 1 a %d" % MAX_QTY
	if price < 1:
		return "Preço mínimo 1 $S"
	return ""

## Tira `n` do que está travado na ordem de venda, das piores ★ primeiro (já vieram nessa ordem)
func _take_escrow(o: Dictionary, n: int) -> void:
	var left := n
	for e in o.escrow:
		var k := mini(left, int(e.n))
		e.n -= k
		left -= k
		if left == 0:
			break
