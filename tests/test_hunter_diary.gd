extends SceneTree

## B40 / GDD-19 fases 1 e 2: Diário do Caçador — Páginas de abate, assistência e queda
## (criatura, jogador e ambiente), limite de 50 Páginas, ofícios dos oito capítulos,
## andanças, recordes e save local e do servidor.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const _FeatLedger = preload("res://scripts/data/feat_ledger.gd")
const _DiaryComponent = preload("res://scripts/components/diary_component.gd")
const _ForgedItem = preload("res://scripts/data/forged_item.gd")
const _ServerPersistence = preload("res://scripts/core/server_persistence.gd")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("⭐ TESTANDO O DIÁRIO DO CAÇADOR (B40)")
	print("========================================================")
	test_ledger()
	var ana := _player("Ana", "Lâmina de Osso", &"talho")
	var bruno := _player("Bruno", "Martelo de Pedra", &"malho")
	test_creature_kill(ana)
	test_assist(ana, bruno)
	test_assist_window(ana, bruno)
	test_pvp(ana, bruno)
	test_fall(ana)
	test_activities(ana, bruno)
	test_market_and_cooking(ana)
	test_movement(ana)
	test_save(ana)
	print("\n🎉 TODOS OS TESTES DO DIÁRIO PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _player(p_name: String, weapon: String, family: StringName) -> Player:
	var p: Player = PlayerScene.instantiate() as Player
	p.set_meta("player_name", p_name)
	root.add_child(p)
	p._setup_components()
	p.set_physics_process(false) # sem chão no teste
	var item := _ForgedItem.new()
	item.display_name = weapon
	item.family = family
	p.inventory.equipped_items[_ForgedItem.Slot.MAIN_HAND] = item
	return p

## Criatura de teste: só Vida e uma parte que sempre quebra
func _creature(c_name: String, boss: bool = false) -> Node3D:
	var script := GDScript.new()
	script.source_code = "extends Node3D\nfunc damage_part(_p, _d) -> bool:\n\treturn true\n"
	script.reload()
	var c := Node3D.new()
	c.set_script(script)
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

func _hit(attacker: Node, target: Node, dmg: float, part: StringName = &"") -> Dictionary:
	return CombatResolver.resolve_hit(HitEvent.new(attacker, target, dmg, DamageType.Type.SLASH, 0.0, part))

func _revive(p: Player) -> void:
	p.is_downed = false
	p.pools.reset_all()

func test_ledger() -> void:
	print("\n[1/10] Contadores e limite de Páginas...")
	var l := _FeatLedger.new()
	l.add(&"caca", "abates")
	l.add(&"caca", "abates", 2)
	assert(l.count(&"caca", "abates") == 3, "Contador soma")
	assert(l.count(&"forja", "pecas") == 0, "Contador vazio é zero")
	l.add_page({"kind": "abate", "keep": true, "who": {"name": "Rei"}})
	for i in 60:
		l.add_page({"kind": "queda", "n": i})
	assert(l.pages.size() == _FeatLedger.MAX_PAGES + 1, "50 Páginas soltas + a de chefe")
	assert(l.pages[0].get("keep", false), "A Página de chefe fica para sempre")
	assert(l.pages_of("queda")[0]["n"] == 59, "pages_of vem da mais nova para a mais antiga")
	assert(l.pages_of("queda")[-1]["n"] == 10, "As quedas mais antigas saíram")
	var copy := _FeatLedger.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(l.to_dict())))
	assert(copy.count(&"caca", "abates") == 3 and copy.pages.size() == l.pages.size(), "Volta igual do JSON")
	print("  ✓ ok")

