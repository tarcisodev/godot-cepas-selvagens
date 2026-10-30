class_name BlackMarketSystem
extends Node

## Sistema do Mercado Negro Clandestino (GDD-05 §3).
## Atua como o regulador sistêmico e ponte entre o artesanato dos jogadores e os baús de tesouro dos ermos:
## 1. Emite ordens de compra sistêmicas (+40% a +60% sobre o valor base) para drenar itens e injetar $S.
## 2. Compra equipamentos forjados de jogadores e armazena no cofre de Loot Orgânico.
## 3. Alimenta baús dos ermos com equipamentos genuínos de jogadores (take_organic_loot).
## 4. Triturador de Excesso (Ralo): se o cofre ultrapassar a capacidade máxima, desmancha itens excedentes.

const _ForgedItem = preload("res://scripts/data/forged_item.gd")
const _Forge = preload("res://scripts/systems/forge.gd")
const _WalletComponent = preload("res://scripts/components/wallet_component.gd")
const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const _MaterialData = preload("res://scripts/data/material_data.gd")

const MAX_ORGANIC_POOL: int = 12

signal order_fulfilled(order: Dictionary, player: Node, payout: int)
signal gear_sold(item: _ForgedItem, player: Node, payout: int)
signal organic_loot_taken(item: _ForgedItem)
signal orders_refreshed()

static var _instance: Node = null

var systemic_orders: Array[Dictionary] = []
var organic_loot_pool: Array[Dictionary] = []
var total_items_shredded: int = 0
var _order_counter: int = 1

func _ready() -> void:
	add_to_group("black_market")
	_instance = self
	if systemic_orders.is_empty():
		generate_systemic_orders()

static func get_instance(tree: SceneTree = null) -> Node:
	if _instance != null and is_instance_valid(_instance):
		return _instance
	if tree != null:
		var found := tree.get_first_node_in_group("black_market")
		if found != null:
			_instance = found
			return found
		var root := tree.current_scene
		if root != null:
			var script = load("res://scripts/systems/black_market_system.gd")
			var new_sys = script.new()
			new_sys.name = "BlackMarketSystem"
			root.add_child(new_sys)
			_instance = new_sys
			return new_sys
	return null

## Gera novas ordens sistêmicas de compra
func generate_systemic_orders() -> void:
	systemic_orders.clear()
	
	# Ordem 1: Equipamento Forjado de Ferro/Aço
	systemic_orders.append({
		"id": "bm_order_%d" % _next_id(),
		"type": "gear",
		"target_id": &"espada_ferro",
		"title": "Armaria Clandestina: Espada de Ferro",
		"description": "Contrabandistas buscam espadas de ferro de pelo menos 2★ para reabastecer mercenários.",
		"min_quality": 2,
		"quantity": 1,
		"reward_money": 65, # Valor base ~30 * 1.5 + prêmio
		"icon": "🗡️"
	})

	# Ordem 2: Equipamento Forjado de Armadura
	systemic_orders.append({
		"id": "bm_order_%d" % _next_id(),
		"type": "gear",
		"target_id": &"gibao_andarilho",
		"title": "Proteção para a Fronteira: Gibão do Andarilho",
		"description": "Exploradores dos ermos pagam alto por gibões resistentes com costura de couro.",
		"min_quality": 2,
		"quantity": 1,
		"reward_money": 70,
		"icon": "🦺"
	})

	# Ordem 3: Material Biológico Nobre de Monstro
	systemic_orders.append({
		"id": "bm_order_%d" % _next_id(),
		"type": "material",
		"target_id": &"chifre_rinolito",
		"title": "Demanda Alquímica: Chifre de Rinolito",
		"description": "Alquimistas proibidos exigem 2 chifres íntegros para destilação terpênica.",
		"min_quality": 1,
		"quantity": 2,
		"reward_money": 90, # 40 base * 2 = 80 + prêmio
		"icon": "🦏"
	})

	# Ordem 4: Solventes e Óleos Raros
	systemic_orders.append({
		"id": "bm_order_%d" % _next_id(),
		"type": "material",
		"target_id": &"oleo_peixe",
		"title": "Refino Biológico: Óleo de Peixe Purificado",
		"description": "Graxa especial para engrenagens de armadilhas e solvente de venenos.",
		"min_quality": 2,
		"quantity": 2,
		"reward_money": 45,
		"icon": "🧪"
	})

	orders_refreshed.emit()

