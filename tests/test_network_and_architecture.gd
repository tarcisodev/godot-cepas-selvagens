extends SceneTree

func _init() -> void:
	print("\n==========================================")
	print("🧪 TESTANDO ARQUITETURA DE REDE E ANATOMIA (B06)")
	print("==========================================")
	
	test_network_manager()
	test_anatomy_system()
	
	print("\n🎉 TODOS OS TESTES DE REDE E ARQUITETURA PASSARAM!")
	print("==========================================\n")
	quit(0)

func test_network_manager() -> void:
	print("\n[1/2] Testando autoridade do NetworkManager (ADR-0002)...")
	var net := NetworkManagerAutoload.new()
	assert(net.is_server_authoritative(), "Modo padrão offline deve ser autoritativo")
	assert(net.state == NetworkManagerAutoload.NetworkState.OFFLINE_HOST, "Estado inicial deve ser OFFLINE_HOST")
	
	# Teste de inicialização de servidor local
	var err := net.start_server(18787, 4)
	assert(err == OK, "Deve conseguir criar servidor local ENet na porta 18787")
	assert(net.is_server_authoritative(), "Servidor iniciado deve ser autoritativo")
	assert(net.state == NetworkManagerAutoload.NetworkState.HOSTING_SERVER, "Estado deve ser HOSTING_SERVER")
	
	net.cleanup_peer()
	net.setup_offline_host()
	assert(net.is_server_authoritative(), "Após cleanup, volta para OFFLINE_HOST")
	net.free()
	print("  ✓ NetworkManager e autoridade de servidor validados com sucesso!")

func test_anatomy_system() -> void:
	print("\n[2/2] Testando AnatomyComponent e quebra de partes (GDD-03)...")
	var creature := Node.new()
	creature.name = "TestCreature"
	
	var anatomy := AnatomyComponent.new()
	creature.add_child(anatomy)
	anatomy.register_part(&"horn", 50.0, false)
	anatomy.register_part(&"tail", 40.0, true) # severable
	
	assert(anatomy.is_part_intact(&"horn"), "Chifre deve nascer intacto")
	assert(anatomy.is_part_intact(&"tail"), "Cauda deve nascer intacta")
	
	# Dano parcial no chifre (30 de 50 -> 20 restante, vira CRACKED)
	var broke := anatomy.damage_part(&"horn", 30.0)
	assert(not broke, "30 de dano em 50 de HP não quebra o chifre")
	assert(anatomy.get_part_state(&"horn") == AnatomyComponent.PartState.CRACKED, "Abaixo de 50% de HP deve ficar Rachado")
	
	# Dano letal no chifre (mais 25 de dano -> quebra)
	broke = anatomy.damage_part(&"horn", 25.0)
	assert(broke, "Zerar HP do chifre deve quebrar")
	assert(anatomy.get_part_state(&"horn") == AnatomyComponent.PartState.BROKEN, "Estado deve ser BROKEN")
	
	# Dano letal na cauda decepável (45 de dano em 40 HP -> decepa)
	var severed := anatomy.damage_part(&"tail", 45.0)
	assert(severed, "Zerar HP da cauda severable deve decepar")
	assert(anatomy.get_part_state(&"tail") == AnatomyComponent.PartState.SEVERED, "Estado deve ser SEVERED")
	
	creature.free()
	print("  ✓ AnatomyComponent e estados de quebra/decepamento validados com sucesso!")
