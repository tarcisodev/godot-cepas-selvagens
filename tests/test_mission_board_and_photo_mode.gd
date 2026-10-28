extends SceneTree

## B28 / GDD-05 §5, GDD-03, GDD-04, GDD-13:
## Teste do Quadro de Missões da Vila, Contratos Dinâmicos (Caça, Forja, Culinária, Foto)
## e Modo Foto / Câmera de Reconhecimento.

const _MissionBoardSystem = preload("res://scripts/systems/mission_board_system.gd")
const _MissionBoard = preload("res://scripts/town/mission_board.gd")
const _MissionBoardScreen = preload("res://scripts/ui/mission_board_screen.gd")
const _PhotoModeScreen = preload("res://scripts/ui/photo_mode_screen.gd")
const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const _WalletComponent = preload("res://scripts/components/wallet_component.gd")
const _MasteryComponent = preload("res://scripts/components/mastery_component.gd")
const _WildCreature = preload("res://scripts/creatures/wild_creature.gd")
const _CreatureDNA = preload("res://scripts/data/creature_dna.gd")

var _started := false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("📋 TESTANDO QUADRO DE MISSÕES, CONTRATOS & MODO FOTO (B28)")
	print("========================================================")
	test_mission_system_generation()
	test_contract_delivery_rewards()
	test_photo_mode_and_recognition()
	test_mission_board_station_and_ui()
	print("\n🎉 TODOS OS TESTES DE MISSÕES, CONTRATOS E MODO FOTO PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_mission_system_generation() -> void:
	print("\n[1/4] MissionBoardSystem: geração determinística nas 4 categorias...")
	var sys := _MissionBoardSystem.new()
	assert(sys.active_contracts.size() == _MissionBoardSystem.MAX_ACTIVE_CONTRACTS, "Quadro inicia com contratos ativos")

	var hunt_c := sys.generate_contract(_MissionBoardSystem.Category.HUNT)
	assert(hunt_c.category == int(_MissionBoardSystem.Category.HUNT), "Contrato de Caça gerado")
	assert(not hunt_c.target_id.is_empty(), "Possui material alvo de caça")
	assert(hunt_c.reward_money > 0 and hunt_c.reward_rep > 0, "Recompensas de ouro e reputação presentes")

	var forge_c := sys.generate_contract(_MissionBoardSystem.Category.FORGE)
	assert(forge_c.category == int(_MissionBoardSystem.Category.FORGE), "Contrato de Forja gerado")
	assert(forge_c.reward_mastery == &"forja" or forge_c.reward_mastery == &"mineracao", "Maestria de forja/mineração")

	var cook_c := sys.generate_contract(_MissionBoardSystem.Category.COOK)
	assert(cook_c.category == int(_MissionBoardSystem.Category.COOK), "Contrato de Culinária gerado")
	assert(cook_c.reward_mastery == &"culinaria", "Maestria de culinária")

	var photo_c := sys.generate_contract(_MissionBoardSystem.Category.PHOTO)
	assert(photo_c.category == int(_MissionBoardSystem.Category.PHOTO), "Contrato de Modo Foto gerado")
	assert(photo_c.is_photo == true, "Sinalizado como contrato de foto")
	assert(not photo_c.species.is_empty(), "Espécie alvo definida")

	# Serialização
	var arr := sys.to_array()
	var restored := _MissionBoardSystem.new()
	restored.load_from_array(arr)
	assert(restored.active_contracts.size() == sys.active_contracts.size(), "Serialização preserva contratos")
	print("  ✓ 4 categorias de contratos dinâmicos validadas")

func test_contract_delivery_rewards() -> void:
	print("\n[2/4] Entrega de contratos: dedução de materiais, $S, Reputação e Maestria...")
	var sys := _MissionBoardSystem.new()

	var p_node := Node3D.new()
	p_node.name = "PlayerHero"
	var inv := _InventoryComponent.new()
	inv.name = "InventoryComponent"
	p_node.add_child(inv)
	var wallet := _WalletComponent.new()
	wallet.name = "WalletComponent"
	wallet.money = 100
	p_node.add_child(wallet)
	var mastery := _MasteryComponent.new()
	mastery.name = "MasteryComponent"
	p_node.add_child(mastery)
	root.add_child(p_node)

	var city_mock := Node.new()
	city_mock.set_meta("reputation", 10)

	var contract := sys.generate_contract(_MissionBoardSystem.Category.FORGE)
	contract.target_id = &"barra_ferro"
	contract.amount_needed = 2
	contract.reward_money = 60
	contract.reward_rep = 15
	contract.reward_mastery = &"forja"
	contract.reward_xp = 40.0
	sys.active_contracts[0] = contract

	# Falha se não tiver o material
	assert(not sys.can_deliver(contract, p_node), "Sem barras de ferro não pode entregar")

	# Adiciona material na mochila
	inv.add_material(&"barra_ferro", 3, 2, [])
	assert(sys.can_deliver(contract, p_node), "Com barras de ferro pode entregar")

	# Entrega
	var delivered := sys.deliver_contract(contract, p_node, city_mock)
	assert(delivered, "Contrato entregue com sucesso")
	assert(inv.get_material_count(&"barra_ferro") == 1, "Consumiu 2 barras de ferro (sobrou 1)")
	assert(wallet.money == 160, "Recebeu +60 $S (100 + 60 = 160)")
	assert(city_mock.get_meta("reputation") == 25, "Recebeu +15 Reputação da Vila (10 + 15 = 25)")
	assert(mastery.get_level(&"forja") >= 2 or mastery.get_xp(&"forja") > 0.0, "Recebeu XP de Forja e subiu de nível")

	city_mock.free()
	p_node.free()
	print("  ✓ Entrega de materiais, economia de $S, reputação e XP validados")

func test_photo_mode_and_recognition() -> void:
	print("\n[3/4] Modo Foto: enquadramento de espécimes e avanço de contratos...")
	var sys := _MissionBoardSystem.new()
	var photo_c := sys.generate_contract(_MissionBoardSystem.Category.PHOTO)
	photo_c.species = "trotador"
	photo_c.amount_needed = 1
	photo_c.amount_current = 0
	photo_c.is_completed = false
	sys.active_contracts.clear()
	sys.active_contracts.append(photo_c)

	# Registra fotografia
	var completed := sys.record_photo("trotador", {"zoom": 1.5})
	assert(completed.size() == 1, "Foto de Trotador avança o contrato correspondente")
	assert(photo_c.is_completed, "Contrato de foto marcado como concluído")

	# Foto de espécie não relacionada não avança
	var photo_lobo := sys.generate_contract(_MissionBoardSystem.Category.PHOTO)
	photo_lobo.species = "lobo"
	photo_lobo.amount_needed = 1
	sys.active_contracts.append(photo_lobo)
	var completed2 := sys.record_photo("peixe", {})
	assert(completed2.is_empty(), "Foto de peixe não avança contrato de lobo")

	# Validação do nó PhotoModeScreen
	var screen := _PhotoModeScreen.new()
	screen.mission_system = sys
	root.add_child(screen)
	assert(screen.is_in_group("photo_mode"), "PhotoModeScreen no grupo photo_mode")
	screen.open_photo_mode()
	assert(screen.is_active and screen.visible, "Modo foto ativo")
	screen.take_photo()
	screen.close_photo_mode()
	assert(not screen.is_active and not screen.visible, "Modo foto fecha corretamente")
	screen.free()
	print("  ✓ Modo Foto e contratos de reconhecimento ecológico validados")

func test_mission_board_station_and_ui() -> void:
	print("\n[4/4] Estação 3D MissionBoard e interface MissionBoardScreen...")
	var board := _MissionBoard.new()
	root.add_child(board)
	assert(board.is_in_group("talkable") and board.is_in_group("mission_board"), "Quadro registrado nos grupos")

	var ui_screen := _MissionBoardScreen.new()
	root.add_child(ui_screen)
	var sys := _MissionBoardSystem.new()
	ui_screen.open(null, sys, null)
	assert(ui_screen.visible, "Interface do Quadro de Missões abre")
	ui_screen.close()
	assert(not ui_screen.visible, "Interface fecha")

	ui_screen.free()
	board.free()
	print("  ✓ Estação 3D do quadro e interface validadas")