func _next_id() -> int:
	var id := _order_counter
	_order_counter += 1
	return id

## Verifica se o jogador possui os requisitos para cumprir uma ordem
func can_fulfill_order(order_id: String, player: Node) -> bool:
	var order := get_order(order_id)
	if order.is_empty() or player == null:
		return false
	
	var inv: _InventoryComponent = _get_inventory(player)
	if inv == null:
		return false

	if order.type == "gear":
		var target_recipe: StringName = order.target_id
		var min_q: int = int(order.min_quality)
		for item in inv.items:
			if item and item.recipe_id == target_recipe and item.quality >= min_q:
				return true
		return false
	elif order.type == "material":
		var mat_id: StringName = order.target_id
		var req_qty: int = int(order.quantity)
		var min_q: int = int(order.get("min_quality", 1))
		var total := 0
		for s in inv.get_stacks(mat_id):
			if int(s.get("quality", 1)) >= min_q:
				total += int(s.get("amount", 0))
		return total >= req_qty

	return false

## Cumpre a ordem, consome os itens do jogador, paga em $S e abastece o Loot Orgânico
func fulfill_order(order_id: String, player: Node) -> Dictionary:
	var res := { &"success": false, &"payout": 0, &"message": "" }
	var order := get_order(order_id)
	if order.is_empty():
		res.message = "Ordem não encontrada."
		return res

	if not can_fulfill_order(order_id, player):
		res.message = "Recursos insuficientes na mochila para cumprir esta ordem."
		return res

	var inv: _InventoryComponent = _get_inventory(player)
	var wallet: _WalletComponent = _get_wallet(player)
	var payout: int = int(order.reward_money)

	if order.type == "gear":
		var target_recipe: StringName = order.target_id
		var min_q: int = int(order.min_quality)
		var chosen_item: _ForgedItem = null
		for item in inv.items:
			if item and item.recipe_id == target_recipe and item.quality >= min_q:
				chosen_item = item
				break
		if chosen_item == null:
			res.message = "Equipamento correspondente não encontrado."
			return res

		# Remove da mochila e adiciona ao Loot Orgânico do mundo
		inv.remove_item(chosen_item)
		deposit_organic_loot(chosen_item)
	elif order.type == "material":
		var mat_id: StringName = order.target_id
		var req_qty: int = int(order.quantity)
		if not inv.consume_material(mat_id, req_qty):
			res.message = "Falha ao consumir materiais."
			return res

	# Paga recompensa em $S
	if wallet:
		wallet.add(payout)

	if player and player.has_signal("posture_changed"):
		player.posture_changed.emit("💰 Mercado Negro: Ordem cumprida! +%d $S" % payout)

	res.success = true
	res.payout = payout
	res.message = "Ordem cumprida com sucesso!"

	EventBusAutoload.report(player, &"venda", {"money": payout, "where": "mercado_negro"})
	order_fulfilled.emit(order, player, payout)

	# Substitui a ordem cumprida por uma nova
	_replace_order(order_id)
	return res

## Venda Direta de Equipamento Forjado pelo jogador
func sell_gear(player: Node, item: _ForgedItem) -> Dictionary:
	var res := { &"success": false, &"payout": 0, &"message": "" }
	if player == null or item == null:
		res.message = "Item ou jogador inválido."
		return res

	var inv: _InventoryComponent = _get_inventory(player)
	var wallet: _WalletComponent = _get_wallet(player)
	if inv == null or not inv.items.has(item):
		res.message = "Peça não encontrada na mochila."
		return res

	var payout := calculate_gear_payout(item)

	inv.remove_item(item)
	deposit_organic_loot(item)

	if wallet:
		wallet.add(payout)

	if player and player.has_signal("posture_changed"):
		player.posture_changed.emit("🕶️ %s vendido ao Mercado Negro por %d $S." % [item.display_name, payout])

	res.success = true
	res.payout = payout
	res.message = "Equipamento vendido e transferido para o fluxo dos ermos."

	EventBusAutoload.report(player, &"venda", {"money": payout, "item": item.display_name, "where": "mercado_negro"})
	gear_sold.emit(item, player, payout)
	return res

