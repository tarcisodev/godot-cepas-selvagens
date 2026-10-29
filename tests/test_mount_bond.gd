extends SceneTree

## B37 / GDD-16 fase 1: Elo com as montarias próprias (faixas, ganhos com teto diário, fome,
## índole herdada), nome, Companheira única com ciúme, ordem Seguir/Ficar e save.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("⭐ TESTANDO O ELO COM AS MONTARIAS (B37)")
	print("========================================================")
	test_temperament_gene()
	test_bond_rules()
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	player.set_physics_process(false) # sem chão no teste
	var eco := EcosystemSpawner.new()
	for prop in ["trotador_herds", "saltarelos", "planadores", "raias", "lambari_schools", "trees", "bushes", "cepas", "mushrooms", "pinheira_groves"]:
		eco.set(prop, 0)
	root.add_child(eco)
	test_stable_and_companion(player, eco)
	test_care_dialog(player, eco)
	test_follow_order(player, eco)
	test_save(eco)
	print("\n🎉 TODOS OS TESTES DO ELO PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _dna(species: CreatureDNA.Species, seed: int, indole: Array) -> CreatureDNA:
	var d := CreatureDNA.randomized(species, seed)
	d.alleles["indole"] = indole
	return d

func test_temperament_gene() -> void:
	print("\n[1/6] Gene da índole...")
	var d := CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 42)
	assert(d.alleles.has("indole") and d.alleles["indole"].size() == 2, "Bicho novo nasce com índole")
	assert(_dna(CreatureDNA.Species.TROTADOR, 1, ["I", "I"]).temperament() == &"ousada", "II = Ousada")
	assert(_dna(CreatureDNA.Species.TROTADOR, 1, ["I", "i"]).temperament() == &"equilibrada", "Ii = Equilibrada")
	assert(_dna(CreatureDNA.Species.TROTADOR, 1, ["i", "i"]).temperament() == &"mansa", "ii = Mansa")
	assert(_dna(CreatureDNA.Species.TROTADOR, 1, ["*", "i"]).temperament() == &"leal", "Mutação = Leal")
	# Save antigo (sem o gene): a índole sai da seed, sempre igual
	var old := d.to_dict()
	old["alleles"].erase("indole")
	var a := CreatureDNA.from_dict(old)
	var b := CreatureDNA.from_dict(old)
	assert(a.alleles.has("indole") and a.alleles["indole"] == b.alleles["indole"], "Save antigo ganha índole estável")
	# Pai de save antigo cruza sem quebrar e o filho herda índole
	var parent_old := CreatureDNA.new()
	parent_old.alleles = {"porte": ["T", "t"], "chifre": ["c", "c"], "padrao": ["p", "p"]}
	var child := CreatureDNA.cross(_dna(CreatureDNA.Species.TROTADOR, 3, ["I", "I"]), parent_old, 9, 0.0)
	assert(child.alleles["indole"] == ["I", "I"], "Filho herda a índole do pai que tem o gene")
	print("  ✓ II/Ii/ii/* viram Ousada/Equilibrada/Mansa/Leal; saves antigos e cruzas seguem funcionando")