func test_creature_kill(ana: Player) -> void:
	print("\n[2/10] Abate de chefe com parte quebrada...")
	var boss := _creature("Rei-Javali", true)
	_hit(ana, boss, 40.0, &"presa")
	_hit(ana, boss, 70.0)
	var d: _DiaryComponent = ana.diary
	assert(d.ledger.count(&"caca", "abates") == 1, "Um abate de caça")
	assert(d.ledger.count(&"caca", "especie:Rei-Javali") == 1, "Conta por espécie")
	assert(d.ledger.count(&"caca", "chefes") == 1, "Conta chefe")
	assert(d.ledger.count(&"caca", "partes_quebradas") == 1, "Presa quebrada")
	assert(d.ledger.count(&"capa", "abates") == 1, "Total na capa")
	var page: Dictionary = d.ledger.pages_of("abate")[0]
	assert(page["who"]["name"] == "Rei-Javali" and page["who"]["boss"], "Página diz quem")
	assert(page["with"]["weapon"] == "Lâmina de Osso" and page["with"]["family"] == "talho", "Página diz com o quê")
	assert(page["with"]["damage_type"] == "slash", "Tipo do golpe final")
	assert(page["parts"].has("presa"), "Partes quebradas na Página")
	assert(page["keep"], "Chefe fica para sempre")
	# Golpe no corpo caído não é outro abate
	_hit(ana, boss, 30.0)
	assert(d.ledger.count(&"caca", "abates") == 1, "Bater no corpo não conta de novo")
	print("  ✓ ok")

func test_assist(ana: Player, bruno: Player) -> void:
	print("\n[3/10] Assistência e ajuda...")
	var t := _creature("Trotador")
	_hit(ana, t, 50.0)
	_hit(bruno, t, 60.0)
	assert(ana.diary.ledger.count(&"caca", "assistencias") == 1, "Ana ajudou")
	assert(ana.diary.ledger.count(&"caca", "abates") == 1, "Ana não ganhou o abate")
	assert(bruno.diary.ledger.count(&"caca", "abates") == 1, "Bruno abateu")
	var page: Dictionary = bruno.diary.ledger.pages_of("abate")[0]
	assert(page["helpers"] == ["Ana"], "A Página do Bruno cita a Ana")
	assert(ana.diary.ledger.pages_of("assistencia")[0]["who"]["name"] == "Trotador", "Página de assistência")
	print("  ✓ ok")

func test_assist_window(ana: Player, bruno: Player) -> void:
	print("\n[4/10] Acerto antigo não é assistência...")
	var t := _creature("Saltarelo")
	_hit(ana, t, 50.0)
	ana.diary._hits_dealt[t.get_instance_id()]["t"] -= _DiaryComponent.ASSIST_WINDOW + 1.0
	_hit(bruno, t, 60.0)
	assert(ana.diary.ledger.count(&"caca", "assistencias") == 1, "Fora da janela de 15 s não conta")
	print("  ✓ ok")

func test_pvp(ana: Player, bruno: Player) -> void:
	print("\n[5/10] Abate e queda entre jogadores...")
	_hit(bruno, ana, 60.0)
	_hit(bruno, ana, 5000.0)
	assert(bruno.diary.ledger.count(&"sangue", "abates") == 1, "Bruno abateu a Ana")
	assert(ana.diary.ledger.count(&"sangue", "quedas") == 1, "Ana caiu para um jogador")
	assert(ana.diary.ledger.count(&"capa", "quedas") == 1, "Queda na capa")
	var fall: Dictionary = ana.diary.ledger.pages_of("queda")[0]
	assert(fall["who"]["kind"] == "jogador" and fall["who"]["name"] == "Bruno", "Queda diz quem")
	assert(fall["with"]["weapon"] == "Martelo de Pedra", "Queda diz com o quê")
	var kill: Dictionary = bruno.diary.ledger.pages_of("abate")[0]
	assert(kill["who"]["name"] == "Ana" and not kill["keep"], "Abate de jogador não é para sempre")
	_hit(bruno, ana, 60.0)
	assert(ana.diary.ledger.count(&"capa", "quedas") == 1, "Golpe em quem já caiu não é outra queda")
	_revive(ana)
	print("  ✓ ok")

