extends SceneTree

## B40 / GDD-19 fase 4: tela do Diário [L] (capa, capítulos, Páginas, Marcos, mostras),
## escolher título, mostrar a quem está perto e a cópia que o cliente recebe do servidor.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const _DiaryScreen = preload("res://scripts/ui/diary_screen.gd")
const _DiaryComponent = preload("res://scripts/components/diary_component.gd")
const _FeatLedger = preload("res://scripts/data/feat_ledger.gd")
const _ForgedItem = preload("res://scripts/data/forged_item.gd")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("⭐ TESTANDO A TELA DO DIÁRIO (B40 fase 4)")
	print("========================================================")
	var ana := _player("Ana", Vector3.ZERO)
	var bruno := _player("Bruno", Vector3(3, 0, 0))
	var carla := _player("Carla", Vector3(60, 0, 0))
	_fill(ana, bruno)
	var screen := _DiaryScreen.new()
	screen.player = ana
	root.add_child(screen)
	screen.open()
	test_cover_and_title(screen, ana)
	test_tabs(screen)
	test_pages_and_show(screen, ana, bruno, carla)
	test_receive_and_snapshot(bruno)
	screen.close()
	print("\n🎉 TODOS OS TESTES DA TELA DO DIÁRIO PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _player(p_name: String, pos: Vector3) -> Player:
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
	return p

func _fill(ana: Player, bruno: Player) -> void:
	for i in 5:
		EventBusAutoload.report(ana, &"forja", {"item": "Peça %d" % i, "family": "couro", "quality": 2})
	EventBusAutoload.report(ana, &"coleta", {"material": "fibra", "amount": 3, "quality": 1})
	CombatResolver.resolve_hit(HitEvent.new(ana, bruno, 5000.0, DamageType.Type.SLASH, 0.0))
	bruno.is_downed = false
	bruno.pools.reset_all()

func _texts(n: Node, out: Array[String] = []) -> Array[String]:
	if n is Label:
		out.append((n as Label).text)
	elif n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		_texts(c, out)
	return out

func _has_text(screen: Node, piece: String) -> bool:
	return _texts(screen).any(func(t): return piece in t)

func test_cover_and_title(screen: _DiaryScreen, ana: Player) -> void:
	print("\n[1/4] Capa e título...")
	assert(screen.visible and screen.current_tab == &"capa", "Abre na capa")
	assert(_has_text(screen, "Tempo jogado") and _has_text(screen, "Abates"), "Capa mostra os totais")
	assert(_has_text(screen, "2 Rastro"), "Capa conta os Marcos (forja e primeiro sangue)")
	assert(screen.find_child("TitlePick", true, false) != null, "Escolha de título na capa")
	assert(not screen.choose_title("Rei do Mundo"), "Título que não tem não vale")
	assert(screen.choose_title("Aprendiz de Bigorna"), "Escolhe o título conquistado")
	assert(ana.diary.ledger.active_title == "Aprendiz de Bigorna", "Fica no Diário")
	assert(_has_text(screen, "Diário de Ana  ·  Aprendiz de Bigorna"), "Título no cabeçalho")
	print("  ✓ ok")

func test_tabs(screen: _DiaryScreen) -> void:
	print("\n[2/4] Separadores...")
	for t in _DiaryScreen.TABS:
		screen.select_tab(t.id)
		assert(screen._content.get_child_count() > 0, "Separador %s tem conteúdo" % t.id)
	screen.select_tab(&"forja")
	assert(_has_text(screen, "Peças forjadas") and _has_text(screen, "Por família"), "Feitos da forja")
	assert(_has_text(screen, "Melhor peça"), "Recorde da forja")
	assert(_has_text(screen, "Forjar 5 peças"), "Marcos do capítulo")
	assert(_has_text(screen, "Forja"), "Maestria ao lado")
	screen.select_tab(&"marcos")
	assert(_has_text(screen, "Marcos (2 de 24)"), "Lista todos os Marcos")
	assert(_has_text(screen, "(aguardando)"), "Marco das ilhas aparece como pendente")
	print("  ✓ ok")

func test_pages_and_show(screen: _DiaryScreen, ana: Player, bruno: Player, carla: Player) -> void:
	print("\n[3/4] Páginas e mostrar a quem está perto...")
	screen.select_tab(&"paginas")
	assert(_has_text(screen, "Abateu Bruno com Lâmina de Osso"), "Página do abate")
	assert(_has_text(screen, "Marco de Rastro: Aprendiz de Bigorna"), "Página do Marco")
	assert(screen.current_showcase().is_empty(), "Sem Página escolhida não mostra nada")
	screen.page_filter = "abate"
	screen.refresh()
	assert(not _has_text(screen, "Marco de Rastro"), "Filtro só deixa os abates")
	var near := ana.diary.nearby_players()
	assert(near.has(bruno) and not near.has(carla), "Só quem está a 10 m")
	var kill_index := ana.diary.ledger.pages.find(ana.diary.ledger.pages_of("abate")[0])
	screen.selected_page = kill_index
	screen.refresh()
	assert(screen.current_showcase() == ["pagina", kill_index], "Mostra a Página escolhida")
	screen._on_show_pressed()
	assert(bruno.diary.showcases[0]["kind"] == "pagina" and bruno.diary.showcases[0]["from"] == "Ana", "Bruno recebeu a Página")
	assert(screen._status.text == "Mostrado a Bruno", "Aviso na tela")
	screen.select_tab(&"forja")
	screen._on_show_pressed()
	assert(bruno.diary.showcases[0]["kind"] == "capitulo" and bruno.diary.showcases[0]["counters"]["pecas"] == 5, "Bruno recebeu o capítulo")
	assert(not bruno.diary.showcases[0].has("pages"), "Capítulo não leva as Páginas")
	assert(not ana.diary.show_to(carla, "titulo"), "Longe demais")
	assert(not ana.diary.show_to(ana, "titulo"), "Não mostra para si")
	assert(ana.diary.show_to(bruno, "titulo"), "Título vai")
	assert("Ana · Aprendiz de Bigorna mostrou o título" in _DiaryScreen.showcase_text(bruno.diary.showcases[0]), "Texto da mostra")
	print("  ✓ ok")

func test_receive_and_snapshot(bruno: Player) -> void:
	print("\n[4/4] Mostra estranha, cópia do servidor e rede...")
	var before := bruno.diary.showcases.size()
	bruno.diary.receive_showcase({"kind": "tudo", "from": "X"})
	assert(bruno.diary.showcases.size() == before, "Tipo desconhecido é descartado")
	bruno.diary.receive_showcase({"kind": "titulo", "from": "N".repeat(200), "segredo": 1})
	assert(bruno.diary.showcases[0]["from"].length() == 32 and not bruno.diary.showcases[0].has("segredo"), "Só passam os campos conhecidos")
	for i in 20:
		bruno.diary.receive_showcase({"kind": "titulo", "from": "Y"})
	assert(bruno.diary.showcases.size() == _DiaryComponent.MAX_SHOWCASES, "Guarda só as últimas mostras")
	var fired := [false]
	bruno.diary.snapshot_applied.connect(func(): fired[0] = true)
	var server_copy := _FeatLedger.new()
	server_copy.add(&"caca", "abates", 7)
	bruno.diary.apply_snapshot(JSON.parse_string(JSON.stringify(server_copy.to_dict())))
	assert(fired[0] and bruno.diary.ledger.count(&"caca", "abates") == 7, "Cópia do servidor substitui a do cliente")
	var net := root.get_node("NetworkManager")
	assert(net.peer_of(bruno) == 0, "Jogador local não é avatar de rede")
	assert(not net.send_diary_showcase(bruno, {"kind": "titulo"}), "Sem rede não envia")
	print("  ✓ ok")