func test_bond_rules() -> void:
	print("\n[2/6] Regras do Elo...")
	var dna := _dna(CreatureDNA.Species.TROTADOR, 5, ["I", "i"])
	var b := MountBond.create(dna, &"laco", 0)
	assert(b.elo == 10.0 and not b.marked and b.band_name() == "Arisca", "Laço: Elo 10, Arisca, não marcada")
	assert(b.accepts(false), "Capturada com Elo baixo aceita outro cavaleiro")
	assert(not b.can_be_companion() and b.whistle_range() == 0.0, "Arisca não é Companheira nem ouve apito")
	var cria := MountBond.create(dna, &"cria", 0)
	assert(cria.elo == 40.0 and cria.marked and not cria.accepts(false) and cria.accepts(true), "Cria: Elo 40, só aceita o dono")
	assert(MountBond.create(dna, &"ninho", 0).band_name() == "Parceira", "Ninho começa Parceira")

	# Andar montado: +1 a cada 2 min, teto de +6 por dia de jogo
	var gained := 0.0
	for i in 20 * 60:
		gained += b.add_ride_time(1.0, 0)
	assert(gained == 6.0 and b.elo == 16.0, "20 min montado num dia dá só +6 (deu %.1f)" % gained)
	assert(b.add_ride_time(120.0, 1) == 1.0, "No dia seguinte volta a ganhar")

	# Comida: só a da espécie, 1× por dia
	assert(b.feed(&"carne_crua", 1) == 0.0, "Trotador não come carne")
	assert(b.feed(&"frutinha", 1) == 3.0, "Frutinha: +3")
	assert(b.feed(&"folha", 1) == 0.0, "Segunda refeição no mesmo dia não dá Elo")
	assert(b.care(1) == 2.0 and b.care(1) == 0.0, "Cuidar: +2, uma vez por dia")
	assert(b.fight(1) == 2.0 and b.fight(1) == 2.0 and b.fight(1) == 0.0, "Luta: até 2 vezes por dia")

	# Índole muda os ganhos
	var mansa := MountBond.create(_dna(CreatureDNA.Species.TROTADOR, 6, ["i", "i"]), &"laco", 0)
	var ousada := MountBond.create(_dna(CreatureDNA.Species.TROTADOR, 7, ["I", "I"]), &"laco", 0)
	assert(mansa.feed(&"frutinha", 0) == 6.0 and ousada.feed(&"frutinha", 0) == 1.5, "Mansa ganha o dobro comendo, Ousada metade")
	assert(ousada.fight(0) == 4.0 and mansa.fight(0) == 1.0, "Ousada ganha o dobro lutando, Mansa metade")
	assert(mansa.hurt() == -4.0 and ousada.hurt() == -2.0, "Mansa perde o dobro quando leva dano")

	# Fome: 2 dias de carência, depois −4 por dia; Leal não perde
	var hungry := MountBond.create(dna, &"cria", 0)
	assert(hungry.tick_hunger(2) == 0.0 and not hungry.is_hungry(1) and hungry.is_hungry(2), "Dois dias sem comer: ainda sem perda, mas com fome")
	assert(hungry.tick_hunger(5) == -12.0 and hungry.elo == 28.0, "Dias 3, 4 e 5 sem comer: −12")
	hungry.feed(&"erva", 5)
	assert(hungry.tick_hunger(7) == 0.0, "Comeu: a carência recomeça")
	var leal := MountBond.create(_dna(CreatureDNA.Species.TROTADOR, 8, ["*", "I"]), &"cria", 0)
	assert(leal.tick_hunger(10) == 0.0 and leal.elo == 40.0, "Leal não perde Elo com fome")

	# Nome e save do Elo
	assert(not b.rename("   ") and b.rename("  Estrela-da-Manhã do Vale  ") and b.mount_name == "Estrela-da-Manhã", "Batiza com até 16 letras")
	var back := MountBond.from_dict(JSON.parse_string(JSON.stringify(b.to_dict())), dna)
	assert(back.elo == b.elo and back.mount_name == b.mount_name and back.temperament == &"equilibrada", "Elo e nome voltam do save")
	assert(back.feed(&"frutinha", 1) == 0.0 and back.care(1) == 0.0, "Os tetos do dia também voltam do save (sem farm por reload)")
	print("  ✓ Faixas, tetos diários, comida da espécie, índole, fome e nome")

func test_stable_and_companion(player: Player, eco: EcosystemSpawner) -> void:
	print("\n[3/6] Estábulo e Companheira única...")
	assert(eco.add_owned_mount(_dna(CreatureDNA.Species.TROTADOR, 11, ["I", "i"])), "Capturado no laço entra no estábulo")
	assert(eco.bonds.size() == 1 and eco.bonds[0].elo == 10.0, "Ganha Elo 10")
	var first: Mount = eco._owned_nodes[0]
	assert(first.bond == eco.bonds[0], "O nó da montaria tem o Elo")
	assert(not eco.set_companion(first), "Arisca não vira Companheira")
	first.bond.elo = 30.0
	assert(eco.set_companion(first) and eco.companion_mount() == first, "Mansa vira Companheira")
	assert(eco.add_owned_mount(_dna(CreatureDNA.Species.PLANADOR, 12, ["i", "i"]), MountBond.create(_dna(CreatureDNA.Species.PLANADOR, 12, ["i", "i"]), &"cria", 0)), "Cria entra com o Elo dado")
	var second: Mount = eco._owned_nodes[1]
	assert(eco.set_companion(second), "Troca de Companheira")
	assert(eco.companion_mount() == second and not first.bond.companion, "Só uma Companheira")
	assert(first.bond.elo == 24.0 and first.bond.band_name() == "Arisca", "A antiga fica com ciúme e volta a Arisca")
	print("  ✓ Só uma Companheira; a troca derruba o Elo da antiga")

