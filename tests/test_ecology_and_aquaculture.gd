extends SceneTree

## B29 / GDD-04, GDD-08 §5, GDD-10 §9:
## Teste da Composteira de Monstros, Tanque de Aquicultura & Conhecimento Ecológico.

const _BuildablePiece = preload("res://scripts/buildable_piece.gd")
const _PlantBody = preload("res://scripts/systems/plant_body.gd")
const _PlantDNA = preload("res://scripts/data/plant_dna.gd")
const _Ecology = preload("res://scripts/ecology/ecology.gd")
const _EcologyKnowledgeComponent = preload("res://scripts/components/ecology_knowledge_component.gd")
const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const _PhotoModeScreen = preload("res://scripts/ui/photo_mode_screen.gd")
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
	print("🌱 TESTANDO COMPOSTEIRA, AQUICULTURA & CONHECIMENTO ECOLÓGICO (B29)")
	print("========================================================")
	test_composter_and_fertilizer()
	test_aquaculture_tank_and_oil()
	test_plant_fertilization_and_growth()
	test_ecology_knowledge_progression()
	test_photo_mode_ecology_scanner()
	print("\n🎉 TODOS OS TESTES DE ECOLOGIA, COMPOSTEIRA E AQUICULTURA PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_composter_and_fertilizer() -> void:
	print("\n[1/5] Composteira de Monstros & Produção de Adubo...")
	
	# Validação de custos e metadados no PIECE_CONFIG
	var cfg: Dictionary = _BuildablePiece.PIECE_CONFIG[_BuildablePiece.PieceType.COMPOSTEIRA]
	assert(cfg["id"] == &"composteira", "ID da Composteira correto")
	assert(cfg["costs"].get(&"ossos", 0) == 2, "Custa 2x ossos")
	assert(cfg["costs"].get(&"madeira", 0) == 4, "Custa 4x madeira")

	var composter := _BuildablePiece.new()
	composter.piece_type = _BuildablePiece.PieceType.COMPOSTEIRA
	root.add_child(composter)

	var player := Node3D.new()
	var inv := _InventoryComponent.new()
	inv.name = "InventoryComponent"
	player.add_child(inv)
	root.add_child(player)

	# 1. Tentar compostar sem ingredientes deve falhar
	var ok_fail := composter.compost(player)
	assert(not ok_fail, "Compostagem sem ingredientes falha")
	assert(inv.get_material_count(&"adubo_organico") == 0, "Nenhum adubo gerado")

	# 2. Compostar com ossos
	inv.add_material(&"ossos", 2)
	assert(inv.get_material_count(&"ossos") == 2, "Possui 2 ossos")
	var ok_bones := composter.compost(player)
	assert(ok_bones, "Compostagem com ossos bem-sucedida")
	assert(inv.get_material_count(&"ossos") == 0, "Ossos foram consumidos")
	assert(inv.get_material_count(&"adubo_organico") == 1, "1x Adubo de Monstro gerado")
	
	var stacks := inv.get_stacks(&"adubo_organico")
	assert(not stacks.is_empty(), "Pilha de adubo criada")
	assert(stacks[0].get("quality", 1) == 3, "Adubo produzido com qualidade 3")
	assert(stacks[0].get("traits", []).has(&"mineralizado"), "Adubo possui trait mineralizado")

	# 3. Compostar com folhas
	inv.add_material(&"folha", 4)
	var ok_leaves := composter.compost(player, &"folha")
	assert(ok_leaves, "Compostagem com folhas específica bem-sucedida")
	assert(inv.get_material_count(&"folha") == 0, "Folhas consumidas")
	assert(inv.get_material_count(&"adubo_organico") == 2, "Total de 2x Adubo no inventário")

	player.queue_free()
	composter.queue_free()

func test_aquaculture_tank_and_oil() -> void:
	print("\n[2/5] Tanque de Aquicultura & Extração de Óleo Purificado...")

	var cfg: Dictionary = _BuildablePiece.PIECE_CONFIG[_BuildablePiece.PieceType.TANQUE_PEIXE]
	assert(cfg["id"] == &"tanque_peixe", "ID do Tanque correto")
	assert(cfg["costs"].get(&"quartzo_lume", 0) == 2, "Custa 2x quartzo_lume")

	var tank := _BuildablePiece.new()
	tank.piece_type = _BuildablePiece.PieceType.TANQUE_PEIXE
	root.add_child(tank)

	var player := Node3D.new()
	var inv := _InventoryComponent.new()
	inv.name = "InventoryComponent"
	player.add_child(inv)
	root.add_child(player)

	# 1. Sem peixe falha
	assert(not tank.process_fish(player), "Sem peixe falha processamento")

	# 2. Com Peixe Lambari normal (qualidade 1)
	inv.add_material(&"peixe_lambari", 1, 1)
	var ok_fish := tank.process_fish(player)
	assert(ok_fish, "Processou peixe lambari")
	assert(inv.get_material_count(&"peixe_lambari") == 0, "Consumiu lambari")
	assert(inv.get_material_count(&"oleo_peixe") == 1, "1x Óleo de Peixe Purificado extraído")

	var oil_stacks := inv.get_stacks(&"oleo_peixe")
	assert(oil_stacks[0].get("traits", []).has(&"purificado"), "Óleo possui trait purificado")

	# 3. Com Peixe Dourado lendário (rende dobro de óleo)
	inv.add_material(&"peixe_dourado", 1, 1)
	var ok_gold := tank.process_fish(player)
	assert(ok_gold, "Processou peixe dourado")
	assert(inv.get_material_count(&"peixe_dourado") == 0, "Consumiu dourado")
	assert(inv.get_material_count(&"oleo_peixe") == 3, "Rendeu +2x óleo pelo dourado (total 3)")

	player.queue_free()
	tank.queue_free()

func test_plant_fertilization_and_growth() -> void:
	print("\n[3/5] Adubação em Plantas & Aceleração de Crescimento...")

	var plant_dna := _PlantDNA.randomized(_PlantDNA.Kind.PINHEIRA, 42)
	var plant := _PlantBody.new()
	plant.dna = plant_dna
	plant.stage = _PlantBody.Stage.BROTO
	root.add_child(plant)

	assert(not plant.is_fertilized, "Planta começa sem adubação")

	# Adubar diretamente
	var ok_fert := plant.fertilize()
	assert(ok_fert, "Adubação realizada com sucesso")
	assert(plant.is_fertilized, "Planta agora está adubada")
	assert(not plant.fertilize(), "Segunda adubação recusada pois já está adubada")

	# Teste de velocidade do life_tick (+50% progresso com adubo)
	var unfertilized := _PlantBody.new()
	unfertilized.dna = plant_dna
	unfertilized.stage = _PlantBody.Stage.BROTO
	root.add_child(unfertilized)

	var cell := {"moisture": 0.8, "nutrients": 0.8}
	var days := 0.2

	var r_unf := unfertilized.life_tick(days, cell, true)
	var r_fert := plant.life_tick(days, cell, true)

	assert(plant.progress > unfertilized.progress, "Planta adubada avança mais rápido que a comum")
	var ratio: float = plant.progress / maxf(unfertilized.progress, 0.0001)
	assert(is_equal_approx(ratio, 1.5), "Taxa de crescimento é exatamente +50% (1.5x)")

	# Teste de fertilização via Ecology.fertilize_plant
	var eco := _Ecology.new()
	root.add_child(eco)

	var target_plant := _PlantBody.new()
	target_plant.dna = plant_dna
	root.add_child(target_plant)

	var p_mock := Node3D.new()
	var inv := _InventoryComponent.new()
	inv.name = "InventoryComponent"
	p_mock.add_child(inv)
	root.add_child(p_mock)

	var msg_no_item := eco.fertilize_plant(target_plant, p_mock)
	assert(msg_no_item.contains("Falta 1x Adubo"), "Avisa que falta adubo no inventário")

	inv.add_material(&"adubo_organico", 1)
	var msg_ok := eco.fertilize_plant(target_plant, p_mock)
	assert(msg_ok.contains("sucesso"), "Adubação via Ecology executada")
	assert(target_plant.is_fertilized, "Planta alvo adubada com sucesso")
	assert(inv.get_material_count(&"adubo_organico") == 0, "1x Adubo consumido do jogador")

	plant.queue_free()
	unfertilized.queue_free()
	target_plant.queue_free()
	p_mock.queue_free()
	eco.queue_free()

func test_ecology_knowledge_progression() -> void:
	print("\n[4/5] EcologyKnowledgeComponent: 3 Tiers de Pesquisa e Normalização...")

	var eco := _EcologyKnowledgeComponent.new()
	root.add_child(eco)

	# 1. Espécie desconhecida (0 pts -> Level 0)
	assert(eco.get_points(&"trotador") == 0, "Inicia com 0 pontos")
	assert(eco.get_level(&"trotador") == 0, "Inicia no Nível 0")
	assert(not eco.has_unlocked_weaknesses(&"trotador"), "Fraquezas bloqueadas")
	assert(not eco.has_unlocked_anatomy_hud(&"trotador"), "HUD anatômico bloqueado")
	assert(not eco.has_unlocked_genetics(&"trotador"), "Genética bloqueada")

	# 2. Adicionar 25 pts -> Nível 1 (Análise Fisiológica)
	var pts := eco.add_research(&"trotador", 25)
	assert(pts == 25, "Pontos acumulados: 25")
	assert(eco.get_level(&"trotador") == 1, "Alcançou Nível 1")
	assert(eco.has_unlocked_weaknesses(&"trotador"), "Nível 1 desbloqueia fraquezas")
	assert(not eco.has_unlocked_anatomy_hud(&"trotador"), "Nível 2 ainda bloqueado")

	var weak: Array = eco.get_species_weaknesses(&"trotador")
	assert(weak.has("Corte") and weak.has("Fogo"), "Fraquezas de Trotador corretas")

	var parts: Array = eco.get_species_parts(&"trotador")
	assert(parts.has("Chifre"), "Partes anatômicas de Trotador presentes")

	# 3. Adicionar mais 35 pts (total 60) -> Nível 2 (Diagnóstico em Tempo Real)
	eco.add_research(&"trotador", 35)
	assert(eco.get_level(&"trotador") == 2, "Alcançou Nível 2")
	assert(eco.has_unlocked_anatomy_hud(&"trotador"), "Nível 2 desbloqueia HUD anatômico")
	assert(not eco.has_unlocked_genetics(&"trotador"), "Nível 3 ainda bloqueado")

	# 4. Adicionar mais 60 pts (total 120) -> Nível 3 (Genética de Campo)
	eco.add_research(&"trotador", 60)
	assert(eco.get_level(&"trotador") == 3, "Alcançou Nível 3")
	assert(eco.has_unlocked_genetics(&"trotador"), "Nível 3 desbloqueia Genética de Campo")

	# 5. Normalização de nomes
	eco.add_research("Lobo-do-Ermo", 30)
	assert(eco.get_level(&"lobo") == 1, "Normalizou Lobo-do-Ermo para &lobo")

	# 6. Serialização to_dict e from_dict
	var saved: Dictionary = eco.to_dict()
	assert(saved.has("trotador") and saved["trotador"] >= 120, "Salvou pontuação do trotador")

	var eco_restore := _EcologyKnowledgeComponent.new()
	eco_restore.from_dict(saved)
	assert(eco_restore.get_level(&"trotador") == 3, "Restaurou Nível 3 com sucesso")

	eco.queue_free()
	eco_restore.queue_free()

func test_photo_mode_ecology_scanner() -> void:
	print("\n[5/5] Modo Foto: scanner de fraquezas, alelos genéticos e recompensa de XP...")

	var photo := _PhotoModeScreen.new()
	root.add_child(photo)

	var p_mock := Node3D.new()
	var eco := _EcologyKnowledgeComponent.new()
	eco.name = "EcologyKnowledgeComponent"
	p_mock.add_child(eco)
	root.add_child(p_mock)
	photo.player = p_mock

	# Simular foco em espécime com Level 3
	eco.add_research(&"trotador", 125)
	assert(eco.has_unlocked_genetics(&"trotador"), "Genética desbloqueada para teste")

	# Bicho com DNA
	var beast := _WildCreature.new()
	beast.dna = _CreatureDNA.randomized(_CreatureDNA.Species.TROTADOR, 999)
	root.add_child(beast)

	# Simular registro fotográfico
	photo.set("_current_target", beast)
	photo.set("_current_species", "trotador")
	photo.set("_current_name", "Trotador (Macho, Adulto)")

	var old_pts: int = eco.get_points(&"trotador")
	photo.take_photo()
	var new_pts: int = eco.get_points(&"trotador")
	assert(new_pts == old_pts + 15, "Fotografar adiciona +15 pontos de pesquisa")

	beast.queue_free()
	photo.queue_free()
	p_mock.queue_free()
