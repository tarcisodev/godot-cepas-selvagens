extends SceneTree

const TradePackDataClass = preload("res://scripts/data/trade_pack_data.gd")
const TradeRouteManagerClass = preload("res://scripts/systems/trade_route_manager.gd")
const CaravanConvoyClass = preload("res://scripts/systems/caravan_convoy.gd")
const WorldTradePackClass = preload("res://scripts/props/world_trade_pack.gd")
const TradeRouteScreenClass = preload("res://scripts/ui/trade_route_screen.gd")
const WorldSettlementsClass = preload("res://scripts/world/world_settlements.gd")
const WalletComponentClass = preload("res://scripts/components/wallet_component.gd")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("📦 TESTANDO CARAVANAS, FARDOS DE CARGA & ROTAS (B33)")
	print("GDD-05 §2, §5; GDD-11; GDD-08 §6: Logística, Risco & Escolta")
	print("========================================================")

	test_trade_pack_data_and_pricing()
	test_trade_route_manager_buy_and_sell()
	test_fast_travel_blocking_with_trade_pack()
	test_drop_and_pickup_world_trade_pack()
	test_market_demand_equilibration()
	test_caravan_convoy_journey_and_escort()
	test_caravan_destruction()
	test_trade_route_screen_ui()

	print("\n🎉 TODOS OS TESTES DE CARAVANAS E ROTAS COMERCIAIS PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_trade_pack_data_and_pricing() -> void:
	print("\n[1/8] Fardo Comercial e cálculo de valor por distância...")
	var pack := TradePackDataClass.new(&"fardo_pescado", &"porto_bruma", Vector3(42.0, 0.0, 48.0), 1)
	assert(pack.id == &"fardo_pescado", "ID do fardo deve ser fardo_pescado")
	assert(pack.base_buy_price == 25, "Preço base de compra deve ser 25 $S")
	assert(pack.origin_settlement_id == &"porto_bruma", "Origem deve ser Porto Bruma")

	# Devolução na mesma cidade de origem (Porto Bruma): 80% do valor (sem lucro)
	var refund := pack.calculate_sale_value(&"porto_bruma", Vector3(42.0, 0.0, 48.0))
	assert(refund == 20, "Devolução à origem deve reembolsar 80%% (20 $S)")

	# Entrega na Vigia do Norte (-32, 0, -72) -> distância ~141m
	var dest_pos := Vector3(-32.0, 0.0, -72.0)
	var sale_val := pack.calculate_sale_value(&"vigia_norte", dest_pos, 1.25)
	var profit := pack.calculate_profit(&"vigia_norte", dest_pos, 1.25)
	assert(sale_val > pack.base_buy_price, "Venda em posto distante deve render mais que o custo")
	assert(profit >= 40, "Lucro líquido para rota sul-norte (~141m) deve ser expressivo (obtido: %d $S)" % profit)

	# Serialização roundtrip
	var dict := pack.to_dict()
	var restored := TradePackDataClass.from_dict(dict) as TradePackDataClass
	assert(restored.id == pack.id, "ID restaurado idêntico")
	assert(restored.base_buy_price == pack.base_buy_price, "Preço restaurado idêntico")
	print("  ✓ Cálculo de distância, devolução e serialização validados.")

func test_trade_route_manager_buy_and_sell() -> void:
	print("\n[2/8] Compra e venda de fardos pelo TradeRouteManager...")
	var manager := TradeRouteManagerClass.new()
	root.add_child(manager)

	var player := Node3D.new()
	player.name = "Mercador"
	var wallet := WalletComponentClass.new()
	wallet.money = 100
	player.add_child(wallet)
	player.set_meta("wallet", wallet)
	root.add_child(player)

	# 1. Compra de fardo de pescado em Porto Bruma (25 $S)
	var pack := manager.buy_trade_pack(player, &"fardo_pescado", &"porto_bruma")
	assert(pack != null, "Compra de fardo deve ser bem-sucedida")
	assert(wallet.money == 75, "Carteira deve debitar 25 $S (resta 75 $S)")
	assert(TradeRouteManagerClass.get_carried_pack(player) == pack, "Jogador deve registrar o fardo carregado")

	# 2. Bloqueio ao tentar comprar segundo fardo simultâneo
	var second_pack := manager.buy_trade_pack(player, &"fardo_pescado", &"porto_bruma")
	assert(second_pack == null, "Não pode carregar dois fardos ao mesmo tempo")

	# 3. Entrega e liquidação no Santuário Astral (82, 0, -38)
	var res := manager.sell_trade_pack(player, &"santuario_astral")
	assert(res["success"], "Entrega de fardo no destino deve ter sucesso")
	assert(res["sale_price"] > 25, "Preço de venda deve superar o custo")
	assert(res["profit"] > 0, "Lucro deve ser positivo")
	assert(wallet.money == 75 + res["sale_price"], "Carteira deve receber o valor total da venda")
	assert(TradeRouteManagerClass.get_carried_pack(player) == null, "Fardo deve ser retirado das costas do jogador")

	manager.free()
	player.free()
	print("  ✓ Compra, débito de carteira e liquidação com lucro validadas.")

func test_fast_travel_blocking_with_trade_pack() -> void:
	print("\n[3/8] Bloqueio obrigatório de Viagem Rápida com carga pesada...")
	var ws := WorldSettlementsClass.new()
	root.add_child(ws)

	var player := Node3D.new()
	player.name = "Viajante"
	player.position = Vector3(1.5, 0.0, 4.5)
	root.add_child(player)

	# Sem fardo: Viagem Rápida permitida
	assert(TradeRouteManagerClass.can_player_fast_travel(player), "Sem carga, Viagem Rápida deve ser permitida")
	var ft_ok := ws.fast_travel_to(&"porto_bruma", player)
	assert(ft_ok, "Viagem rápida sem carga deve ser realizada")

	# Com fardo nas costas: Viagem Rápida bloqueada (GDD-05 §2)
	var dummy_pack := TradePackDataClass.new(&"fardo_manufatura", &"vila_esperanca")
	player.set_meta("carrying_trade_pack", dummy_pack)

	assert(not TradeRouteManagerClass.can_player_fast_travel(player), "Com carga comercial, Viagem Rápida deve ser proibida")
	var ft_blocked := ws.fast_travel_to(&"vigia_norte", player)
	assert(not ft_blocked, "WorldSettlements deve rejeitar Viagem Rápida enquanto o jogador carregar fardo")

	player.set_meta("carrying_trade_pack", null)
	ws.free()
	player.free()
	print("  ✓ Regra de logística e bloqueio de Viagem Rápida validados.")

func test_drop_and_pickup_world_trade_pack() -> void:
	print("\n[4/8] Soltar e recolher fardo físico no chão do mundo...")
	var manager := TradeRouteManagerClass.new()
	root.add_child(manager)

	var player := Node3D.new()
	player.name = "Transportador"
	player.position = Vector3(15.0, 0.0, 25.0)
	root.add_child(player)

	var pack := TradePackDataClass.new(&"fardo_astral", &"santuario_astral")
	player.set_meta("carrying_trade_pack", pack)

	# Soltar fardo no mundo
	var prop := manager.drop_trade_pack(player, root)
	assert(prop != null, "Deve criar o prop WorldTradePack no mundo")
	assert(TradeRouteManagerClass.get_carried_pack(player) == null, "Jogador não deve mais ter o fardo após soltar")
	assert(prop.position.distance_to(Vector3(15.0, 0.0, 25.0)) < 0.1, "Prop deve nascer na posição do jogador")

	# Outro jogador recolhe o fardo do chão com [E]
	var scavenger := Node3D.new()
	scavenger.name = "Resgatador"
	root.add_child(scavenger)

	prop.talk_to(scavenger)
	assert(TradeRouteManagerClass.get_carried_pack(scavenger) == pack, "Novo jogador deve recolher o fardo")

	manager.free()
	player.free()
	scavenger.free()
	prop.free()
	print("  ✓ Drop e coleta de fardo físico no mundo 3D validados.")

func test_market_demand_equilibration() -> void:
	print("\n[5/8] Flutuação e recuperação de demanda regional...")
	var manager := TradeRouteManagerClass.new()
	root.add_child(manager)

	var initial_demand := manager.get_demand_multiplier(&"vigia_norte", &"fardo_pescado")
	assert(initial_demand > 1.0, "Demanda inicial de pescado na serra deve ser valorizada")

	var player := Node3D.new()
	player.name = "Comerciante"
	var wallet := WalletComponentClass.new()
	wallet.money = 200
	player.add_child(wallet)
	player.set_meta("wallet", wallet)
	root.add_child(player)

	# Realiza entrega para saturar o mercado
	var p1 := manager.buy_trade_pack(player, &"fardo_pescado", &"porto_bruma")
	manager.sell_trade_pack(player, &"vigia_norte")

	var saturated_demand := manager.get_demand_multiplier(&"vigia_norte", &"fardo_pescado")
	assert(saturated_demand < initial_demand, "Entrega deve diminuir levemente a taxa de demanda local")

	# Passagem de tempo recupera a demanda gradualmente em direção à base regional
	manager.advance_time(2.0)
	var recovered_demand := manager.get_demand_multiplier(&"vigia_norte", &"fardo_pescado")
	assert(recovered_demand > saturated_demand, "Passagem de tempo deve recuperar a demanda do mercado rumo à base")

	manager.free()
	player.free()
	print("  ✓ Saturação de entrega e recuperação orgânica de demanda validadas.")

func test_caravan_convoy_journey_and_escort() -> void:
	print("\n[6/8] Caravana itinerante, marcha, emboscada e recompensa de escolta...")
	var convoy := CaravanConvoyClass.new()
	root.add_child(convoy)

	var player := Node3D.new()
	player.name = "Guarda"
	var wallet := WalletComponentClass.new()
	wallet.money = 10
	player.add_child(wallet)
	player.set_meta("wallet", wallet)
	root.add_child(player)

	convoy.add_escort_player(player)
	assert(convoy.escorting_players.has(player), "Jogador deve ser registrado como escolta")

	# Iniciar comboio com rota
	var path: Array[Vector3] = [Vector3(0, 0, 0), Vector3(20, 0, 0), Vector3(50, 0, 0)]
	convoy.start_journey(path, &"vila_esperanca", &"porto_bruma")
	assert(convoy.status == CaravanConvoyClass.ConvoyStatus.TRAVELING, "Status deve ser TRAVELING")

	# Disparar emboscada
	convoy.trigger_ambush("Salteadores de Sucata", 2)
	assert(convoy.status == CaravanConvoyClass.ConvoyStatus.UNDER_ATTACK, "Status deve ser UNDER_ATTACK")
	assert(convoy.active_attackers == 2, "2 atacantes ativos")

	# Derrotar inimigos
	convoy.report_attacker_defeated()
	assert(convoy.status == CaravanConvoyClass.ConvoyStatus.UNDER_ATTACK, "Ainda resta 1 atacante")
	convoy.report_attacker_defeated()
	assert(convoy.status == CaravanConvoyClass.ConvoyStatus.TRAVELING, "Emboscada repelida, volta a marchar")

	# Simular aproximação e chegada ao último waypoint
	convoy.current_waypoint_idx = 2
	convoy.global_position = Vector3(49.5, 0, 0)
	convoy._physics_process(1.0)
	assert(convoy.status == CaravanConvoyClass.ConvoyStatus.ARRIVED, "Caravana deve ter chegado ao destino")
	assert(wallet.money == 10 + convoy.bounty_reward, "Jogador escolta deve receber a recompensa de 40 $S")

	convoy.free()
	player.free()
	print("  ✓ Marcha, combate de emboscada e pagamento de escolta validados.")

func test_caravan_destruction() -> void:
	print("\n[7/8] Destruição de caravana quando atacada sem defesa...")
	var convoy := CaravanConvoyClass.new()
	root.add_child(convoy)

	convoy.start_journey([Vector3.ZERO, Vector3(10, 0, 0)], &"vila_esperanca", &"porto_bruma")
	convoy.take_damage(100.0)
	assert(convoy.current_health == 200.0, "Dano aplicado à vida da caravana")

	convoy.take_damage(250.0)
	assert(convoy.current_health == 0.0, "Vida zerada")
	assert(convoy.status == CaravanConvoyClass.ConvoyStatus.DESTROYED, "Caravana deve entrar no status DESTROYED")

	convoy.free()
	print("  ✓ Integridade e status de destruição validados.")

func test_trade_route_screen_ui() -> void:
	print("\n[8/8] Interface do Usuário (TradeRouteScreen)...")
	var manager := TradeRouteManagerClass.new()
	root.add_child(manager)

	var player := Node3D.new()
	player.name = "MercadorUI"
	var wallet := WalletComponentClass.new()
	wallet.money = 150
	player.add_child(wallet)
	player.set_meta("wallet", wallet)
	root.add_child(player)

	var screen := TradeRouteScreenClass.new()
	root.add_child(screen)
	screen.open(manager, player, &"porto_bruma")

	assert(screen.visible, "Tela deve estar visível após open()")

	# Compra de fardo via UI
	screen._buy_pack(&"fardo_pescado")
	assert(TradeRouteManagerClass.get_carried_pack(player) != null, "Jogador deve carregar o fardo após compra na UI")
	assert(wallet.money == 125, "Carteira deve debitar 25 $S")

	# Soltar no chão via UI
	screen._drop_pack()
	assert(TradeRouteManagerClass.get_carried_pack(player) == null, "Fardo deve ser solto no chão via UI")

	screen.close()
	screen.free()
	manager.free()
	player.free()
	print("  ✓ Interface TradeRouteScreen validada com sucesso.")
