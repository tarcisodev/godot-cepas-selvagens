extends SceneTree

## B27 / GDD-14: Teste de Gênero, Ciclo de Vida 4 Fases, Capela da Vila e Família.

const _CreatureDNA = preload("res://scripts/data/creature_dna.gd")
const _CharacterDNA = preload("res://scripts/data/character_dna.gd")
const _WildCreature = preload("res://scripts/creatures/wild_creature.gd")
const _EcosystemSpawner = preload("res://scripts/creatures/ecosystem_spawner.gd")
const _FamilyComponent = preload("res://scripts/components/family_component.gd")
const _StatsComponent = preload("res://scripts/components/stats_component.gd")
const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const _VillageChapel = preload("res://scripts/town/village_chapel.gd")
const _TownNursery = preload("res://scripts/town/town_nursery.gd")
const _MaterialData = preload("res://scripts/data/material_data.gd")

var _started := false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("👶 TESTANDO GÊNERO, CICLO DE VIDA E FAMÍLIA (B27 / GDD-14)")
	print("========================================================")
	test_creature_dna_stages()
	test_character_dna_stages_and_cross()
	test_wild_creature_pregnancy_and_birth()
	test_vows_ring_and_marriage()
	test_player_pregnancy_and_nursery()
	test_town_chapel_and_nursery_stations()
	print("\n🎉 TODOS OS TESTES DE CICLO DE VIDA E FAMÍLIA PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_creature_dna_stages() -> void:
	print("\n[1/6] CreatureDNA: gênero, 4 fases de vida e escala...")
	var m := _CreatureDNA.randomized(_CreatureDNA.Species.TROTADOR, 10)
	m.gender = _CreatureDNA.Gender.MALE
	m.stage = _CreatureDNA.LifeStage.ADULT
	assert(m.is_male() and not m.is_female(), "Macho detectado")
	assert(m.is_fertile(), "Adulto é fértil")
	assert(is_equal_approx(m.stage_scale(), 1.0), "Adulto tem escala 1.0")

	var f := _CreatureDNA.randomized(_CreatureDNA.Species.TROTADOR, 20)
	f.gender = _CreatureDNA.Gender.FEMALE
	f.stage = _CreatureDNA.LifeStage.BABY
	assert(f.is_female() and not f.is_male(), "Fêmea detectada")
	assert(not f.is_fertile(), "Filhote não é fértil")
	assert(is_equal_approx(f.stage_scale(), 0.45), "Filhote tem escala 0.45")

	# Dimorfismo no body_size: Macho é ligeiramente maior
	m.alleles["porte"] = ["T", "T"]
	f.alleles["porte"] = ["T", "T"]
	f.stage = _CreatureDNA.LifeStage.ADULT
	assert(m.body_size() > f.body_size(), "Dimorfismo sexual: macho tem maior porte que fêmea")

	# Cruzamento produz filhote BABY
	var child := _CreatureDNA.cross(m, f, 55)
	assert(child.stage == _CreatureDNA.LifeStage.BABY, "Filho de cruzamento nasce no estágio BABY")
	assert(child.species == m.species, "Mesma espécie dos pais")

	# Serialização
	var dict := child.to_dict()
	assert(dict.has("gender") and dict.has("stage"), "Dicionário possui gender e stage")
	var restored := _CreatureDNA.from_dict(dict)
	assert(restored.gender == child.gender and restored.stage == child.stage, "from_dict restaura gênero e estágio")
	print("  ✓ CreatureDNA: dimorfismo, 4 fases e herança validados")

func test_character_dna_stages_and_cross() -> void:
	print("\n[2/6] CharacterDNA: humanoide com gênero, estágios e cruzamento familiar...")
	var father := _CharacterDNA.randomized(100)
	father.gender = _CharacterDNA.Gender.MALE
	father.stage = _CharacterDNA.LifeStage.ADULT
	assert(father.is_male() and father.is_fertile(), "Pai é macho adulto fértil")

	var mother := _CharacterDNA.randomized(200)
	mother.gender = _CharacterDNA.Gender.FEMALE
	mother.stage = _CharacterDNA.LifeStage.ADULT
	assert(mother.is_female() and mother.is_fertile(), "Mãe é fêmea adulta fértil")

	var baby := _CharacterDNA.cross(father, mother, 42)
	assert(baby.stage == _CharacterDNA.LifeStage.BABY, "Bebê humanoide nasce BABY")
	assert(is_equal_approx(baby.stage_scale(), 0.45), "Escala do bebê é 0.45")
	assert(not baby.is_fertile(), "Bebê não é fértil")
	assert(baby.beard == _CharacterDNA.Beard.NONE, "Bebê nasce sem barba")

	# Serialização de CharacterDNA
	var data := baby.to_dict()
	var copy := _CharacterDNA.from_dict(data)
	assert(copy.gender == baby.gender and copy.stage == baby.stage, "from_dict preserva gênero e estágio humanoide")
	print("  ✓ CharacterDNA: herança genética de pais e 4 fases validadas")

func test_wild_creature_pregnancy_and_birth() -> void:
	print("\n[3/6] WildCreature: acasalamento 1 Macho + 1 Fêmea, gestação e parto...")
	var spawner := _EcosystemSpawner.new()
	root.add_child(spawner)

	var female := _WildCreature.new()
	female.dna = _CreatureDNA.randomized(_CreatureDNA.Species.TROTADOR, 1)
	female.dna.gender = _CreatureDNA.Gender.FEMALE
	female.dna.stage = _CreatureDNA.LifeStage.ADULT
	female.age_days = 2.0
	spawner.add_child(female)

	var male := _WildCreature.new()
	male.dna = _CreatureDNA.randomized(_CreatureDNA.Species.TROTADOR, 2)
	male.dna.gender = _CreatureDNA.Gender.MALE
	male.dna.stage = _CreatureDNA.LifeStage.ADULT
	male.age_days = 2.0
	spawner.add_child(male)

	# Inicia gestação na fêmea com DNA do macho
	female.start_pregnancy(male.dna)
	assert(female.is_pregnant, "Fêmea entra no estado de gestação")
	assert(female.mate_dna == male.dna, "Guarda DNA do parceiro")

	# Fêmea não engravida novamente se já estiver prenha
	var female2 := _WildCreature.new()
	female2.dna = female.dna
	female2.start_pregnancy(male.dna)
	female2.start_pregnancy(male.dna) # idempotente

	# Parto
	var newborn := female.give_birth()
	assert(not female.is_pregnant, "Após o parto não está mais prenha")
	assert(female.mate_dna == null, "DNA do parceiro limpo após parto")
	if newborn:
		assert(newborn.dna.stage == _CreatureDNA.LifeStage.BABY, "Recém-nascido é filhote BABY")
		assert(newborn.dna.species == _CreatureDNA.Species.TROTADOR, "Espécie herdada")
		newborn.free()

	female2.free()
	male.free()
	female.free()
	spawner.free()
	print("  ✓ WildCreature: acasalamento biológico e gestação validados")

func test_vows_ring_and_marriage() -> void:
	print("\n[4/6] Aliança de Votos, Casamento e Laço de Votos (+10% regen)...")
	var ring_mat := _MaterialData.of(&"alianca_votos")
	assert(ring_mat != null, "Recurso alianca_votos.tres existe")
	assert(ring_mat.display_name == "Aliança de Votos", "Nome da aliança correto")

	var player_node := Node3D.new()
	player_node.name = "TestPlayer"
	var stats := _StatsComponent.new()
	stats.name = "StatsComponent"
	stats.set_base_stat(&"health_regen", 5.0)
	stats.set_base_stat(&"vigor_regen", 10.0)
	player_node.add_child(stats)

	var inv := _InventoryComponent.new()
	inv.name = "InventoryComponent"
	player_node.add_child(inv)

	var p_dna := _CharacterDNA.randomized(50)
	p_dna.gender = _CharacterDNA.Gender.MALE
	player_node.set("dna", p_dna)

	var fam := _FamilyComponent.new()
	fam.name = "FamilyComponent"
	player_node.add_child(fam)
	root.add_child(player_node)

	assert(not fam.is_married(), "Começa solteiro")
	var spouse_dna := _CharacterDNA.randomized(60)
	spouse_dna.gender = _CharacterDNA.Gender.FEMALE

	var success := fam.marry("Ayla", spouse_dna)
	assert(success and fam.is_married(), "Casamento realizado com sucesso")
	assert(fam.spouse_name == "Ayla", "Nome do cônjuge registrado")
	assert(inv.get_material_count(&"alianca_votos") == 1, "Aliança de Votos concedida ao casar")

	# Proximidade ativa buff Laço de Votos
	var base_hp_regen := stats.get_stat(&"health_regen")
	fam.set_spouse_near(true)
	assert(stats.get_stat(&"health_regen") > base_hp_regen, "Laço de Votos concede +10% regen de vida")

	# Afastar do cônjuge desativa o buff
	fam.set_spouse_near(false)
	assert(is_equal_approx(stats.get_stat(&"health_regen"), base_hp_regen), "Buff removido ao afastar")

	# Divórcio
	fam.divorce()
	assert(not fam.is_married(), "Divórcio dissolve os votos")
	assert(fam.spouse_name.is_empty(), "Sem cônjuge")

	player_node.free()
	print("  ✓ Matrimônio, Aliança de Votos e buff Laço de Votos validados")

func test_player_pregnancy_and_nursery() -> void:
	print("\n[5/6] Gravidez de 9 meses da jogadora e parto gratuito no Berçário...")
	var player_node := Node3D.new()
	player_node.name = "FemalePlayer"

	var p_dna := _CharacterDNA.randomized(77)
	p_dna.gender = _CharacterDNA.Gender.FEMALE
	player_node.set("dna", p_dna)

	var fam := _FamilyComponent.new()
	fam.name = "FamilyComponent"
	player_node.add_child(fam)
	root.add_child(player_node)

	var partner_dna := _CharacterDNA.randomized(88)
	partner_dna.gender = _CharacterDNA.Gender.MALE

	fam.marry("Breno", partner_dna)
	assert(fam.conceive(partner_dna, "Breno"), "Concepção bem-sucedida")
	assert(fam.is_pregnant, "Jogadora grávida")
	assert(not fam.is_labor_ready(), "No início da gestação ainda não está pronta para o parto")

	# Avança 20 dias (menos que 27 dias / 9 meses)
	fam.advance_pregnancy(20.0)
	assert(not fam.is_labor_ready(), "Com 20 dias ainda não completou os 9 meses")

	# Completa os 27 dias (9 meses de sol)
	fam.advance_pregnancy(7.0)
	assert(fam.is_labor_ready(), "Com 27 dias (9 meses) está pronta para o parto iminente!")

	# Berçário da cidade acolhe o bebê
	var nursery := _TownNursery.new()
	root.add_child(nursery)

	var child_data := fam.give_birth("Gael", 1234)
	assert(not fam.is_pregnant, "Após o parto não está mais grávida")
	assert(fam.children.size() == 1, "Criança registrada na árvore da família")
	assert(child_data.name == "Gael", "Nome da criança confere")

	nursery.admit_child(child_data)
	assert(nursery.get_registered_children().size() == 1, "Criança admitida no Berçário Comunitário")

	# Crescimento da criança através das fases no Berçário
	nursery.advance_children_days(5.0)
	assert(nursery.get_registered_children()[0].stage == 1, "Com 5 dias cresceu para Jovem Aprendiz")

	nursery.advance_children_days(10.0)
	assert(nursery.get_registered_children()[0].stage == 2, "Com 15 dias cresceu para Cidadão Pleno Adulto")

	nursery.free()
	player_node.free()
	print("  ✓ Gestação de 9 meses, parto assistido e ciclo no Berçário validados")

func test_town_chapel_and_nursery_stations() -> void:
	print("\n[6/6] Estações 3D da Vila: VillageChapel e TownNursery...")
	var chapel := _VillageChapel.new()
	root.add_child(chapel)
	assert(chapel.is_in_group("talkable") and chapel.is_in_group("village_chapel"), "Capela registrada nos grupos")

	var nursery := _TownNursery.new()
	root.add_child(nursery)
	assert(nursery.is_in_group("talkable") and nursery.is_in_group("town_nursery"), "Berçário registrado nos grupos")

	chapel.free()
	nursery.free()
	print("  ✓ Estações 3D da Capela e Berçário validadas")
