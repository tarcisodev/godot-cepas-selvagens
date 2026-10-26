extends SceneTree

## B30 / GDD-05 §3, GDD-03 §8:
## Teste do Mercado Negro Clandestino, Armadilhas de Caça & Baús do Ermo.

const _HuntingTrap = preload("res://scripts/systems/hunting_trap.gd")
const _HuntingBait = preload("res://scripts/systems/hunting_bait.gd")
const _TrapSystem = preload("res://scripts/systems/trap_system.gd")
const _BlackMarketSystem = preload("res://scripts/systems/black_market_system.gd")
const _WildChest = preload("res://scripts/world/wild_chest.gd")
const _BlackMarketStation = preload("res://scripts/town/black_market_station.gd")
const _BlackMarketScreen = preload("res://scripts/ui/black_market_screen.gd")
const _WildCreature = preload("res://scripts/creatures/wild_creature.gd")
const _CreatureDNA = preload("res://scripts/data/creature_dna.gd")
const _ForgedItem = preload("res://scripts/data/forged_item.gd")
const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const _WalletComponent = preload("res://scripts/components/wallet_component.gd")
const _CardCollectionComponent = preload("res://scripts/components/card_collection_component.gd")
const _StatsComponent = preload("res://scripts/components/stats_component.gd")
const _PoolsComponent = preload("res://scripts/components/pools_component.gd")