## Calcula o valor de liquidação em $S para uma peça forjada
func calculate_gear_payout(item: _ForgedItem) -> int:
	if item == null:
		return 0
	var base := 25
	var r: Dictionary = item.recipe()
	if not r.is_empty():
		base = 20 + int(r.get("load", 0.0) * 1.5)
		if item.is_weapon():
			base += 15
	var q_mult: float = _ForgedItem.QUALITY_MULT[clampi(item.quality, 1, 5)]
	var trait_bonus: int = item.traits.size() * 5
	return maxi(15, int(float(base) * q_mult + float(trait_bonus)))

## Adiciona equipamento ao cofre de Loot Orgânico e aplica o Triturador de Excesso (Ralo)
func deposit_organic_loot(item: _ForgedItem) -> void:
	if item == null:
		return
	organic_loot_pool.append(item.to_dict())
	
	# Triturador de Excesso (GDD-05 §3): ralo permanente se ultrapassar capacidade
	if organic_loot_pool.size() > MAX_ORGANIC_POOL:
		organic_loot_pool.pop_front()
		total_items_shredded += 1

## Retira uma peça forjada do Loot Orgânico para recompensar um baú dos ermos
func take_organic_loot() -> _ForgedItem:
	if not organic_loot_pool.is_empty():
		var data: Dictionary = organic_loot_pool.pop_back()
		var item: _ForgedItem = _ForgedItem.from_dict(data)
		organic_loot_taken.emit(item)
		return item

	# Fallback sistêmico se o cofre estiver vazio: gera peça de qualidade 2★ ou 3★
	var fallback := _ForgedItem.new()
	var fallback_recipes := [&"espada_ferro", &"gibao_andarilho", &"elmo_chifre_de_pedra", &"mangual"]
	fallback.recipe_id = fallback_recipes[randi() % fallback_recipes.size()]
	var r: Dictionary = _Forge.RECIPES.get(fallback.recipe_id, {})
	fallback.display_name = str(r.get("name", "Peça dos Ermos"))
	fallback.slot = r.get("slot", _ForgedItem.Slot.MAIN_HAND)
	fallback.family = r.get("family", &"couro")
	fallback.quality = 2 + (randi() % 2) # 2★ ou 3★
	fallback.durability = 100.0
	fallback.max_durability = 100.0
	if randf() > 0.4:
		fallback.traits.append(&"balanceado")

	organic_loot_taken.emit(fallback)
	return fallback

func get_order(order_id: String) -> Dictionary:
	for ord in systemic_orders:
		if ord.get("id", "") == order_id:
			return ord
	return {}

func _replace_order(order_id: String) -> void:
	for i in range(systemic_orders.size()):
		if systemic_orders[i].get("id", "") == order_id:
			var old_type: String = systemic_orders[i].get("type", "material")
			if old_type == "gear":
				systemic_orders[i] = {
					"id": "bm_order_%d" % _next_id(),
					"type": "gear",
					"target_id": &"couraca_galhada",
					"title": "Armadura de Caçador: Couraça de Galhada",
					"description": "Contrabandistas procuram couraças com chifre galhado para expedições no vale.",
					"min_quality": 2,
					"quantity": 1,
					"reward_money": 80,
					"icon": "🧥"
				}
			else:
				systemic_orders[i] = {
					"id": "bm_order_%d" % _next_id(),
					"type": "material",
					"target_id": &"adubo_organico",
					"title": "Fertilizante Mineralizado: Adubo Orgânico",
					"description": "Cultivadores clandestinos de cepas pagam bem por adubo de alta absorção.",
					"min_quality": 2,
					"quantity": 3,
					"reward_money": 50,
					"icon": "🌱"
				}
			break
	orders_refreshed.emit()

func to_dict() -> Dictionary:
	return {
		"orders": systemic_orders,
		"organic_pool": organic_loot_pool,
		"shredded_count": total_items_shredded,
		"order_counter": _order_counter
	}

func from_dict(d: Dictionary) -> void:
	if d.has("orders"):
		systemic_orders.clear()
		for ord in d["orders"]:
			systemic_orders.append(ord)
	if d.has("organic_pool"):
		organic_loot_pool.clear()
		for item_data in d["organic_pool"]:
			organic_loot_pool.append(item_data)
	total_items_shredded = int(d.get("shredded_count", 0))
	_order_counter = int(d.get("order_counter", 1))
	orders_refreshed.emit()

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