func test_fall(ana: Player) -> void:
	print("\n[6/10] Queda de altura...")
	var hit := HitEvent.new(null, ana, 500.0, DamageType.Type.IMPACT, 0.0, &"queda")
	CombatResolver.resolve_hit(hit)
	assert(ana.diary.ledger.count(&"capa", "quedas") == 2, "Segunda queda")
	assert(ana.diary.ledger.count(&"sangue", "quedas") == 1, "Queda de altura não é do Sangue")
	assert(ana.diary.ledger.pages_of("queda")[0]["who"]["name"] == "Queda", "Página diz que foi a queda")
	_revive(ana)
	print("  ✓ ok")

func test_activities(ana: Player, bruno: Player) -> void:
	print("\n[7/10] Ofícios e recordes...")
	var l: _FeatLedger = ana.diary.ledger
	EventBusAutoload.report(ana, &"coleta", {"material": "minerio_ferro", "amount": 3, "quality": 2})
	EventBusAutoload.report(ana, &"coleta", {"material": "minerio_ferro", "amount": 2, "quality": 1})
	EventBusAutoload.report(ana, &"pesca", {"material": "peixe", "species": "Lambari", "quality": 3})
	EventBusAutoload.report(ana, &"forja", {"item": "Lâmina de Osso", "family": "talho", "quality": 2})
	EventBusAutoload.report(ana, &"forja", {"item": "Elmo de Chifre", "family": "couraca", "quality": 4})
	EventBusAutoload.report(ana, &"fundicao", {"material": "barra_ferro", "quality": 2})
	EventBusAutoload.report(ana, &"captura", {"species": "Trotador"})
	EventBusAutoload.report(ana, &"cria", {"species": "Trotador", "generation": 3})
	EventBusAutoload.report(ana, &"elo", {"mount": "Brasa", "elo": 42})
	EventBusAutoload.report(ana, &"elo", {"mount": "Brasa", "elo": 30})
	EventBusAutoload.report(ana, &"companheira_perdida", {"name": "Brasa", "species": "Trotador", "elo": 42})
	EventBusAutoload.report(ana, &"missao", {"title": "Chifres", "money": 40})
	EventBusAutoload.report(ana, &"caravana", {"money": 60})
	# Ofício de outro jogador não entra no Diário da Ana
	EventBusAutoload.report(bruno, &"forja", {"item": "Martelo", "family": "malho", "quality": 5})
	assert(l.count(&"coleta", "recursos") == 5 and l.count(&"coleta", "material:minerio_ferro") == 5, "Coleta soma")
	assert(l.record(&"coleta", "melhor_coleta")["value"] == 2.0, "Recorde de coleta fica no melhor")
	assert(l.count(&"coleta", "peixes") == 1, "Peixe conta")
	assert(l.count(&"forja", "pecas") == 2 and l.count(&"forja", "familia:couraca") == 1, "Forja por família")
	assert(l.record(&"forja", "melhor_peca")["label"] == "Elmo de Chifre", "Melhor peça é a da Ana, não a do Bruno")
	assert(l.count(&"forja", "barras") == 1, "Fundição conta")
	assert(bruno.diary.ledger.count(&"forja", "pecas") == 1, "Bruno tem a dele")
	assert(l.count(&"criadouro", "capturas") == 1 and l.count(&"criadouro", "crias") == 1, "Criadouro")
	assert(l.record(&"criadouro", "maior_geracao")["value"] == 3.0, "Maior geração")
	assert(l.record(&"criadouro", "maior_elo")["value"] == 42.0, "Maior Elo não cai")
	assert(l.count(&"criadouro", "perdidas") == 1, "Companheira perdida conta")
	var loss: Dictionary = l.pages_of("perda")[0]
	assert(loss["who"]["name"] == "Brasa" and loss["keep"], "Página da perda fica para sempre")
	assert(l.count(&"balcao", "missoes") == 1 and l.count(&"balcao", "caravanas") == 1, "Balcão")
	assert(l.count(&"balcao", "moedas") == 100, "Moedas de missão e caravana")
	assert(l.record(&"caca", "maior_caca")["label"] == "Rei-Javali", "Maior caça é o chefe")
	print("  ✓ ok")