var _started := false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🕶️ TESTANDO MERCADO NEGRO, ARMADILHAS DE CAÇA & BAÚS DO ERMO (B30)")
	print("========================================================")
	test_hunting_trap_and_mechanics()
	test_hunting_bait_and_attraction()
	test_trap_system_and_wheel_integration()
	test_black_market_system_and_orders()
	test_direct_gear_sale_and_organic_loot_circulation()
	test_wild_chest_and_station_ui()
	print("\n🎉 TODOS OS TESTES DO MERCADO NEGRO E ARMADILHAS PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_hunting_trap_and_mechanics() -> void:
	print("\n[1/6] Armadilha de Mandíbula de Caça (HuntingTrap)...")

	var trap := _HuntingTrap.new()
	root.add_child(trap)
	assert(trap.state == _HuntingTrap.State.ARMED, "Armadilha inicia armada")
	assert(trap.is_in_group("talkable"), "Armadilha está no grupo talkable")

	# Mock de criatura selvagem
	var creature := Node3D.new()
	creature.name = "CreatureMock"
	creature.add_to_group("wild_creatures")
	var stats := _StatsComponent.new()
	stats.name = "StatsComponent"
	creature.add_child(stats)
	var pools := _PoolsComponent.new()
	pools.name = "PoolsComponent"
	pools.stats = stats
	creature.add_child(pools)
	creature.set("dna", _CreatureDNA.randomized(_CreatureDNA.Species.TROTADOR, 1))
	root.add_child(creature)

	creature.set_script(load("res://scripts/creatures/wild_creature.gd"))

	# Teste de disparo
	var initial_hp: float = pools.current_health
	var ok_snap := trap.snap_shut(creature)
	assert(ok_snap, "Disparo da armadilha executado com sucesso")
	assert(trap.state == _HuntingTrap.State.TRIGGERED, "Estado mudou para TRIGGERED")
	assert(pools.current_health < initial_hp, "Alvo recebeu dano físico da armadilha")

	# Teste de desarme e recolhimento de uma nova armadilha
	var trap2 := _HuntingTrap.new()
	root.add_child(trap2)

	var player := Node3D.new()
	var inv := _InventoryComponent.new()
	inv.name = "InventoryComponent"
	player.add_child(inv)
	root.add_child(player)

	assert(inv.get_material_count(&"armadilha_mola") == 0, "Sem armadilhas inicialmente")
	trap2.talk_to(player)
	assert(trap2.state == _HuntingTrap.State.DISARMED, "Armadilha desarmada pelo jogador")
	assert(inv.get_material_count(&"armadilha_mola") == 1, "Armadilha recolhida de volta para a mochila")

	trap.queue_free()
	trap2.queue_free()
	creature.queue_free()
	player.queue_free()
	print("  -> Mandíbula de ferro, dano anatômico e desarme validados.")

func test_hunting_bait_and_attraction() -> void:
	print("\n[2/6] Isca Odorífera de Caça (HuntingBait)...")

	var bait := _HuntingBait.new()
	bait.scent_radius = 20.0
	bait.lifetime = 60.0
	root.add_child(bait)

	assert(bait.is_in_group("hunting_baits"), "Isca no grupo hunting_baits")
	assert(bait.is_in_group("talkable"), "Isca no grupo talkable")

	# Mock de criatura com atração
	var creature := Node3D.new()
	creature.name = "AttractedCreature"
	creature.add_to_group("wild_creatures")
	creature.set_meta("hunger", 0.8)
	root.add_child(creature)
	creature.global_position = bait.global_position + Vector3(5, 0, 0)

	# Simula alimentação ao alcançar a isca
	var consumed_emitted := [false]
	bait.consumed.connect(func(_b, _c): consumed_emitted[0] = true)
	bait.call("_feed_creature", creature)

	assert(bait.is_consumed, "Isca marcada como consumida")
	var hunger_val: float = creature.get_meta("hunger", 1.0)
	assert(hunger_val == 0.0, "Fome da criatura saciada")
	assert(consumed_emitted[0], "Sinal consumed emitido")

	# Teste de recolhimento antes do consumo
	var bait2 := _HuntingBait.new()
	root.add_child(bait2)

	var player := Node3D.new()
	var inv := _InventoryComponent.new()
	inv.name = "InventoryComponent"
	player.add_child(inv)
	root.add_child(player)

	bait2.talk_to(player)
	assert(inv.get_material_count(&"isca_feromonio") == 1, "Isca recolhida para a mochila")

	creature.queue_free()
	player.queue_free()
	bait2.queue_free()
	print("  -> Emissão de odor, saciedade de criatura e recolhimento validados.")

func test_trap_system_and_wheel_integration() -> void:
	print("\n[3/6] Gerenciador TrapSystem & Roda Rápida...")

	var sys := _TrapSystem.new()
	root.add_child(sys)

	var player := Node3D.new()
	var inv := _InventoryComponent.new()
	inv.name = "InventoryComponent"
	player.add_child(inv)
	root.add_child(player)

	# Tentar armar sem material deve falhar
	var ok_fail := sys.deploy_trap_by_player(player, &"armadilha_mola")
	assert(not ok_fail, "Armar sem ter o item na mochila falha")

	# Adiciona materiais na mochila
	inv.add_material(&"armadilha_mola", 2, 2)
	inv.add_material(&"isca_feromonio", 2, 2)

	# Armar com material
	var ok_trap := sys.deploy_trap_by_player(player, &"armadilha_mola")
	assert(ok_trap, "Armadilha posicionada com sucesso")
	assert(inv.get_material_count(&"armadilha_mola") == 1, "Consumiu 1x armadilha_mola")

	# Colocar isca com material
	var ok_bait := sys.deploy_bait_by_player(player, &"isca_feromonio")
	assert(ok_bait, "Isca odorífera posicionada com sucesso")
	assert(inv.get_material_count(&"isca_feromonio") == 1, "Consumiu 1x isca_feromonio")

	sys.queue_free()
	player.queue_free()
	print("  -> Deploy de armadilha e isca por consumo de inventário validado.")

func test_black_market_system_and_orders() -> void:
	print("\n[4/6] Mercado Negro: Ordens Sistêmicas de Compra...")

	var bm := _BlackMarketSystem.new()
	root.add_child(bm)

	assert(bm.systemic_orders.size() >= 4, "Mercado Negro gerou pelo menos 4 ordens sistêmicas")

	var player := Node3D.new()
	var inv := _InventoryComponent.new()
	inv.name = "InventoryComponent"
	var wallet := _WalletComponent.new()
	wallet.name = "WalletComponent"
	wallet.money = 50
	player.add_child(inv)
	player.add_child(wallet)
	root.add_child(player)

	# Procura uma ordem de material
	var mat_order: Dictionary = {}
	for ord in bm.systemic_orders:
		if ord.type == "material":
			mat_order = ord
			break
	assert(not mat_order.is_empty(), "Ordem de material encontrada")

	# Sem material, can_fulfill_order deve ser falso
	assert(not bm.can_fulfill_order(mat_order.id, player), "Não pode cumprir sem materiais")

	# Adiciona materiais necessários
	inv.add_material(mat_order.target_id, int(mat_order.quantity), int(mat_order.min_quality))
	assert(bm.can_fulfill_order(mat_order.id, player), "Pode cumprir com materiais suficientes")

	var prev_money: int = wallet.money
	var res := bm.fulfill_order(mat_order.id, player)
	assert(res.success, "Ordem cumprida com sucesso")
	assert(wallet.money == prev_money + int(mat_order.reward_money), "Recebeu remuneração em $S com prêmio sistêmico")
	assert(inv.get_material_count(mat_order.target_id) == 0, "Materiais entregues foram consumidos")

	bm.queue_free()
	player.queue_free()
	print("  -> Ordens sistêmicas, validação e liquidação em $S validadas.")

func test_direct_gear_sale_and_organic_loot_circulation() -> void:
	print("\n[5/6] Venda Direta de Equipamentos & Cofre de Loot Orgânico...")

	var bm := _BlackMarketSystem.new()
	root.add_child(bm)

	var player := Node3D.new()
	var inv := _InventoryComponent.new()
	inv.name = "InventoryComponent"
	var wallet := _WalletComponent.new()
	wallet.name = "WalletComponent"
	wallet.money = 100
	player.add_child(inv)
	player.add_child(wallet)
	root.add_child(player)

	# Cria uma espada forjada pelo jogador
	var sword := _ForgedItem.new()
	sword.recipe_id = &"espada_ferro"
	sword.display_name = "Espada de Ferro Nobre"
	sword.slot = _ForgedItem.Slot.MAIN_HAND
	sword.family = &"ferro"
	sword.quality = 3
	sword.traits.append(&"serrilhado")
	inv.add_item(sword)

	assert(inv.items.has(sword), "Espada está na mochila")
	assert(bm.organic_loot_pool.is_empty(), "Cofre de Loot Orgânico inicia vazio")

	# Vende ao Mercado Negro
	var sell_res := bm.sell_gear(player, sword)
	assert(sell_res.success, "Venda concluída com sucesso")
	assert(not inv.items.has(sword), "Espada removida da mochila do jogador")
	assert(wallet.money > 100, "Jogador recebeu $S pela liquidação")
	assert(bm.organic_loot_pool.size() == 1, "Equipamento transferido para o fluxo de Loot Orgânico")

	# Validação do Triturador de Excesso (Ralo permanente do GDD-05 §3)
	for i in range(15):
		var dummy_item := _ForgedItem.new()
		dummy_item.recipe_id = &"espada_ferro"
		dummy_item.display_name = "Peça Excedente %d" % i
		dummy_item.quality = 1
		bm.deposit_organic_loot(dummy_item)

	assert(bm.organic_loot_pool.size() <= _BlackMarketSystem.MAX_ORGANIC_POOL, "Cofre respeita limite máximo (12 peças)")
	assert(bm.total_items_shredded > 0, "Triturador de Excesso destruiu peças excedentes como ralo econômico")

	# Teste de take_organic_loot()
	var loot_item: _ForgedItem = bm.take_organic_loot()
	assert(loot_item != null, "Loot orgânico recuperado")
	assert(not loot_item.display_name.is_empty(), "Item possui nome válido")

	# Teste de serialização
	var save_data := bm.to_dict()
	assert(save_data.has("orders"), "Save contém ordens")
	assert(save_data.has("organic_pool"), "Save contém cofre de loot orgânico")

	var bm2 := _BlackMarketSystem.new()
	bm2.from_dict(save_data)
	assert(bm2.organic_loot_pool.size() == bm.organic_loot_pool.size(), "Cofre orgânico restaurado com sucesso")
	assert(bm2.total_items_shredded == bm.total_items_shredded, "Contador de trituração restaurado")

	bm.queue_free()
	bm2.queue_free()
	player.queue_free()
	print("  -> Venda direta, cofre orgânico, triturador de excesso e save/load validados.")

func test_wild_chest_and_station_ui() -> void:
	print("\n[6/6] Baú do Ermo (WildChest) & Estação do Mercado Negro...")

	var bm := _BlackMarketSystem.new()
	root.add_child(bm)

	# Coloca um item específico no cofre orgânico
	var custom_gear := _ForgedItem.new()
	custom_gear.recipe_id = &"gibao_andarilho"
	custom_gear.display_name = "Gibão das Sombras"
	custom_gear.quality = 4
	bm.deposit_organic_loot(custom_gear)

	var chest := _WildChest.new()
	chest.chest_id = &"chest_ruinas_antigas"
	chest.reward_money = 40
	root.add_child(chest)

	var player := Node3D.new()
	var inv := _InventoryComponent.new()
	inv.name = "InventoryComponent"
	var wallet := _WalletComponent.new()
	wallet.name = "WalletComponent"
	wallet.money = 20
	var cards := _CardCollectionComponent.new(false)
	cards.name = "CardCollectionComponent"
	player.add_child(inv)
	player.add_child(wallet)
	player.add_child(cards)
	root.add_child(player)

	assert(not chest.is_opened, "Baú inicia fechado")
	assert(inv.items.is_empty(), "Inventário sem itens forjados")

	# Abre o baú
	chest.talk_to(player)
	assert(chest.is_opened, "Baú aberto")
	assert(wallet.money == 60, "Recebeu +40 $S do baú")
	assert(inv.items.size() == 1, "Recebeu equipamento orgânico forjado")
	assert(inv.get_material_count(&"oleo_peixe") == 2, "Recebeu óleo de peixe raro")
	assert(cards.is_card_unlocked(&"trenchcoat_mushrooms"), "Carta 3D Cogumelos de Sobretudo destrancada no álbum!")

	# Tentar abrir novamente não deve conceder loot duplicado
	chest.talk_to(player)
	assert(wallet.money == 60, "Não recebe dinheiro duplicado")
	assert(inv.items.size() == 1, "Não recebe equipamento duplicado")

	# Teste da Estação 3D do Mercado Negro
	var station := _BlackMarketStation.new()
	root.add_child(station)
	assert(station.is_in_group("talkable"), "Estação no grupo talkable")
	assert(station.is_in_group("black_market_station"), "Estação no grupo black_market_station")

	station.talk_to(player)
	assert(station._screen != null, "Tela do Mercado Negro criada")
	assert(station._screen.visible, "Tela do Mercado Negro aberta")

	station._screen.close()
	assert(not station._screen.visible, "Tela do Mercado Negro fechada")

	chest.queue_free()
	station.queue_free()
	bm.queue_free()
	player.queue_free()
	print("  -> Baú do Ermo (loot orgânico, $S, cartas 3D) e Estação Clandestina validados.")
