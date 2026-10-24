extends SceneTree

## B20 / GDD-10 §9: Pinheira-Lume — genoma, cruzamento, pinhas, broto em 2 dias, pinha que brota,
## bicho que espalha a semente no esterco, plantio do jogador e save.

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🌲 TESTANDO A PINHEIRA-LUME (B20 / GDD-10 §9)")
	print("========================================================")
	test_genome()
	test_body_and_life()
	test_harvest_and_pinhas()
	test_animals_spread_seeds()
	test_planting()
	await test_save()
	await test_visible_growth()
	print("\n🎉 TODOS OS TESTES DA PINHEIRA-LUME PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_genome() -> void:
	print("\n[1/7] Genoma: código, descrição e cruzamento...")
	var a := PlantDNA.randomized(PlantDNA.Kind.PINHEIRA, 10)
	var code := a.genome_code()
	assert(code.begins_with("gen_"), "Código do genoma")
	var back := PlantDNA.from_genome_code(code)
	assert(back.genome_code() == code, "Código ida e volta (%s)" % code)
	assert(back.describe() == a.describe(), "Mesma descrição")
	assert(MaterialData.trait_name(StringName(code)).begins_with("Copa "), "Inventário mostra o genoma legível")
	assert(PlantDNA.from_dict(a.to_dict()).genome_code() == code, "Save do DNA guarda o genoma")
	# Dois pais bem diferentes: filhos misturam
	var mom := PlantDNA.from_genome_code("gen_TT-TT-BB-FF-00-5-21-4")
	var dad := PlantDNA.from_genome_code("gen_tt-HH-bb-ff-60-12-55-6")
	var kid := PlantDNA.cross(mom, dad, 7)
	assert(kid.porte.has("T") and kid.porte.has("t"), "Porte: um alelo de cada pai")
	assert(kid.copa_type() == PlantDNA.Copa.TACA, "Taça domina a chorona")
	assert(kid.glow_strength() == 0.65, "Bb dá brilho médio")
	assert(kid.is_fibonacci(), "F domina f: pinha Fibonacci")
	assert(mom.genome_code() == "gen_TT-TT-BB-FF-00-5-21-4", "Cruzar não muda a mãe")
	var hues := {}
	var forms := {}
	for s in 60:
		var k := PlantDNA.cross(PlantDNA.cross(mom, dad, s), PlantDNA.cross(mom, dad, s + 100), s + 200)
		hues[roundi(k.lume * 10.0)] = true
		forms[k.is_fibonacci()] = true
	assert(hues.size() >= 3 and forms.size() == 2, "Netos variam a cor (%d tons) e a pinha" % hues.size())
	# Mutação: cor nova e alelo * (espiral ou porte)
	var mutants := 0
	for s in 400:
		var m := PlantDNA.sprout(kid, s, 1.0)
		if m.mutant:
			mutants += 1
	assert(mutants == 400, "Mutação sempre marca * (copa espiral ou porte)")
	assert(not kid.mutant and not kid.copa.has("*"), "sprout não altera a semente original")
	print("  ✓ %s → %s" % [code, a.describe()])

func test_body_and_life() -> void:
	print("\n[2/7] Corpo procedural e ciclo (broto em 2 dias)...")
	for copa in ["TT", "CC", "HH", "*T"]:
		for forma in ["FF", "ff"]:
			var p := PlantBody.new()
			p.dna = PlantDNA.from_genome_code("gen_Tt-%s-Bb-%s-40-8-34-5" % [copa, forma])
			p.stage = PlantBody.Stage.FRUTO
			root.add_child(p)
			assert(p.get_child_count() >= 3, "Copa %s / pinha %s monta malha, brilho e luz" % [copa, forma])
			assert(p.find_child("Lume", false, false) is OmniLight3D, "Adulta acende uma luz")
			p.free()
	var seedling := PlantBody.new()
	seedling.dna = PlantDNA.randomized(PlantDNA.Kind.PINHEIRA, 3)
	seedling.stage = PlantBody.Stage.SEMENTE
	root.add_child(seedling)
	var good := {"moisture": 0.8, "nutrients": 0.8}
	var days := 0.0
	while seedling.stage == PlantBody.Stage.SEMENTE and days < 5.0:
		seedling.life_tick(0.05, good, true)
		days += 0.05
	assert(absf(days - 2.0) < 0.11, "Broto aparece depois de 2 dias (%.2f)" % days)
	assert(is_equal_approx(seedling.growth_scale(), PlantBody.PINHEIRA_GROWTH[PlantBody.Stage.BROTO][0]), "Broto sai pequeno")
	var seen := {}
	var seeds := 0
	for i in 600:
		var r := seedling.life_tick(0.05, good, true)
		seen[seedling.stage] = true
		if r.event == "seeds":
			seeds += 1
	assert(seen.size() >= 5 and seeds >= 1, "Cresce até dar pinhas")
	seedling.free()
	print("  ✓ 4 copas × 2 pinhas montam; broto em %.2f dias; safra" % days)

func _world() -> Ecology:
	var eco := Ecology.new()
	root.add_child(eco)
	return eco

func test_harvest_and_pinhas() -> void:
	print("\n[3/7] Safra com pólen, abrir pinha, sacudir e pinha que brota...")
	var eco := _world()
	var mom := PlantBody.new()
	mom.dna = PlantDNA.from_genome_code("gen_TT-TT-BB-FF-00-5-21-4")
	mom.stage = PlantBody.Stage.FRUTO
	mom.position = Vector3(-80, 0, 120)
	eco.add_child(mom)
	var dad := PlantBody.new()
	dad.dna = PlantDNA.from_genome_code("gen_tt-HH-bb-ff-60-12-55-6")
	dad.stage = PlantBody.Stage.ADULTA
	dad.position = Vector3(-80, 0, 135)
	eco.add_child(dad)
	assert(eco.pollen_father(mom) == dad.dna, "Pólen vem da vizinha a 15 m")
	eco.drop_pinhas(mom, 3)
	var pinhas: Array = get_nodes_in_group("pinhas")
	assert(pinhas.size() == 3, "Safra solta 3 pinhas")
	for f in pinhas:
		assert((f as PinhaFruit).dna.porte.has("t"), "Pinha leva genes do pai")
	# Jogador abre a pinha
	var player := Node3D.new()
	var inv := InventoryComponent.new()
	player.set("name", "Tester")
	player.set_meta("inv", inv)
	var holder := _Holder.new()
	holder.inventory = inv
	root.add_child(holder)
	holder.add_child(inv)
	var first := pinhas[0] as PinhaFruit
	var msg := first.harvest_next(holder)
	assert(inv.get_material_count(&"pinhao_lume") >= 3, "Abrir pinha dá 3–5 pinhões (%s)" % msg)
	assert(String(inv.get_stacks(&"pinhao_lume")[0].traits[0]).begins_with("gen_"), "Pinhão carrega o genoma no trait")
	# Sacudir a árvore com pinhas
	assert(mom.is_harvestable(), "Pinheira com pinhas pode ser sacudida")
	mom.harvest_next(holder)
	assert(mom.stage == PlantBody.Stage.ADULTA and not mom.is_harvestable(), "Sacudiu: volta a adulta")
	assert(get_nodes_in_group("pinhas").filter(func(n): return not n.is_collected).size() >= 4, "Sacudir derruba 2 pinhas")
	# Pinha esquecida brota
	var lone := eco.spawn_pinha(PlantDNA.randomized(PlantDNA.Kind.PINHEIRA, 9), Vector3(60, 0, 150))
	eco._count_plants()
	lone.age_days = PinhaFruit.GERMINATE_DAYS
	lone._process(0.0)
	var sprouted: Array = get_nodes_in_group("plants").filter(func(n): return n.stage == PlantBody.Stage.SEMENTE and n.dna.kind == PlantDNA.Kind.PINHEIRA)
	assert(sprouted.size() == 1, "Pinha esquecida vira pinhão plantado")
	holder.free()
	player.free()
	eco.free()
	_clear_groups()
	print("  ✓ Pólen da vizinha, pinhões com genoma, sacudir e pinha que brota")

class _Holder extends Node3D:
	var inventory: InventoryComponent
	var mastery: MasteryComponent

func test_animals_spread_seeds() -> void:
	print("\n[4/7] Bicho come a pinha e solta a semente no esterco...")
	var eco := _world()
	var spot := Vector3(70, 0, 160)
	var pinha := eco.spawn_pinha(PlantDNA.randomized(PlantDNA.Kind.PINHEIRA, 21), spot)
	var c := WildCreature.new()
	c.dna = CreatureDNA.randomized(CreatureDNA.Species.SALTARELO, 4)
	c.position = spot + Vector3(3, 0, 0)
	eco.add_child(c)
	assert(c._nearest_food(16.0) == pinha, "Saltarelo acha a pinha caída")
	c._consume(pinha)
	assert(c.gut.size() == 1, "Semente na barriga")
	c.global_position = spot + Vector3(-12, 0, 8)
	eco._count_plants()
	var sown := 0
	for k in 20:
		c.gut.append({"dna": PlantDNA.randomized(PlantDNA.Kind.PINHEIRA, 30 + k), "t": 0.0})
		# Cada uma numa célula livre, longe do rio
		var z := -150.0 + k * 7.0
		c.global_position = Vector3(RiverSystem.get_river_center_x(z) - 40.0, 0, z)
		c._digest(0.016)
	sown = get_nodes_in_group("pinheiras").size()
	assert(get_nodes_in_group("dung").size() >= 20, "Cada semente sai num montinho de esterco")
	assert(sown >= 8, "Quase sempre a semente brota no esterco (%d de 21)" % sown)
	var i := eco.cell_index(c.global_position.x, c.global_position.z)
	assert(eco.nutrients[i] > 0.1, "Esterco aduba a célula")
	# Ave come no pé
	var tree := PlantBody.new()
	tree.dna = PlantDNA.randomized(PlantDNA.Kind.PINHEIRA, 40)
	tree.stage = PlantBody.Stage.FRUTO
	tree.position = Vector3(-90, 0, 60)
	eco.add_child(tree)
	var bird := WildCreature.new()
	bird.dna = CreatureDNA.randomized(CreatureDNA.Species.PLANADOR, 5)
	bird.position = tree.position + Vector3(10, 20, 0)
	eco.add_child(bird)
	bird._forage_timer = 0.0
	for k in 400:
		bird._forage(0.05)
		if not bird.gut.is_empty():
			break
	assert(bird.gut.size() == 1 and tree.stage == PlantBody.Stage.ADULTA, "Planador come a pinha no pé")
	c.free()
	bird.free()
	eco.free()
	_clear_groups()
	print("  ✓ Saltarelo come, esterco aduba e semeia (%d brotos); Planador come no pé" % sown)

func test_planting() -> void:
	print("\n[5/7] Jogador planta: terra firme, vila só no canteiro...")
	var eco := _world()
	var holder := _Holder.new()
	holder.name = "Plantador"
	var inv := InventoryComponent.new()
	holder.inventory = inv
	holder.add_child(inv)
	root.add_child(holder)
	var dna := PlantDNA.randomized(PlantDNA.Kind.PINHEIRA, 50)
	var other := PlantDNA.randomized(PlantDNA.Kind.PINHEIRA, 51)
	inv.add_material(&"pinhao_lume", 2, 1, [StringName(dna.genome_code())])
	inv.add_material(&"pinhao_lume", 1, 1, [StringName(other.genome_code())])
	assert(inv.get_stacks(&"pinhao_lume").size() == 2, "Genomas diferentes não empilham")
	# Na vila sem canteiro: recusa
	holder.global_position = Vector3(1.5, 0, 4.5)
	var msg := eco.plant_by_player(holder)
	assert(msg.contains("Canteiro"), "Na vila só no canteiro (%s)" % msg)
	# Canteiro na vila
	var bed := BuildablePiece.new()
	bed.piece_type = BuildablePiece.PieceType.CANTEIRO
	root.add_child(bed)
	bed.global_position = Vector3(1.5, 0, 3.0)
	msg = eco.plant_by_player(holder)
	assert(msg.contains("plantado"), "No canteiro planta (%s)" % msg)
	var garden: Array = get_nodes_in_group("plants").filter(func(n): return n.garden)
	assert(garden.size() == 1 and garden[0].planted_by == "Plantador", "Planta do canteiro, com dono")
	msg = eco.plant_by_player(holder)
	assert(msg.contains("já tem"), "Uma planta por canteiro")
	# Escolhe o outro genoma e planta no campo
	holder.set_meta("seed_traits", [StringName(other.genome_code())] as Array[StringName])
	holder.global_position = Vector3(-70, 0, 140)
	msg = eco.plant_by_player(holder)
	assert(msg.contains("plantado"), "No campo planta (%s)" % msg)
	assert(inv.get_material_count(&"pinhao_lume") == 1, "Gastou 2 pinhões")
	assert(inv.get_stacks(&"pinhao_lume")[0].traits[0] == StringName(dna.genome_code()), "Plantou o genoma escolhido")
	bed.free()
	holder.free()
	eco.free()
	_clear_groups()
	print("  ✓ Vila recusa, canteiro aceita 1, campo aceita, genoma escolhido")

func test_save() -> void:
	print("\n[6/7] Save: pinhas no chão, canteiro e semente na barriga...")
	var eco := _world()
	var spawner := EcosystemSpawner.new()
	spawner.trees = 0
	spawner.bushes = 0
	spawner.cepas = 0
	spawner.mushrooms = 0
	root.add_child(spawner)
	var pinheiras: int = get_nodes_in_group("pinheiras").size()
	assert(pinheiras >= 4, "Vale nasce com bosques de Pinheira (%d)" % pinheiras)
	var p := eco.spawn_pinha(PlantDNA.randomized(PlantDNA.Kind.PINHEIRA, 60), Vector3(80, 0, 170), 0.7)
	var code := p.dna.genome_code()
	var c: WildCreature = get_nodes_in_group("wild_creatures")[0]
	c.gut.append({"dna": PlantDNA.randomized(PlantDNA.Kind.PINHEIRA, 61), "t": 0.3})
	var gut_code: String = c.gut[0].dna.genome_code()
	var state := spawner.nature_state()
	var json: Dictionary = JSON.parse_string(JSON.stringify(state))
	spawner.restore_nature(json)
	await process_frame
	var back: Array = get_nodes_in_group("pinhas").filter(func(n): return not n.is_queued_for_deletion())
	assert(back.size() == 1 and back[0].dna.genome_code() == code and absf(back[0].age_days - 0.7) < 0.02, "Pinha volta com genoma e idade")
	var guts: Array = get_nodes_in_group("wild_creatures").filter(func(n): return not n.gut.is_empty())
	assert(guts.size() == 1 and guts[0].gut[0].dna.genome_code() == gut_code, "Semente na barriga volta")
	assert(get_nodes_in_group("pinheiras").filter(func(n): return not n.is_queued_for_deletion()).size() == pinheiras, "Pinheiras voltam")
	spawner.free()
	eco.free()
	print("  ✓ %d Pinheiras, pinha e barriga sobrevivem ao save" % pinheiras)

func test_visible_growth() -> void:
	print("\n[7/7] Crescimento contínuo e troca de etapa suave...")
	var holder := Node3D.new()
	root.add_child(holder)
	var p := PlantBody.new()
	p.dna = PlantDNA.randomized(PlantDNA.Kind.PINHEIRA, 70)
	p.stage = PlantBody.Stage.JOVEM
	holder.add_child(p)
	assert(p.is_processing(), "Jovem cresce na tela")
	var good := {"moisture": 0.8, "nutrients": 0.8}
	var start := p.growth_scale()
	p.life_tick(1.5, good, true)
	var mid := p.growth_scale()
	assert(p.growth_scale() > start + 0.3, "Metade da etapa jovem: a árvore já cresceu (%.2f → %.2f)" % [start, mid])
	var before := p.scale.x
	await create_timer(0.5).timeout
	assert(p.scale.x > before and p.scale.x < p.growth_scale(), "Tamanho na tela persegue o progresso aos poucos")
	# Fim da etapa: vira adulta do mesmo tamanho, sem salto, e para de processar
	p.life_tick(1.6, good, true)
	assert(p.stage == PlantBody.Stage.ADULTA and not p.is_processing(), "Adulta não cresce mais")
	assert(p.find_child("Faiscas", false, false) is CPUParticles3D, "Troca de etapa solta faíscas do lume")
	# Broto → jovem muda de tamanho: a malha velha fica ao lado e encolhe até sumir
	var s := PlantBody.new()
	s.dna = PlantDNA.randomized(PlantDNA.Kind.PINHEIRA, 71)
	s.stage = PlantBody.Stage.BROTO
	s.progress = 0.99
	holder.add_child(s)
	s.life_tick(0.1, good, true)
	assert(s.stage == PlantBody.Stage.JOVEM, "Broto virou jovem")
	assert(holder.find_child("PlantaSaindo", false, false) != null, "Broto velho continua à vista na troca")
	assert(s.scale.x < 0.01, "Jovem começa do zero e cresce")
	await create_timer(PlantBody.STAGE_BLEND + 0.3).timeout
	assert(holder.find_child("PlantaSaindo", false, false) == null, "Broto velho sumiu")
	assert(absf(s.scale.x - s.growth_scale()) < 0.02, "Jovem chegou ao tamanho do progresso (%.3f)" % s.scale.x)
	holder.free()
	print("  ✓ Jovem cresce %.2f → %.2f; troca de etapa sem salto" % [start, mid])

func _clear_groups() -> void:
	for g in ["pinhas", "plants", "pinheiras", "dung", "fallen_fruit", "harvestable", "wild_creatures"]:
		for n in get_nodes_in_group(g):
			if is_instance_valid(n):
				n.remove_from_group(g)
