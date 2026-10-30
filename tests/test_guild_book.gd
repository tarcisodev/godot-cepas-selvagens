extends SceneTree

## B40 / GDD-19 fase 5: Livro do Totem (por membro e semana de 7 dias reais), Feitos da
## Guilda, anti-farm de doação e cofre, Placar das Guildas no Quadro da Vila e o save.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const _ForgedItem = preload("res://scripts/data/forged_item.gd")
const _GuildData = preload("res://scripts/data/guild_data.gd")
const _GuildLedger = preload("res://scripts/data/guild_ledger.gd")
const _GuildSystem = preload("res://scripts/systems/guild_system.gd")
const _GuildBook = preload("res://scripts/systems/guild_book.gd")
const _GuildTotem = preload("res://scripts/town/guild_totem.gd")
const _GuildScreen = preload("res://scripts/ui/guild_screen.gd")
const _DiaryScreen = preload("res://scripts/ui/diary_screen.gd")
const _MissionBoardScreen = preload("res://scripts/ui/mission_board_screen.gd")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("⭐ TESTANDO O LIVRO DO TOTEM E O PLACAR DAS GUILDAS (B40 fase 5)")
	print("========================================================")
	test_weeks_and_refund()
	var gs = _GuildSystem.get_instance()
	var lobos: _GuildData = gs.create_guild(&"livro_lobos", "Lobos do Ermo", "LOB", "Ana")
	lobos.add_member("Duda", _GuildData.Role.MEMBER)
	var garras: _GuildData = gs.create_guild(&"livro_garras", "Garras do Vale", "GAR", "Bruno")
	var ana := _player("Ana", Vector3.ZERO, &"livro_lobos")
	var bruno := _player("Bruno", Vector3(3, 0, 0), &"livro_garras")
	var carla := _player("Carla", Vector3(50, 0, 0), &"")
	test_credits(ana, carla, lobos)
	test_boss_and_invaders(ana, bruno, lobos)
	test_feats(ana, lobos)
	test_board_and_book(ana, bruno, carla, lobos, garras)
	test_screens(ana, carla, lobos)
	test_save(lobos)
	print("\n🎉 TODOS OS TESTES DO LIVRO DO TOTEM PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _player(p_name: String, pos: Vector3, guild_id: StringName) -> Player:
	var p: Player = PlayerScene.instantiate() as Player
	p.set_meta("player_name", p_name)
	root.add_child(p)
	p._setup_components()
	p.set_physics_process(false)
	p.diary.set_physics_process(false)
	p.global_position = pos
	var item := _ForgedItem.new()
	item.display_name = "Lâmina de Osso"
	item.family = &"couro"
	item.quality = 2
	p.inventory.equipped_items[_ForgedItem.Slot.MAIN_HAND] = item
	if not guild_id.is_empty():
		p.guild.join_guild(guild_id)
	return p

func _boss() -> Node3D:
	var c := Node3D.new()
	c.name = "Javali-Rei"
	var stats := StatsComponent.new()
	stats.name = "StatsComponent"
	c.add_child(stats)
	var pools := PoolsComponent.new()
	pools.name = "PoolsComponent"
	pools.stats = stats
	c.add_child(pools)
	c.add_to_group("boss")
	root.add_child(c)
	pools.reset_all()
	return c

func _hit(attacker: Node, target: Node, dmg: float) -> void:
	CombatResolver.resolve_hit(HitEvent.new(attacker, target, dmg, DamageType.Type.SLASH, 0.0))

func _texts(n: Node, out: Array[String] = []) -> Array[String]:
	if n is Label:
		out.append((n as Label).text)
	elif n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		_texts(c, out)
	return out

func _has_text(n: Node, piece: String) -> bool:
	return _texts(n).any(func(t): return piece in t)

func test_weeks_and_refund() -> void:
	print("\n[1/6] Semana de 7 dias reais e devolução no mesmo dia...")
	var monday := Time.get_unix_time_from_datetime_string("2026-10-26T00:00:00")
	var w := _GuildLedger.week_of(monday)
	assert(_GuildLedger.week_of(monday + 7 * 86400 - 1) == w, "Domingo à noite ainda é a mesma semana")
	assert(_GuildLedger.week_of(monday - 1) == w - 1, "Domingo anterior é a semana passada")
	assert(_GuildLedger.week_start_text(w) == "2026-10-26", "Semana começa na segunda")
	var l := _GuildLedger.new()
	l.credit("Ana", "manutencao", 50, monday + 3600)
	assert(l.refund("Ana", "manutencao", 80, monday + 7200) == 50, "Tirar no mesmo dia desfaz só o que pôs hoje")
	assert(l.amount("Ana", "manutencao", w) == 0 and l.total("manutencao") == 0, "Pôr e tirar no mesmo dia anula")
	l.credit("Ana", "manutencao", 30, monday + 3600)
	assert(l.refund("Ana", "manutencao", 30, monday + 86400 + 3600) == 0, "No dia seguinte já contou")
	l.credit("Ana", "tesouro", 99, monday)
	assert(l.total("tesouro") == 0, "Tipo desconhecido não entra")
	l.credit("Ana", "doacao", 10, monday - 9 * 7 * 86400)
	l.credit("Ana", "doacao", 10, monday)
	assert(not l.weeks.has(str(w - 9)) and l.total("doacao") == 20, "Semana velha sai do Livro, o total fica")
	print("  ✓ ok")

func test_credits(ana: Player, carla: Player, lobos: _GuildData) -> void:
	print("\n[2/6] Doação, cofre e caravana creditam o membro...")
	var week := _GuildLedger.week_of(_GuildLedger.now())
	EventBusAutoload.report(ana, &"doacao", {"material": "barra_ferro", "amount": 3, "value": 99999})
	assert(lobos.book.amount("Ana", "doacao", week) == 36, "Valor de mercado vem da ficha do material, não da tela")
	EventBusAutoload.report(ana, &"doacao", {"material": "pedra_sem_ficha", "amount": 50})
	assert(lobos.book.amount("Ana", "doacao", week) == 36, "Material sem valor de mercado não conta")
	EventBusAutoload.report(ana, &"manutencao", {"money": 40})
	EventBusAutoload.report(ana, &"manutencao_retirada", {"money": 15})
	assert(lobos.book.amount("Ana", "manutencao", week) == 25, "Tirou parte do cofre no mesmo dia")
	EventBusAutoload.report(ana, &"caravana", {"money": 120})
	assert(lobos.book.amount("Ana", "caravanas", week) == 1 and lobos.book.amount("Ana", "caravana_valor", week) == 120, "Caravana entra no Livro")
	assert(ana.diary.ledger.count(&"balcao", "caravanas") == 1, "E continua no Diário dela")
	EventBusAutoload.report(carla, &"caravana", {"money": 500})
	assert(lobos.book.week_contribution(week) == 36 + 25 + 120, "Quem não é da guilda não escreve no Livro")
	print("  ✓ ok")

func test_boss_and_invaders(ana: Player, bruno: Player, lobos: _GuildData) -> void:
	print("\n[3/6] Chefes e invasores no território...")
	var week := _GuildLedger.week_of(_GuildLedger.now())
	var boss := _boss()
	_hit(ana, boss, 99999.0)
	assert(lobos.book.amount("Ana", "chefes", week) == 1, "Chefe derrubado entra no Livro")
	_hit(ana, bruno, 5000.0)
	assert(lobos.book.amount("Ana", "invasores", week) == 0, "Fora do território não é invasor")
	bruno.is_downed = false
	bruno.pools.reset_all()
	ana.diary.ledger.recent_kills.clear()
	var totem := _GuildTotem.new()
	totem.guild_data = lobos
	root.add_child(totem)
	totem.global_position = Vector3(5, 0, 0)
	_hit(ana, bruno, 5000.0)
	assert(lobos.book.amount("Ana", "invasores", week) == 1, "Abate digno de outra guilda dentro do território")
	bruno.is_downed = false
	bruno.pools.reset_all()
	_hit(ana, bruno, 5000.0)
	assert(lobos.book.amount("Ana", "invasores", week) == 1, "O mesmo invasor de novo em 6 h não conta")
	bruno.is_downed = false
	bruno.pools.reset_all()
	print("  ✓ ok")

func test_feats(ana: Player, lobos: _GuildData) -> void:
	print("\n[4/6] Feitos da Guilda...")
	var got: Array[String] = []
	ana.diary.guild_feat_reached.connect(func(id): got.append(id))
	lobos.add_donation(&"madeira", 40)
	lobos.add_donation(&"pedra", 30)
	lobos.add_donation(&"barra_ferro", 10)
	assert(lobos.level == 2, "Sede subiu")
	EventBusAutoload.report(ana, &"doacao", {"material": "pedra", "amount": 1})
	assert(got.has("forte_erguido") and lobos.book.feats.has("forte_erguido"), "Feito do Forte com aviso")
	for i in 9:
		_GuildBook.credit(lobos, "Duda", "chefes", 1)
	assert(lobos.book.feats.has("dez_chefes"), "Dez chefes somando os membros")
	assert(_GuildBook.heraldry_unlocks(lobos) == ["Borda de Madeira", "Borda de Presas"], "Recompensa é só heráldica")
	assert(_GuildBook.credit(lobos, "Estranho", "chefes", 1).is_empty() and lobos.book.total("chefes") == 10, "Quem não é membro não conta")
	_GuildBook.credit(lobos, "Duda", "defesas", 5)
	assert(not lobos.book.feats.has("totem_firme"), "Feito das defesas espera o cerco do Totem")
	assert(_DiaryScreen.guild_feat_name("dez_chefes") == "Derrubar 10 chefes (Borda de Presas)", "Nome do aviso")
	print("  ✓ ok")

func test_board_and_book(ana: Player, bruno: Player, carla: Player, lobos: _GuildData, garras: _GuildData) -> void:
	print("\n[5/6] Placar só de guildas e Livro só para membros...")
	_GuildBook.credit(garras, "Bruno", "doacao", 5000)
	_GuildBook.credit(garras, "Bruno", "defesas", 2)
	var board := _GuildBook.scoreboard()
	assert(board["contribuicao"][0]["guild"] == "Garras do Vale" and board["contribuicao"][1]["guild"] == "Lobos do Ermo", "Quem mais contribuiu primeiro")
	assert(board["chefes"].size() == 1 and board["chefes"][0]["value"] == 10, "Coluna dos chefes")
	assert(board["defesas"].size() == 2 and board["defesas"][0]["tag"] == "LOB", "Coluna das defesas (Lobos 5, Garras 2)")
	assert(not JSON.stringify(board).contains("Ana") and not JSON.stringify(board).contains("Bruno"), "Placar não mostra jogador")
	var last := _GuildBook.scoreboard(_GuildLedger.week_of(_GuildLedger.now()) - 1)
	assert(last["contribuicao"].is_empty(), "Semana passada vazia")
	var view := _GuildBook.view_for(ana)
	assert(view["book"]["guild"] == "Lobos do Ermo" and view["book"]["rows"][0]["member"] == "Ana", "Ana lê o Livro dos Lobos")
	assert(not _GuildBook.view_for(carla).has("book"), "Sem guilda, sem Livro")
	assert(_GuildBook.book_view(lobos, "Bruno").is_empty(), "Bruno não lê o Livro dos Lobos")
	var text := _GuildBook.row_text(view["book"]["rows"][0])
	assert(text.begins_with("Ana — 183 $S") and "chefes 1" in text and "invasores 1" in text, "Linha do Livro: " + text)
	var lines := _GuildBook.feat_lines(view["book"])
	assert(lines[0].begins_with("✔ Erguer o Forte") and "aguardando" in lines[7], "Feitos com progresso")
	print("  ✓ ok")

func test_screens(ana: Player, carla: Player, lobos: _GuildData) -> void:
	print("\n[6/6] Telas: Diário [Totem], sede da guilda e Quadro da Vila...")
	var diary := _DiaryScreen.new()
	diary.player = ana
	root.add_child(diary)
	diary.open()
	diary.select_tab(&"totem")
	assert(_has_text(diary, "Livro do Totem") and _has_text(diary, "Ana — 183 $S"), "Aba Totem do Diário: %s" % [_texts(diary)])
	assert(_has_text(diary, "Derrubar 10 chefes"), "Feitos no Diário")
	assert(diary.current_showcase().is_empty(), "O Livro da guilda não se mostra a quem é de fora")
	diary.close()
	var gscreen := _GuildScreen.new()
	root.add_child(gscreen)
	gscreen.open(ana, lobos)
	gscreen._switch_tab(_GuildScreen.Tab.BOOK)
	assert(_has_text(gscreen, "Ana — 183 $S") and _has_text(gscreen, "Feitos da Guilda"), "Livro na sede")
	gscreen.open(carla, lobos)
	gscreen._switch_tab(_GuildScreen.Tab.BOOK)
	assert(_has_text(gscreen, "Só os membros") and not _has_text(gscreen, "Ana — "), "De fora não lê")
	gscreen.close()
	var board := _MissionBoardScreen.new()
	root.add_child(board)
	board.open(carla, null)
	board._set_filter(_MissionBoardScreen.FILTER_GUILD_BOARD)
	assert(_has_text(board, "Placar das Guildas") and _has_text(board, "1. [GAR] Garras do Vale"), "Placar no Quadro da Vila")
	assert(not _has_text(board, "Ana —") and not _has_text(board, "Bruno"), "Quadro não mostra jogador")
	board.close()
	print("  ✓ ok")

func test_save(lobos: _GuildData) -> void:
	print("\n[7] Livro salvo com a guilda...")
	var copy := _GuildData.from_dict(JSON.parse_string(JSON.stringify(lobos.to_dict())))
	var week := _GuildLedger.week_of(_GuildLedger.now())
	assert(copy.book.amount("Ana", "doacao", week) == lobos.book.amount("Ana", "doacao", week), "Livro volta do JSON")
	assert(copy.book.feats.has("dez_chefes") and copy.book.total("chefes") == 10, "Feitos e totais voltam")
	var sp := root.get_node("ServerPersistence")
	var path := "user://test_guild_book_save.json"
	assert(sp.save_guilds(path), "Servidor grava as guildas")
	_GuildSystem.get_instance().guilds.clear()
	assert(sp.load_guilds(path), "E lê de volta")
	var back: _GuildData = _GuildSystem.get_instance().get_guild(&"livro_lobos")
	assert(back != null and back.book.total("chefes") == 10 and back.level == 2, "Guilda e Livro restaurados")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("  ✓ ok")
