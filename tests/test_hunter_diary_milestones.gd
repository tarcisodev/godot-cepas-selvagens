extends SceneTree

## B40 / GDD-19 fase 3: Marcos (Rastro, Trilha, Lenda), recompensas sem poder (título, carta,
## adorno, Contrato de Mestre no Quadro), memória na arma e anti-farm do §8.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const _FeatLedger = preload("res://scripts/data/feat_ledger.gd")
const _DiaryComponent = preload("res://scripts/components/diary_component.gd")
const _ForgedItem = preload("res://scripts/data/forged_item.gd")
const _MilestoneDef = preload("res://scripts/data/milestone_def.gd")
const _MilestoneTable = preload("res://scripts/data/milestone_table.gd")
const _MissionBoardSystem = preload("res://scripts/systems/mission_board_system.gd")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("⭐ TESTANDO OS MARCOS DO DIÁRIO (B40 fase 3)")
	print("========================================================")
	test_table()
	var ana := _player("Ana", "Lâmina de Osso", 3)
	var bruno := _player("Bruno", "Martelo de Pedra", 2)
	test_rastro_and_title(ana)
	test_trilha_and_board(ana)
	test_lenda_flawless_boss(ana, bruno)
	test_worthy_kills(ana, bruno)
	test_bred_and_daily_cap(ana)
	test_save(ana)
	print("\n🎉 TODOS OS TESTES DOS MARCOS PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _player(p_name: String, weapon: String, quality: int) -> Player:
	var p: Player = PlayerScene.instantiate() as Player
	p.set_meta("player_name", p_name)
	root.add_child(p)
	p._setup_components()
	p.set_physics_process(false)
	p.diary.set_physics_process(false)
	var item := _ForgedItem.new()
	item.display_name = weapon
	item.family = &"couro"
	item.quality = quality
	p.inventory.equipped_items[_ForgedItem.Slot.MAIN_HAND] = item
	return p

func _creature(c_name: String, boss: bool = false) -> Node3D:
	var c := Node3D.new()
	c.name = c_name
	var stats := StatsComponent.new()
	stats.name = "StatsComponent"
	c.add_child(stats)
	var pools := PoolsComponent.new()
	pools.name = "PoolsComponent"
	pools.stats = stats
	c.add_child(pools)
	if boss:
		c.add_to_group("boss")
	root.add_child(c)
	pools.reset_all()
	return c

func _hit(attacker: Node, target: Node, dmg: float) -> void:
	CombatResolver.resolve_hit(HitEvent.new(attacker, target, dmg, DamageType.Type.SLASH, 0.0))

func _revive(p: Player) -> void:
	p.is_downed = false
	p.pools.reset_all()

func test_table() -> void:
	print("\n[1/7] Tabela de Marcos...")
	var defs := _MilestoneTable.all()
	assert(defs.size() == 24, "Oito capítulos × três graus")
	var ids := {}
	var per_chapter := {}
	for d in defs:
		assert(not ids.has(d.id), "Id repetido: %s" % d.id)
		ids[d.id] = true
		per_chapter[d.chapter] = per_chapter.get(d.chapter, 0) + 1
		assert(_FeatLedger.CHAPTERS.has(d.chapter), "Capítulo existe")
		assert(d.title != "", "Todo Marco dá título")
	for c in per_chapter:
		assert(per_chapter[c] == 3, "Rastro, Trilha e Lenda em %s" % c)
	assert(_MilestoneTable.get_def(&"andancas_lenda").pending, "Ilhas aguardam o B39")
	print("  ✓ ok")

func test_rastro_and_title(ana: Player) -> void:
	print("\n[2/7] Rastro, título e Página de Marco...")
	var got: Array = []
	ana.diary.milestone_reached.connect(func(d): got.append(d.id))
	for i in 6:
		EventBusAutoload.report(ana, &"forja", {"item": "Peça %d" % i, "family": "couro", "quality": 2})
	assert(got.count(&"forja_rastro") == 1, "Marco cravado uma vez só")
	var l: _FeatLedger = ana.diary.ledger
	assert(l.has_milestone(&"forja_rastro") and l.titles.has("Aprendiz de Bigorna"), "Título liberado")
	assert(not l.set_title("Rei do Mundo"), "Título não conquistado não vale")
	assert(l.set_title("Aprendiz de Bigorna") and l.active_title == "Aprendiz de Bigorna", "Escolhe o título")
	var page: Dictionary = l.pages_of("marco")[0]
	assert(page["who"]["tier"] == "Rastro" and page["keep"], "Página de Marco fica para sempre")
	print("  ✓ ok")

func test_trilha_and_board(ana: Player) -> void:
	print("\n[3/7] Trilha libera o Contrato de Mestre...")
	var board := _MissionBoardSystem.new()
	var master: Dictionary = {}
	for c in board.active_contracts:
		if c.get("is_master", false):
			master = c
	assert(not master.is_empty(), "O Quadro tem um Contrato de Mestre")
	assert(master["title"].begins_with("Contrato de Mestre"), "Nome do contrato")
	var forge_master := board.generate_contract(_MissionBoardSystem.Category.FORGE, true)
	var normal := board.generate_contract(_MissionBoardSystem.Category.FORGE)
	assert(forge_master["requires_access"] == "forja" and normal["requires_access"] == "", "Pede o Marco da forja")
	assert(not board.has_access(forge_master, ana), "Sem o Marco de Trilha não pega")
	assert(board.has_access(normal, ana), "Contrato comum é de todos")
	EventBusAutoload.report(ana, &"forja", {"item": "Gibão de Pano", "family": "pano", "quality": 2})
	EventBusAutoload.report(ana, &"forja", {"item": "Elmo de Ferro", "family": "ferro", "quality": 2})
	assert(ana.diary.ledger.has_milestone(&"forja_trilha"), "Três famílias")
	assert(board.has_access(forge_master, ana), "Com o Marco, pega o Contrato de Mestre")
	assert(not ana.diary.has_board_access(&"caca"), "Acesso é por capítulo")
	print("  ✓ ok")

func test_lenda_flawless_boss(ana: Player, bruno: Player) -> void:
	print("\n[4/7] Lenda: chefe sem levar golpe forte...")
	# Bruno leva um golpe forte do chefe: o abate dele não é ileso
	var boss1 := _creature("Javali-Rei Velho", true)
	_hit(boss1, bruno, bruno.stats.get_stat(&"max_health") * 0.3)
	_hit(bruno, boss1, 500.0)
	assert(bruno.diary.ledger.count(&"caca", "chefes") == 1, "Bruno abateu o chefe")
	assert(bruno.diary.ledger.count(&"caca", "chefes_ilesos") == 0, "Mas levou golpe forte")
	assert(not bruno.diary.has_lenda(), "Sem Lenda para o Bruno")
	_revive(bruno)
	# Ana leva só um arranhão e derruba
	var boss2 := _creature("Rei-Javali", true)
	_hit(boss2, ana, 1.0)
	_hit(ana, boss2, 500.0)
	var l: _FeatLedger = ana.diary.ledger
	assert(l.has_milestone(&"caca_lenda") and ana.diary.has_lenda(), "Intocável")
	assert(ana.card_collection.is_card_unlocked(&"beast_horn"), "Carta do Marco")
	assert(l.adornos.has("presa_dourada"), "Adorno do Marco")
	var feats: Array = ana.inventory.equipped_in(_ForgedItem.Slot.MAIN_HAND).memory.get("feitos", [])
	assert(feats.size() == 2, "Memória do chefe e do Marco na arma")
	assert(feats[0].begins_with("Derrubou Rei-Javali") and feats[1].begins_with("Marco de Lenda: Intocável"), "Texto da memória")
	assert(ana.stats.get_stat(&"max_health") == bruno.stats.get_stat(&"max_health"), "Marco não dá atributo")
	print("  ✓ ok")

func test_worthy_kills(ana: Player, bruno: Player) -> void:
	print("\n[5/7] Abate digno (anti-farm)...")
	var l: _FeatLedger = ana.diary.ledger
	_hit(ana, bruno, 5000.0)
	assert(l.count(&"sangue", "abates") == 1 and l.count(&"sangue", "abates_dignos") == 1, "Primeiro abate é digno")
	assert(l.has_milestone(&"sangue_rastro"), "Primeiro Sangue")
	_revive(bruno)
	_hit(ana, bruno, 5000.0)
	assert(l.count(&"sangue", "abates") == 2 and l.count(&"sangue", "abates_dignos") == 1, "A mesma vítima em menos de 6 h não é digna")
	assert(not l.pages_of("abate")[0]["digno"], "A Página marca que não foi digno")
	_revive(bruno)
	# Mesma guilda não conta
	var carla := _player("Carla", "Faca", 3)
	ana.guild.guild_id = &"lobos"
	carla.guild.guild_id = &"lobos"
	_hit(ana, carla, 5000.0)
	assert(l.count(&"sangue", "abates_dignos") == 1, "Mesma guilda não é digno")
	ana.guild.guild_id = &""
	# Equipamento fraco demais não conta
	var dino := _player("Dino", "Galho", 1)
	dino.inventory.equipped_items.clear()
	_hit(ana, dino, 5000.0)
	assert(l.count(&"sangue", "abates_dignos") == 1, "Vítima sem equipamento não é digna")
	# Derrubar quem tem Lenda
	_hit(bruno, ana, 5000.0)
	assert(bruno.diary.ledger.count(&"sangue", "lendas_abatidas") == 1, "Bruno derrubou uma Lenda")
	assert(bruno.diary.ledger.has_milestone(&"sangue_lenda"), "Matador de Lendas")
	_revive(ana)
	print("  ✓ ok")

func test_bred_and_daily_cap(ana: Player) -> void:
	print("\n[6/7] Bicho de cercado e teto diário...")
	var l: _FeatLedger = ana.diary.ledger
	var before := l.count(&"caca", "abates")
	var pet := _creature("Trotador")
	pet.set_meta("criado", true)
	_hit(ana, pet, 500.0)
	assert(l.count(&"caca", "abates") == before, "Bicho de cercado não conta na Caça")
	assert(l.pages_of("abate")[0].get("criado", false), "Mas vira Página")
	EventBusAutoload.report(ana, &"coleta", {"material": "fibra", "amount": 150, "quality": 1})
	EventBusAutoload.report(ana, &"coleta", {"material": "fibra", "amount": 150, "quality": 1})
	assert(l.count(&"coleta", "recursos") == _DiaryComponent.GATHER_DAILY_CAP, "Teto por lugar e por dia")
	l.daily["day"] = -1 # outro dia de jogo
	EventBusAutoload.report(ana, &"coleta", {"material": "fibra", "amount": 10, "quality": 1})
	assert(l.count(&"coleta", "recursos") == _DiaryComponent.GATHER_DAILY_CAP + 10, "Novo dia, novo teto")
	assert(l.has_milestone(&"coleta_rastro"), "Catador")
	print("  ✓ ok")

func test_save(ana: Player) -> void:
	print("\n[7/7] Save dos Marcos...")
	var data: Dictionary = JSON.parse_string(JSON.stringify(ana.diary.to_dict()))
	var copy := _FeatLedger.new()
	copy.from_dict(data)
	assert(copy.has_milestone(&"caca_lenda") and copy.has_milestone(&"forja_trilha"), "Marcos voltam")
	assert(copy.titles == ana.diary.ledger.titles and copy.active_title == "Aprendiz de Bigorna", "Títulos voltam")
	assert(copy.board_access.has("forja") and copy.adornos.has("presa_dourada"), "Acesso e adornos voltam")
	assert(copy.recent_kills.has("Bruno"), "Anti-farm lembra da vítima")
	print("  ✓ ok")
