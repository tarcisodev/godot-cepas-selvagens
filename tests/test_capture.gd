extends SceneTree

## B14 / GDD-03 §9: caça e captura dos bichos procedurais e montaria própria.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("➰ TESTANDO CAPTURA E MONTARIA PRÓPRIA (B14)")
	print("========================================================")
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	player.set_physics_process(false) # sem chão no teste
	var eco := EcosystemSpawner.new()
	for prop in ["trotador_herds", "saltarelos", "planadores", "raias", "lambari_schools", "trees", "bushes", "cepas", "mushrooms"]:
		eco.set(prop, 0)
	root.add_child(eco)

	test_crafting(player)
	await test_capture_flow(player, eco)
	await test_careful_slaughter(player, eco)
	test_stable_limit_and_save(player, eco)
	print("\n🎉 TODOS OS TESTES DE CAPTURA PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _creature(eco: EcosystemSpawner, player: Player, seed: int) -> WildCreature:
	var c := eco._add_wild(CreatureDNA.Species.TROTADOR, Vector3(0, 0, 0), 4.0)
	c.dna.alleles["chifre"] = ["C", "C"]
	player.global_position = c.global_position + Vector3(1.5, 0, 0)
	return c

func test_crafting(player: Player) -> void:
	print("\n[1/4] Ofícios: Laço de Fibra e Sedativo de Erva...")
	var inv := player.inventory
	assert(not inv.craft(&"laco_fibra"), "Sem material não faz laço")
	inv.add_material(&"fibra", 8)
	inv.add_material(&"galho", 4)
	inv.add_material(&"erva", 6)
	inv.add_material(&"mel", 2)
	assert(inv.craft(&"laco_fibra") and inv.craft(&"laco_fibra"), "Faz dois laços")
	assert(inv.craft(&"sedativo_erva") and inv.craft(&"sedativo_erva"), "Faz dois sedativos")
	assert(inv.get_material_count(&"fibra") == 0 and inv.get_material_count(&"mel") == 0, "Gastou a receita")
	assert(MaterialData.of(&"laco_fibra").is_tool() and MaterialData.of(&"sedativo_erva").is_tool(), "São ferramentas")
	print("  ✓ Receitas gastam e entregam as ferramentas")

func test_capture_flow(player: Player, eco: EcosystemSpawner) -> void:
	print("\n[2/4] Cansar → laço → sedativo → estábulo...")
	var c := _creature(eco, player, 1)
	var inv := player.inventory
	assert(WildCreature.use_tool(player, &"laco_fibra") and inv.get_material_count(&"laco_fibra") == 1, "Laço em bicho descansado arrebenta (gasta o laço)")
	assert(c.state != WildCreature.State.TRAPPED, "Não prendeu descansado")
	assert(c.state == WildCreature.State.WANDER, "Ainda passeando")

	var max_hp: float = c.stats.get_stat(&"max_health")
	c.pools.take_damage(max_hp * 0.5)
	assert(c.state == WildCreature.State.FLEE, "Apanhou: foge")
	c.pools.take_damage(max_hp * 0.35)
	assert(c.state == WildCreature.State.EXHAUSTED, "Abaixo de 20%: Exausto")
	player.global_position = c.global_position + Vector3(1.0, 0, 0)
	assert(not WildCreature.use_tool(player, &"sedativo_erva"), "Sedativo sem laço não serve (não gasta)")
	assert(WildCreature.use_tool(player, &"laco_fibra") and c.state == WildCreature.State.TRAPPED, "Laço prende o exausto")

	assert(WildCreature.use_tool(player, &"sedativo_erva") and c.state == WildCreature.State.SEDATING, "Sedativo começa a sedação")
	player.pools.current_health -= 3.0
	await process_frame
	await process_frame
	assert(c.state == WildCreature.State.TRAPPED, "Dano cancela a sedação (volta a preso)")
	assert(WildCreature.use_tool(player, &"sedativo_erva"), "Segundo sedativo")
	await create_timer(WildCreature.SEDATE_TIME + 0.3).timeout
	assert(c.state == WildCreature.State.CAPTURED, "3 s parado: capturado")
	assert(eco._dialog.visible, "Abre a escolha pós-captura")
	var dna := c.dna
	eco._dialog._choose(&"estabulo")
	await process_frame
	assert(eco.owned.size() == 1 and eco.owned[0] == dna, "Foi para o estábulo")
	var mount: Mount = eco._owned_nodes[0]
	assert(mount.owned and mount.body.dna == dna, "Vira montaria própria com o DNA do bicho")
	dna.alleles["porte"] = ["t", "t"]
	assert(is_equal_approx(dna.mount_speed_factor(), 0.85), "tt corre 85%")
	print("  ✓ Laço arrebenta em bicho descansado, Exausto, preso, dano cancela, capturado e montaria")

func test_careful_slaughter(player: Player, eco: EcosystemSpawner) -> void:
	print("\n[3/4] Abate cuidadoso e esfola Íntegra...")
	var c := _creature(eco, player, 2)
	c.pools.take_damage(c.stats.get_stat(&"max_health") * 0.85)
	player.inventory.add_material(&"laco_fibra", 1)
	player.inventory.add_material(&"sedativo_erva", 1)
	player.global_position = c.global_position + Vector3(1.0, 0, 0)
	WildCreature.use_tool(player, &"laco_fibra")
	WildCreature.use_tool(player, &"sedativo_erva")
	await create_timer(WildCreature.SEDATE_TIME + 0.3).timeout
	eco._dialog._choose(&"abate")
	assert(c.state == WildCreature.State.DEAD and c.is_harvestable(), "Corpo para esfolar")
	var parts := 0
	while c.is_harvestable():
		c.harvest_next(player)
		parts += 1
	assert(parts == 3, "Trotador com chifre: chifre, couro e carne (saiu %d)" % parts)
	var horn := player.inventory.best_stack(&"chifre_galhado")
	assert(horn.quality == 3 and horn.traits.has(&"integro"), "Partes saem Íntegras (3★)")
	# Morte comum: partes 2★ sem Íntegro
	var c2 := _creature(eco, player, 3)
	c2.pools.take_damage(9999.0)
	assert(c2.state == WildCreature.State.DEAD, "Morreu")
	c2.harvest_next(player)
	var plain := player.inventory.get_stacks(&"chifre_galhado").filter(func(s): return not s.traits.has(&"integro"))
	assert(not plain.is_empty() and plain[0].quality == 2, "Morte comum: 2★ sem Íntegro")
	print("  ✓ Abate cuidadoso dá 3★ Íntegro; morte comum dá 2★")

func test_stable_limit_and_save(player: Player, eco: EcosystemSpawner) -> void:
	print("\n[4/4] Estábulo até 3 e save das montarias...")
	assert(eco.add_owned_mount(CreatureDNA.randomized(CreatureDNA.Species.PLANADOR, 5)), "Segunda montaria (Planador)")
	assert(eco.add_owned_mount(CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 6)), "Terceira")
	assert(not eco.add_owned_mount(CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 7)), "Quarta não cabe (máx. 3)")
	assert(not eco.add_owned_mount(CreatureDNA.randomized(CreatureDNA.Species.SALTARELO, 8)), "Saltarelo não é montaria")
	var state: Array = JSON.parse_string(JSON.stringify(eco.owned_state()))
	var first_alleles: Dictionary = eco.owned[1].alleles.duplicate(true)
	eco.restore_owned([])
	assert(eco.owned.is_empty(), "Limpou")
	eco.restore_owned(state)
	assert(eco.owned.size() == 3 and eco.owned[1].species == CreatureDNA.Species.PLANADOR, "3 montarias voltam do save")
	assert(eco.owned[1].alleles == first_alleles, "Genes voltam iguais")
	print("  ✓ Limite de 3, só Trotador/Planador, ida e volta do save")
