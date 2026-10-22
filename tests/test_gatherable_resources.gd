extends SceneTree

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const GatherableClass = preload("res://scripts/gatherable_resource.gd")
const SpawnerClass = preload("res://scripts/gatherable_spawner.gd")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🌿 TESTANDO SISTEMA DE COLETA DOS 10 RECURSOS")
	print("Madeira, Galho, Folha, Fibra, Pedra, Fruta, Besouro, Ossos, Erva, Mel")
	print("========================================================")
	
	test_all_ten_resource_types_config()
	test_player_harvest_and_inventory()
	test_mastery_progression_by_gathering()
	test_respawn_cycle()
	test_bee_hazard_on_honey()
	test_spawner_population()
	
	print("\n🎉 TODOS OS TESTES DE RECURSOS PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_all_ten_resource_types_config() -> void:
	print("\n[1/6] Validando configurações dos 10 tipos de recursos...")
	var expected_ids: Array[StringName] = [
		&"madeira", &"galho", &"folha", &"fibra", &"pedra",
		&"frutinha", &"besouro", &"ossos", &"erva", &"mel"
	]
	
	for i in range(GatherableClass.Type.size()):
		var res := GatherableClass.new()
		root.add_child(res)
		res.type = i as GatherableClass.Type
		
		assert(res.material_id == expected_ids[i], "Tipo %d deve ter id %s" % [i, expected_ids[i]])
		assert(not res.display_name.is_empty(), "Display name não deve ser vazio")
		assert(not res.get_harvest_verb().is_empty(), "Verbo não deve ser vazio")
		assert(res.is_harvestable(), "Recurso novo deve estar pronto para coleta")
		assert(res.get_gather_time() > 0.0, "Tempo de coleta deve ser positivo")
		
		res.free()
	
	print("  ✓ Todos os 10 tipos de recursos possuem dados, tags e tempos válidos.")

func test_player_harvest_and_inventory() -> void:
	print("\n[2/6] Testando coleta e armazenamento no inventário do Player...")
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	
	var inv: InventoryComponent = player.inventory
	assert(inv != null, "Player deve ter InventoryComponent")
	
	# Coletando um galho
	var twig := GatherableClass.new()
	root.add_child(twig)
	twig.type = GatherableClass.Type.GALHO
	twig.min_amount = 2
	twig.max_amount = 2
	
	var before_twigs := inv.get_material_count(&"galho")
	var label := twig.harvest_next(player)
	
	assert(twig.is_collected, "Recurso deve ficar marcado como coletado")
	assert(not twig.is_harvestable(), "Recurso coletado não deve mais ser colhível")
	assert(inv.get_material_count(&"galho") == before_twigs + 2, "Inventário deve ter recebido 2 galhos")
	assert(label.contains("Galho"), "Label de retorno deve conter o nome do item")
	
	# Coletando madeira
	var wood := GatherableClass.new()
	root.add_child(wood)
	wood.type = GatherableClass.Type.MADEIRA
	wood.min_amount = 3
	wood.max_amount = 3
	wood.harvest_next(player)
	assert(inv.get_material_count(&"madeira") == 3, "Inventário deve ter 3 madeiras")
	
	# Coletando pedra
	var stone := GatherableClass.new()
	root.add_child(stone)
	stone.type = GatherableClass.Type.PEDRA
	stone.min_amount = 2
	stone.max_amount = 2
	stone.harvest_next(player)
	assert(inv.get_material_count(&"pedra") == 2, "Inventário deve ter 2 pedras")
	
	twig.free()
	wood.free()
	stone.free()
	player.free()
	print("  ✓ Coleta de Galho, Madeira e Pedra entregou os materiais corretos ao inventário!")

func test_mastery_progression_by_gathering() -> void:
	print("\n[3/6] Testando avanço de maestria (Coleta, Mineração; sem Lenharia — GDD-08)...")
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()

	var mastery: MasteryComponent = player.mastery
	assert(mastery != null, "Player deve ter MasteryComponent")
	assert(not mastery.initial_tags.has(&"lenharia"), "Lenharia saiu da lista de tags (GDD-08 §8)")

	var xp_mineracao_before: float = mastery.get_xp(&"mineracao")
	var xp_coleta_before: float = mastery.get_xp(&"coleta")

	# Cortar madeira -> sobe coleta
	var wood := GatherableClass.new()
	root.add_child(wood)
	wood.type = GatherableClass.Type.MADEIRA
	wood.harvest_next(player)
	assert(mastery.get_xp(&"coleta") > xp_coleta_before, "Madeira deveria dar XP em Coleta")
	xp_coleta_before = mastery.get_xp(&"coleta")
	
	# Minerar pedra -> sobe mineracao
	var rock := GatherableClass.new()
	root.add_child(rock)
	rock.type = GatherableClass.Type.PEDRA
	rock.harvest_next(player)
	assert(mastery.get_xp(&"mineracao") > xp_mineracao_before, "Deveria ganhar XP em Mineração")
	
	# Colher erva -> sobe coleta
	var herb := GatherableClass.new()
	root.add_child(herb)
	herb.type = GatherableClass.Type.ERVA
	herb.harvest_next(player)
	assert(mastery.get_xp(&"coleta") > xp_coleta_before, "Deveria ganhar XP em Coleta")
	
	wood.free()
	rock.free()
	herb.free()
	player.free()
	print("  ✓ Maestrias de Coleta e Mineração evoluíram com os atos físicos!")

func test_respawn_cycle() -> void:
	print("\n[4/6] Testando ciclo de renascimento (Respawn)...")
	var res := GatherableClass.new()
	root.add_child(res)
	res.type = GatherableClass.Type.FRUTINHA
	res.respawn_time = 0.5
	res.respawn_enabled = true
	
	res.harvest_next(null)
	assert(res.is_collected, "Deve estar coletado")
	assert(not res.is_harvestable(), "Não deve estar colhível")
	
	# Simula passagem de tempo
	res._process(0.6)
	assert(not res.is_collected, "Deve ter renascido após o tempo limite")
	assert(res.is_harvestable(), "Deve estar colhível novamente")
	
	res.free()
	print("  ✓ Recurso coletado renasceu perfeitamente!")

func test_bee_hazard_on_honey() -> void:
	print("\n[5/6] Testando efeito especial do Favo de Mel (Risco das Abelhas)...")
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	
	var initial_hp: float = player.pools.current_health
	var initial_vigor: float = player.pools.current_vigor
	
	var hive := GatherableClass.new()
	root.add_child(hive)
	hive.type = GatherableClass.Type.MEL
	hive.harvest_next(player)
	
	assert(player.inventory.get_material_count(&"mel") == 1, "Player deve ter recebido 1 Mel")
	assert(player.pools.current_health < initial_hp, "Abelhas devem ter causado dano na vida")
	assert(player.pools.current_vigor < initial_vigor, "Abelhas devem ter drenado vigor")
	
	hive.free()
	player.free()
	print("  ✓ Mel extraído com risco das abelhas funcionando com fidelidade!")

func test_spawner_population() -> void:
	print("\n[6/6] Testando gerador ecológico de nós de recursos...")
	var spawner := SpawnerClass.new()
	spawner.count_madeira = 2
	spawner.count_galho = 3
	spawner.count_folha = 2
	spawner.count_fibra = 2
	spawner.count_pedra = 3
	spawner.count_frutinha = 2
	spawner.count_besouro = 2
	spawner.count_ossos = 2
	spawner.count_erva = 2
	spawner.count_mel = 2
	root.add_child(spawner)
	
	var total_spawned := spawner.get_child_count()
	assert(total_spawned >= 20, "Spawner deve ter instanciado pelo menos 20 nós de recursos")
	
	spawner.free()
	print("  ✓ Spawner distribuiu nós no mapa com sucesso!")