func test_care_dialog(player: Player, eco: EcosystemSpawner) -> void:
	print("\n[4/6] Tela de cuidado...")
	var m: Mount = eco._owned_nodes[0]
	player.global_position = m.global_position + Vector3(1.0, 0, 0)
	m.talk_to(player)
	assert(eco._care_dialog.visible and eco._care_mount == m, "[E] na montaria própria abre a tela de cuidado")
	assert(m._channel_player == null, "Não começa a montar sozinha")
	var state := eco.care_state(m, player)
	assert(not state["feed"][1], "Sem comida da espécie na mochila: botão desligado")
	player.inventory.add_material(&"peixe_lambari", 2)
	assert(not eco.care_state(m, player)["feed"][1], "Peixe não é comida de Trotador")
	player.inventory.add_material(&"frutinha", 2)
	var before := m.bond.elo
	eco._on_care_choice(&"alimentar", "")
	assert(player.inventory.get_material_count(&"frutinha") == 1 and m.bond.elo == before + 3.0, "Alimentar gasta 1 frutinha e dá +3")
	assert(eco._care_dialog.visible, "A tela continua aberta depois de alimentar")
	eco._on_care_choice(&"batizar", "Pé-de-Vento")
	assert(m.display_name == "Pé-de-Vento" and m.bond.mount_name == "Pé-de-Vento", "Batizada")
	m.global_position = Vector3(EcosystemSpawner.STABLE_POS.x, 0, EcosystemSpawner.STABLE_POS.y + 3.0)
	assert(eco.care_state(m, player)["care"][1], "Perto do estábulo pode escovar")
	eco._on_care_choice(&"cuidar", "")
	assert(m.bond.elo == before + 5.0, "Escovar: +2")
	m.global_position = Vector3(60, 0, 60)
	assert(not eco.care_state(m, player)["care"][1], "Longe do estábulo não escova")
	player.global_position = m.global_position + Vector3(1.0, 0, 0)
	eco._on_care_choice(&"montar", "")
	assert(not eco._care_dialog.visible and m._channel_player == player, "Montar fecha a tela e começa os 1,5 s")
	m._channel_player = null
	var test_mount := Mount.new()
	test_mount.dna = CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 99)
	root.add_child(test_mount)
	test_mount.talk_to(player)
	assert(test_mount._channel_player == player, "Montaria de teste (sem Elo) monta direto no [E]")
	test_mount._channel_player = null
	test_mount.queue_free()
	print("  ✓ Alimentar, batizar, escovar no estábulo e montar pela tela")

func test_follow_order(player: Player, eco: EcosystemSpawner) -> void:
	print("\n[5/6] Ordem Seguir / Ficar...")
	var m: Mount = eco.companion_mount()
	m.global_position = Vector3(0, 0, 40)
	player.global_position = Vector3(20, 0, 40)
	m.bond.order = MountBond.Order.STAY
	for i in 30:
		m._physics_process(1.0 / 30.0)
	assert(m.global_position.distance_to(Vector3(0, 0, 40)) < 0.01, "Ficar: não sai do lugar")
	eco._care_mount = m
	eco._care_player = player
	eco._on_care_choice(&"ordem", "")
	assert(m.bond.order == MountBond.Order.FOLLOW, "A tela troca a ordem para Seguir")
	for i in 240:
		m._physics_process(1.0 / 30.0)
	var dist := Vector2(m.global_position.x, m.global_position.z).distance_to(Vector2(20, 40))
	assert(dist <= Mount.FOLLOW_DISTANCE + 0.5, "Seguir: chega perto do dono (%.1f m)" % dist)
	assert(m.global_position.distance_to(player.global_position) > 2.0, "E para antes de trombar nele")
	# Longe demais (além do alcance do apito) ela para e espera
	player.global_position = Vector3(20 + m.bond.whistle_range() + 30.0, 0, 40)
	var before := m.global_position
	for i in 30:
		m._physics_process(1.0 / 30.0)
	assert(m.global_position.distance_to(before) < 0.5, "Dono longe demais: espera onde está")
	m.bond.order = MountBond.Order.STAY
	eco._care_dialog.close()
	print("  ✓ Ficar segura; Seguir acompanha a pé e espera se o dono some")

func test_save(eco: EcosystemSpawner) -> void:
	print("\n[6/6] Save do Elo...")
	var state: Array = JSON.parse_string(JSON.stringify(eco.owned_state()))
	var elo0: float = eco.bonds[0].elo
	eco.restore_owned([])
	assert(eco.bonds.is_empty(), "Limpou")
	eco.restore_owned(state)
	assert(eco.bonds.size() == 2 and eco.bonds[0].elo == elo0 and eco.bonds[0].mount_name == "Pé-de-Vento", "Elo e nome voltam")
	assert(eco.companion_mount() == eco._owned_nodes[1] and eco._owned_nodes[0].display_name == "Pé-de-Vento", "Companheira e nome no rótulo voltam")
	# Save de antes do GDD-16 (só DNA): entra como capturada no laço
	var old: Dictionary = state[0].duplicate(true)
	old.erase("bond")
	eco.restore_owned([old])
	assert(eco.bonds.size() == 1 and eco.bonds[0].elo == 10.0 and not eco.bonds[0].companion, "Save antigo: Elo 10")
	print("  ✓ Elo, nome e Companheira no save; saves antigos continuam abrindo")
