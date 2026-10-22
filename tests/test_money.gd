extends SceneTree

## GDD-05 §5: Dólares de Sucata — carteira, contratos (torneira), loja da Alquimista (ralo) e save.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("💰 TESTANDO DÓLARES DE SUCATA (GDD-05 §5)")
	print("========================================================")
	test_wallet()
	test_contracts_and_shop()
	print("\n🎉 TODOS OS TESTES DE MOEDA PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _make_player() -> Player:
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	return player

func test_wallet() -> void:
	print("\n[1/2] Carteira e save...")
	var player := _make_player()
	var w := player.wallet
	assert(w != null and w.money == WalletComponent.STARTING_MONEY, "Personagem novo começa com 50 $S")
	assert(not w.spend(999) and w.money == 50, "Sem saldo não gasta nem fica negativo")
	assert(w.spend(20) and w.money == 30, "Gastar desconta do saldo")
	w.add(15)
	assert(w.money == 45 and WalletComponent.format(45) == "45 $S", "Ganhar soma e formata em $S")
	var data: Dictionary = JSON.parse_string(JSON.stringify(root.get_node("SaveGame").collect(player)))
	var p2 := _make_player()
	root.get_node("SaveGame").apply_save(p2, data)
	assert(p2.wallet.money == 45, "Saldo volta do save")
	player.free()
	p2.free()
	print("  ✓ Saldo inicial, gasto sem negativo, ganho e save")

func test_contracts_and_shop() -> void:
	print("\n[2/2] Contratos (torneira) e loja (ralo)...")
	var city := CityHub.new()
	root.add_child(city)
	var player := _make_player()
	assert(city.contracts.size() == CityHub.CONTRACT_SLOTS, "Sempre 3 contratos abertos")
	var ids := city.contracts.map(func(c): return c.id)
	assert(ids.size() == 3 and ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2], "Contratos pedem materiais diferentes")

	var c: Dictionary = city.contracts[0]
	assert(c.reward == CityHub.contract_reward(c.id, c.amount), "Recompensa = valor-base × quantidade × 1,5")
	assert(not city.deliver_contract(0, player), "Sem o material não entrega")
	player.inventory.add_material(c.id, c.amount + 2)
	var before := player.wallet.money
	assert(city.deliver_contract(0, player), "Com o material entrega")
	assert(player.wallet.money == before + c.reward, "Paga em $S")
	assert(player.inventory.get_material_count(c.id) == 2, "Gasta só o pedido")
	assert(city.contracts.size() == 3, "Um contrato novo entra no lugar")

	var price := city.shop_price(&"pocao")
	assert(price == 15, "Poção custa 15 $S sem reputação")
	player.wallet.set_money(20)
	assert(city.buy(&"pocao", player) and player.wallet.money == 5, "Comprar gasta o preço")
	assert(player.inventory.get_material_count(&"pocao") == 1, "Item vai para a mochila")
	assert(not city.buy(&"pocao", player) and player.wallet.money == 5, "Sem saldo não compra")
	assert(not city.buy(&"madeira", player), "Loja só vende o que está na lista")
	city.reputation = 260
	assert(is_equal_approx(city.shop_discount(), 0.10) and city.shop_price(&"mega_pocao") == 36, "Reputação dá até −10%")

	var state: Dictionary = JSON.parse_string(JSON.stringify(city.get_state()))
	city.free()
	var city2 := CityHub.new()
	root.add_child(city2)
	city2.apply_state(state)
	assert(city2.contracts.size() == 3 and city2.contracts[0].id == StringName(state["contracts"][0]["id"]), "Contratos voltam do save")
	city2.free()
	player.free()
	print("  ✓ 3 contratos, entrega paga, loja gasta, desconto e save")
