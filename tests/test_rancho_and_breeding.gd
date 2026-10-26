extends SceneTree

## B31 / GDD-04 §2, GDD-08 §4-§5, GDD-09 §5:
## Teste do Rancho dos Jogadores, Cercado de Reprodução (Breeding Pen) e Genética de Criadouro.

const _BuildablePiece = preload("res://scripts/buildable_piece.gd")
const _BreedingPen = preload("res://scripts/systems/breeding_pen.gd")
const _BreedingPenScreen = preload("res://scripts/ui/breeding_pen_screen.gd")
const _CreatureDNA = preload("res://scripts/data/creature_dna.gd")
const _Player = preload("res://scripts/player.gd")
const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const _MasteryComponent = preload("res://scripts/components/mastery_component.gd")
const _CaptureDialog = preload("res://scripts/ui/capture_dialog.gd")

var _started := false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🏡 TESTANDO RANCHO, CERCADO DE REPRODUÇÃO & GENÉTICA (B31)")
	print("========================================================")
	test_piece_config_and_building()
	test_breeder_allocation_and_compatibility()
	test_cocho_feeding_and_mutation_boost()
	test_punnett_square_probabilities()
	test_gestation_and_pausing()
	test_careful_slaughter_harvest()
	test_offspring_promotion_to_breeder_and_mount()
	test_serialization_and_persistence()
	test_player_livestock_and_capture_dialog()
	print("\n🎉 TODOS OS TESTES DO RANCHO E BREEDING PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_piece_config_and_building() -> void:
	print("\n[1/9] Configuração e Construção da Peça Cercado de Reprodução...")

	assert(_BuildablePiece.PieceType.has("CERCADO_BREEDING"), "PieceType contém CERCADO_BREEDING")
	var cfg: Dictionary = _BuildablePiece.PIECE_CONFIG.get(_BuildablePiece.PieceType.CERCADO_BREEDING, {})
	assert(not cfg.is_empty(), "PIECE_CONFIG possui entrada para CERCADO_BREEDING")
	assert(cfg.id == &"cercado_breeding", "ID da peça é cercado_breeding")
	assert(cfg.size == Vector3(4.0, 1.4, 4.0), "Tamanho do cercado é 4x1.4x4m")
	assert(cfg.costs.has(&"madeira") and cfg.costs.has(&"galho"), "Custo inclui madeira e galhos")

	var piece := _BuildablePiece.new()
	piece.piece_type = _BuildablePiece.PieceType.CERCADO_BREEDING
	root.add_child(piece)

	assert(piece.is_in_group("built_structures"), "Peça está no grupo built_structures")
	assert(piece.is_in_group("breeding_pens"), "Peça está no grupo breeding_pens")
	assert(piece.is_in_group("talkable"), "Peça está no grupo talkable para interação")
	assert(piece.pen != null, "BreedingPen foi instanciado dentro da peça")
	assert(piece.pen is _BreedingPen, "Componente é do tipo BreedingPen")

	piece.queue_free()

func test_breeder_allocation_and_compatibility() -> void:
	print("\n[2/9] Alocação de Reprodutores e Validação Biológica...")

	var pen := _BreedingPen.new()
	root.add_child(pen)

	# 1. Macho fértil Trotador
	var sire := _CreatureDNA.randomized(_CreatureDNA.Species.TROTADOR, 42)
	sire.gender = _CreatureDNA.Gender.MALE
	sire.stage = _CreatureDNA.LifeStage.ADULT

	# 2. Fêmea fértil Trotador
	var dam := _CreatureDNA.randomized(_CreatureDNA.Species.TROTADOR, 99)
	dam.gender = _CreatureDNA.Gender.FEMALE
	dam.stage = _CreatureDNA.LifeStage.ADULT

	# Fêmea não pode ser sire
	assert(not pen.can_set_sire(dam), "Fêmea não pode ser alocada como Reprodutor (Macho)")
	# Macho não pode ser dam
	assert(not pen.can_set_dam(sire), "Macho não pode ser alocado como Matriz (Fêmea)")

	# Boss colossal não pode ser domesticado
	var colosso := _CreatureDNA.randomized(_CreatureDNA.Species.RINOLITO, 123)
	colosso.gender = _CreatureDNA.Gender.MALE
	assert(not pen.can_set_sire(colosso), "Colosso colossal Rinolito não é domesticável no Rancho")

	# Espécie diferente
	var planador := _CreatureDNA.randomized(_CreatureDNA.Species.PLANADOR, 77)
	planador.gender = _CreatureDNA.Gender.FEMALE

	# Aloca sire
	var ok_sire := pen.set_sire(sire)
	assert(ok_sire, "Reprodutor macho alocado com sucesso")
	assert(pen.sire == sire, "Sire registrado no cercado")

	# Tentativa de alocar dam de espécie diferente falha
	assert(not pen.can_set_dam(planador), "Matriz de espécie diferente deve ser rejeitada")

	# Aloca dam compatível
	var ok_dam := pen.set_dam(dam)
	assert(ok_dam, "Matriz fêmea compatível alocada com sucesso")
	assert(pen.dam == dam, "Dam registrada no cercado")

	pen.queue_free()

func test_cocho_feeding_and_mutation_boost() -> void:
	print("\n[3/9] Alimentação no Cocho e Impulso de Mutação por Adubo...")

	var pen := _BreedingPen.new()
	root.add_child(pen)

	var player := Node.new()
	var inv := _InventoryComponent.new()
	player.add_child(inv)
	root.add_child(player)

	# Tenta alimentar sem materiais
	assert(not pen.feed(player), "Alimentar sem materiais falha")
	assert(pen.feed_level == 0.0, "Cocho permanece vazio")

	# Adiciona folhas e alimenta
	inv.add_material(&"folha", 2)
	var fed_folha := pen.feed(player, &"folha")
	assert(fed_folha, "Alimentou o cocho com folha")
	assert(pen.feed_level == 15.0, "Folha concedeu 15 unidades de comida")
	assert(not pen.mutation_boost, "Folha comum não ativa boost de mutação")

	# Adiciona adubo orgânico de monstro
	inv.add_material(&"adubo_organico", 1, 3, [&"mineralizado"])
	var fed_adubo := pen.feed(player, &"adubo_organico")
	assert(fed_adubo, "Alimentou o cocho com adubo orgânico")
	assert(pen.feed_level == 55.0, "Adubo somou +40 ao cocho (15 + 40 = 55)")
	assert(pen.mutation_boost, "Adubo mineralizado ativou impulso de mutação genética")

	pen.queue_free()
	player.queue_free()

func test_punnett_square_probabilities() -> void:
	print("\n[4/9] Quadro de Punnett e Previsão de Alelos...")

	var pen := _BreedingPen.new()
	root.add_child(pen)

	var sire := _CreatureDNA.randomized(_CreatureDNA.Species.TROTADOR, 10)
	sire.gender = _CreatureDNA.Gender.MALE
	sire.alleles["porte"] = ["T", "T"]
	sire.alleles["chifre"] = ["C", "C"]
	sire.alleles["padrao"] = ["p", "p"]
	pen.set_sire(sire)

	var dam := _CreatureDNA.randomized(_CreatureDNA.Species.TROTADOR, 20)
	dam.gender = _CreatureDNA.Gender.FEMALE
	dam.alleles["porte"] = ["t", "t"]
	dam.alleles["chifre"] = ["c", "c"]
	dam.alleles["padrao"] = ["p", "p"]
	pen.set_dam(dam)

	pen.mutation_boost = true
	var p: Dictionary = pen.punnett_square()

	# Cruzamento TT x tt => 100% Tt
	assert(p["porte"].has("Tt") and p["porte"]["Tt"] == 1.0, "Cruzamento TT x tt resulta em 100% Tt")
	# Cruzamento CC x cc => 100% com chifre (C dominante)
	assert(p["chifre"]["com_chifre"] == 1.0, "Cruzamento CC x cc resulta em 100% com chifre")
	# Mutação com adubo
	assert(p["mutation_chance"] == 0.10, "Taxa de mutação prevista com adubo é 10%")

	pen.queue_free()

func test_gestation_and_pausing() -> void:
	print("\n[5/9] Gestação Temporizada e Pausa por Falta de Comida...")

	var pen := _BreedingPen.new()
	pen.gestation_duration = 20.0
	root.add_child(pen)

	var sire := _CreatureDNA.randomized(_CreatureDNA.Species.TROTADOR, 1)
	sire.gender = _CreatureDNA.Gender.MALE
	pen.set_sire(sire)

	var dam := _CreatureDNA.randomized(_CreatureDNA.Species.TROTADOR, 2)
	dam.gender = _CreatureDNA.Gender.FEMALE
	pen.set_dam(dam)

	# Cocho vazio impede início
	pen.feed_level = 0.0
	assert(not pen.can_start_breeding(), "Não pode iniciar com cocho vazio")

	# Abastece cocho e inicia
	pen.feed_level = 10.0 # Queima a 0.5/s => dura 20 segundos
	assert(pen.can_start_breeding(), "Apto para iniciar cruzamento")
	assert(pen.start_breeding(), "Cruzamento iniciado")
	assert(pen.is_pregnant, "Fêmea entrou em gestação")

	# Avança 4 segundos
	pen.advance_time(4.0)
	assert(pen.gestation_time == 4.0, "Tempo de gestação avançou para 4s")
	assert(is_equal_approx(pen.feed_level, 8.0), "Alimento foi consumido para 8.0")

	# Esvazia a comida propositalmente
	pen.feed_level = 0.0
	pen.advance_time(10.0)
	assert(pen.gestation_time == 4.0, "Gestação paralisa sem comida sem abortar/matar matrizes")
	assert(pen.is_pregnant, "Continua em gestação")

	# Reabastece e conclui
	pen.feed_level = 30.0
	pen.finish_gestation()
	assert(not pen.is_pregnant, "Gestação concluída")
	assert(pen.offspring != null, "Filhote nasceu com sucesso")
	assert(pen.offspring.stage == _CreatureDNA.LifeStage.BABY, "Filhote nasce no estágio BABY")
	assert(pen.offspring.species == _CreatureDNA.Species.TROTADOR, "Espécie do filhote é Trotador")

	pen.queue_free()

func test_careful_slaughter_harvest() -> void:
	print("\n[6/9] Abate Cuidadoso do Filhote (Partes 100% Íntegras +1★)...")

	var pen := _BreedingPen.new()
	root.add_child(pen)

	var off := _CreatureDNA.randomized(_CreatureDNA.Species.TROTADOR, 88)
	off.stage = _CreatureDNA.LifeStage.BABY
	off.alleles["porte"] = ["T", "T"] # Porte Máximo (Denso)
	off.alleles["chifre"] = ["C", "C"] # Com chifre maciço
	pen.offspring = off

	var player := Node.new()
	var inv := _InventoryComponent.new()
	player.add_child(inv)
	var mastery := _MasteryComponent.new()
	player.add_child(mastery)
	player.set("mastery", mastery)
	root.add_child(player)

	var yields: Array[Dictionary] = pen.harvest_offspring(player)
	assert(not yields.is_empty(), "Abate gerou itens colhidos")
	assert(pen.offspring == null, "Filhote removido do cercado após o abate")

	var found_integro := false
	for y in yields:
		assert(y.quality == 3, "Qualidade garantida 3★ pelo abate cuidadoso")
		var traits: Array = y.traits
		if traits.has(&"integro"):
			found_integro = true
		if traits.has(&"denso"):
			print("      ✦ Trait genético herdado detectado: denso")
		if traits.has(&"chifre_macico"):
			print("      ✦ Trait genético herdado detectado: chifre_macico")

	assert(found_integro, "Todas as partes possuem o trait integro (+1★)")
	assert(inv.has_materials({ &"couro_trotador": 2 }), "Inventário recebeu couro do filhote")
	assert(mastery.get_xp(&"esfola") > 0.0, "Jogador recebeu XP de maestria de Esfola")

	pen.free()
	player.free()

func test_offspring_promotion_to_breeder_and_mount() -> void:
	print("\n[7/9] Promoção do Filhote a Nova Matriz e a Montaria...")

	var pen := _BreedingPen.new()
	root.add_child(pen)

	# 1. Promoção a Matriz Reprodutora
	var off_male := _CreatureDNA.randomized(_CreatureDNA.Species.TROTADOR, 555)
	off_male.gender = _CreatureDNA.Gender.MALE
	off_male.stage = _CreatureDNA.LifeStage.BABY
	pen.offspring = off_male

	assert(pen.generation == 1, "Inicia na Geração 1")
	var promoted_breeder := pen.promote_offspring_to_breeder()
	assert(promoted_breeder, "Filhote promovido a novo Reprodutor")
	assert(pen.generation == 2, "Cercado avançou para a Geração 2")
	assert(pen.sire == off_male, "Filhote macho assumiu o posto de Sire")
	assert(pen.sire.stage == _CreatureDNA.LifeStage.ADULT, "Filhote amadureceu para ADULT")
	assert(pen.offspring == null, "Berço do filhote liberado")

	# 2. Promoção a Montaria
	var off_mount := _CreatureDNA.randomized(_CreatureDNA.Species.TROTADOR, 777)
	off_mount.stage = _CreatureDNA.LifeStage.BABY
	pen.offspring = off_mount

	var player := Node.new()
	var promoted_mount := pen.promote_offspring_to_mount(player)
	assert(promoted_mount, "Filhote promovido a montaria própria")
	assert(pen.offspring == null, "Filhote transferido para as montarias")

	pen.free()
	player.free()

func test_serialization_and_persistence() -> void:
	print("\n[8/9] Serialização e Persistência do Cercado...")

	var pen := _BreedingPen.new()
	pen.pen_name = "Rancho Esperança"
	pen.generation = 4
	pen.feed_level = 68.5
	pen.gestation_time = 12.0

	var sire := _CreatureDNA.randomized(_CreatureDNA.Species.TROTADOR, 11)
	sire.gender = _CreatureDNA.Gender.MALE
	pen.set_sire(sire)

	var dam := _CreatureDNA.randomized(_CreatureDNA.Species.TROTADOR, 22)
	dam.gender = _CreatureDNA.Gender.FEMALE
	pen.set_dam(dam)

	pen.is_pregnant = true
	pen.mutation_boost = true

	var data: Dictionary = pen.to_dict()
	assert(data.name == "Rancho Esperança", "Nome preservado")
	assert(data.generation == 4, "Geração preservada")
	assert(data.feed_level == 68.5, "Nível de comida preservado")
	assert(data.is_pregnant == true, "Estado de gravidez preservado")
	assert(data.mutation_boost == true, "Mutation boost preservado")
	assert(data.sire is Dictionary and data.dam is Dictionary, "DNAs serializados como dicionário")

	var pen2 := _BreedingPen.new()
	pen2.from_dict(data)
	assert(pen2.pen_name == "Rancho Esperança", "Desserializou nome")
	assert(pen2.generation == 4, "Desserializou geração")
	assert(pen2.feed_level == 68.5, "Desserializou comida")
	assert(pen2.is_pregnant == true, "Desserializou gravidez")
	assert(pen2.mutation_boost == true, "Desserializou boost de mutação")
	assert(pen2.sire != null and pen2.sire.species == _CreatureDNA.Species.TROTADOR, "Desserializou Sire")
	assert(pen2.dam != null and pen2.dam.species == _CreatureDNA.Species.TROTADOR, "Desserializou Dam")

	pen.free()
	pen2.free()

func test_player_livestock_and_capture_dialog() -> void:
	print("\n[9/9] Rancho no Jogador e Opção no CaptureDialog...")

	var player := _Player.new()

	assert("livestock" in player, "Player possui lista livestock de matrizes")
	var dna := _CreatureDNA.randomized(_CreatureDNA.Species.TROTADOR, 333)
	var added := player.add_livestock(dna)
	assert(added, "Animal capturado adicionado ao livestock do Rancho")
	assert(player.livestock.size() == 1, "Livestock contém 1 animal")

	var retrieved := player.remove_livestock(0)
	assert(retrieved == dna, "Animal retirado corretamente para o cercado")
	assert(player.livestock.is_empty(), "Livestock vazio após remoção")

	# Teste do CaptureDialog com botão Rancho
	var dialog := _CaptureDialog.new()
	root.add_child(dialog)

	# Bicho normal (Trotador) pode ir ao rancho
	dialog.ask(dna, true, "")
	assert(dialog._rancho_btn != null, "Botão do rancho presente no CaptureDialog")
	assert(not dialog._rancho_btn.disabled, "Botão do rancho habilitado para Trotador")

	# Boss colossal (Rinolito) não pode ir ao rancho
	var rino := _CreatureDNA.randomized(_CreatureDNA.Species.RINOLITO, 999)
	dialog.ask(rino, false, "Colosso")
	assert(dialog._rancho_btn.disabled, "Botão do rancho desabilitado para Colosso colossal")

	dialog.free()
	player.free()
