extends SceneTree

## B18 / GDD-05 §6: Mercado da Vila — encomendas e vendas travam dinheiro/itens, taxas de 2% e
## 4%, caravana atende dentro das faixas, cancelar devolve, retirada e save.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🏪 TESTANDO O MERCADO DA VILA (B18 / GDD-05 §6)")
	print("========================================================")
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	test_orders(player)
	test_caravan(player)
	test_cancel_collect_save(player)
	print("\n🎉 TODOS OS TESTES DO MERCADO PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_orders(player: Player) -> void:
	print("\n[1/3] Abrir ordens: trava, taxa e limites...")
	var m := VillageMarket.new(5)
	player.wallet.set_money(100)
	assert(m.place_buy(player.wallet, &"pedra", 10, 3) == "", "Encomenda de 10 pedras a 3")
	assert(player.wallet.money == 100 - 30 - 1, "Trava 30 + taxa de 2% (mínimo 1)")
	assert(m.place_buy(player.wallet, &"pocao", 1, 10) != "", "Poção é da Alquimista, não do Mercado")
	assert(m.place_buy(player.wallet, &"pedra", 21, 1) != "", "Até 20 por ordem")
	assert(m.place_buy(player.wallet, &"chifre_rinolito", 5, 40) != "", "Sem dinheiro não abre")
	player.inventory.add_material(&"madeira", 3, 1)
	player.inventory.add_material(&"madeira", 2, 3)
	assert(m.place_sell(player.inventory, player.wallet, &"madeira", 6, 2) != "", "Não vende o que não tem")
	assert(m.place_sell(player.inventory, player.wallet, &"madeira", 4, 2) == "", "Põe 4 madeiras à venda")
	assert(player.inventory.get_material_count(&"madeira") == 1 and player.inventory.get_stacks(&"madeira")[0].quality == 3, "Saem as de pior ★ primeiro")
	assert(m.orders[1].escrow.size() == 2 and m.orders[1].escrow[0].q == 1, "Lembra a ★ de cada unidade travada")
	for i in 4:
		m.place_buy(player.wallet, &"galho", 1, 1)
	assert(m.orders.size() == VillageMarket.MAX_ORDERS and m.place_buy(player.wallet, &"galho", 1, 1) != "", "Limite de 6 ordens")
	print("  ✓ Dinheiro e itens travados, taxa de listagem, limites")

func test_caravan(_player: Player) -> void:
	print("\n[2/3] Caravana: atende só dentro das faixas de preço...")
	# Encomenda acima do teto (base 2 × 1,5 = 3) sempre é atendida; abaixo do piso nunca
	var m := VillageMarket.new(9)
	m.orders.append({"kind": "buy", "id": &"pedra", "qty": 20, "filled": 0, "price": 3, "escrow": []})
	m.orders.append({"kind": "buy", "id": &"madeira", "qty": 20, "filled": 0, "price": 1, "escrow": []})
	m.orders.append({"kind": "sell", "id": &"chifre_rinolito", "qty": 3, "filled": 0, "price": 200, "escrow": [{"q": 2, "traits": [], "n": 3}]})
	m.orders.append({"kind": "sell", "id": &"folha", "qty": 20, "filled": 0, "price": 1, "escrow": [{"q": 1, "traits": [], "n": 20}]})
	m.caravan_visit()
	var pedra: Dictionary = m.orders.filter(func(o): return o.id == &"pedra")[0]
	assert(pedra.filled >= VillageMarket.SUPPLY_RANGE.x and pedra.filled <= VillageMarket.SUPPLY_RANGE.y, "Traz de 2 a 8 por visita")
	assert(m.orders.filter(func(o): return o.id == &"madeira")[0].filled == 0, "Preço abaixo do que a caravana pede: nada")
	assert(m.orders.filter(func(o): return o.id == &"chifre_rinolito")[0].filled == 0, "Chifre a 200 (base 40): caravana não paga")
	var folha: Dictionary = m.orders.filter(func(o): return o.id == &"folha")[0]
	assert(folha.filled >= 1 and folha.filled <= VillageMarket.DEMAND_RANGE.y, "Procura limitada: 1 a 6 por visita")
	assert(m.pending_money == VillageMarket.after_tax(folha.filled), "Venda paga o seu preço menos 4%")
	assert(m.pending_items.size() == 1 and m.pending_items[0].n == pedra.filled, "Pedra trazida fica a receber")
	# Ordem completa sai da lista
	for i in 6:
		m.caravan_visit()
	assert(m.orders.filter(func(o): return o.id == &"pedra").is_empty(), "Encomenda cheia é fechada")
	print("  ✓ Faixas de preço, lotes, procura limitada, taxa de venda")

func test_cancel_collect_save(player: Player) -> void:
	print("\n[3/3] Cancelar, retirar e save...")
	var m := VillageMarket.new(3)
	player.wallet.set_money(50)
	m.place_buy(player.wallet, &"pedra", 5, 2)
	var after_place := player.wallet.money
	player.inventory.add_material(&"ossos", 2, 2, [&"cicatrizado"])
	m.place_sell(player.inventory, player.wallet, &"ossos", 2, 3)
	var data: Dictionary = JSON.parse_string(JSON.stringify(m.get_state()))
	var m2 := VillageMarket.new(3)
	m2.apply_state(data)
	assert(m2.orders.size() == 2 and m2.orders[1].escrow[0].traits == [&"cicatrizado"], "Ordens voltam do save com ★ e traits")
	m2.cancel(1)
	m2.cancel(0)
	assert(m2.orders.is_empty() and m2.pending_money == 10, "Cancelar devolve o travado (a taxa não)")
	var money_before := player.wallet.money
	assert(m2.collect(player.inventory, player.wallet) == 2, "Retira dinheiro e itens")
	assert(player.wallet.money == money_before + 10 and after_place == 50 - 11, "Dinheiro de volta na carteira")
	var bones := player.inventory.get_stacks(&"ossos")
	assert(bones.size() == 1 and bones[0].quality == 2 and bones[0].traits.has(&"cicatrizado"), "Ossos voltam com a mesma ★ e trait")
	assert(not m2.has_pending(), "Nada mais a receber")
	print("  ✓ Cancelar, retirada com ★ e trait, save das ordens")