func test_market_and_cooking(ana: Player) -> void:
	print("\n[8/10] Mercado e cozinha...")
	var l: _FeatLedger = ana.diary.ledger
	var m := VillageMarket.new(1)
	m.pending_money = 75
	m.pending_items.append({"id": &"sal", "n": 2, "q": 1, "traits": []})
	m.collect(ana.inventory, ana.wallet)
	assert(l.count(&"balcao", "vendas") == 1 and l.count(&"balcao", "compras") == 1, "Mercado conta venda e compra")
	assert(l.record(&"balcao", "maior_venda")["value"] == 75.0, "Maior venda")
	EventBusAutoload.report(ana, &"cozinha", {"result": "carne_torrada", "quality": 1, "burned": true})
	EventBusAutoload.report(ana, &"cozinha", {"result": "ensopado_campeiro", "quality": 2})
	assert(l.count(&"fogao", "pratos") == 1 and l.count(&"fogao", "queimados") == 1, "Queimado não é prato")
	assert(l.count(&"fogao", "receita:ensopado_campeiro") == 1, "Receita conta")
	print("  ✓ ok")

func test_movement(ana: Player) -> void:
	print("\n[9/10] Andanças...")
	var l: _FeatLedger = ana.diary.ledger
	ana.global_position = Vector3(10, 0, 10)
	ana.diary._last_pos = null
	ana.diary.track_movement()
	var places := l.count(&"andancas", "lugares")
	var walked := l.count(&"andancas", "metros_a_pe")
	ana.global_position = Vector3(30, 0, 10)
	ana.diary.track_movement()
	ana.global_position = Vector3(30, 0, 25.5)
	ana.diary.track_movement()
	assert(l.count(&"andancas", "metros_a_pe") == walked + 35, "Andou 35 m a pé")
	ana.global_position = Vector3(500, 0, 10)
	ana.diary.track_movement()
	assert(l.count(&"andancas", "metros_a_pe") == walked + 35, "Teleporte não conta como andança")
	assert(l.count(&"andancas", "lugares") == places + 1, "Lugar novo conta uma vez")
	var mount := Node3D.new()
	ana.mounted_on = mount
	ana.global_position = Vector3(520, 0, 10)
	ana.diary.track_movement()
	ana.mounted_on = null
	mount.free()
	assert(l.count(&"andancas", "metros_montado") == 20, "Montado conta à parte")
	print("  ✓ ok")

func test_save(ana: Player) -> void:
	print("\n[10/10] Save local e do servidor...")
	var data: Dictionary = root.get_node("SaveGame").collect(ana)
	assert(data.has("diary"), "Save local tem o Diário")
	var server: Dictionary = _ServerPersistence.serialize_player(ana)
	assert(server.has("diary"), "Save do servidor tem o Diário")
	var other := _player("Ana2", "Nada", &"talho")
	root.get_node("SaveGame").apply_save(other, JSON.parse_string(JSON.stringify(data)))
	assert(other.diary.ledger.count(&"capa", "quedas") == 2, "Volta do save local")
	assert(other.diary.ledger.pages.size() == ana.diary.ledger.pages.size(), "Páginas voltam")
	var third := _player("Ana3", "Nada", &"talho")
	_ServerPersistence.apply_player_data(third, JSON.parse_string(JSON.stringify(server)))
	assert(third.diary.ledger.count(&"caca", "chefes") == 1, "Volta do save do servidor")
	assert(other.diary.ledger.record(&"forja", "melhor_peca")["label"] == "Elmo de Chifre", "Recordes voltam")
	assert(other.diary.ledger.places.size() == ana.diary.ledger.places.size(), "Lugares voltam")
	print("  ✓ ok")
