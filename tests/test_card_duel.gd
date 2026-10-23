extends SceneTree

## B18 / GDD-07 §7: regras do Duelo de Cepas, traits, fim de jogo, equilíbrio contra a
## Taverneira e aposta/prêmio na mesa da Taverna.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🃏 TESTANDO O DUELO DE CEPAS (B18 / GDD-07 §7)")
	print("========================================================")
	test_rules()
	test_traits()
	test_balance()
	test_table()
	print("\n🎉 TODOS OS TESTES DO DUELO DE CEPAS PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _card(id: StringName) -> CardData:
	return CardDatabase.get_card(id)

## Duelo montado na mão, sem embaralhar
func _fixed(hand0: Array, hand1: Array) -> CardDuel:
	var d := CardDuel.new()
	d.start([], [], 1)
	d.hands = [hand0.duplicate(), hand1.duplicate()]
	d.decks = [[CardDuel.filler(), CardDuel.filler()], [CardDuel.filler(), CardDuel.filler()]]
	d.ether = [5, 5]
	d.ether_max = [5, 5]
	return d

func test_rules() -> void:
	print("\n[1/4] Baralho, Éter, ataque direto e fim por Vida...")
	var deck := CardDuel.build_deck([&"coin"])
	assert(deck.size() == CardDuel.DECK_SIZE and deck.count(_card(&"coin")) == 3, "3 cópias + Recrutas até 12")
	var d := CardDuel.new()
	d.start(CardDuel.build_deck([&"coin"]), CardDuel.build_deck([&"coin"]), 7)
	assert(d.hands[0].size() == CardDuel.START_HAND + 1 and d.ether[0] == 1, "Mão inicial 4 + compra; Éter 1 no primeiro turno")
	assert(d.play(1, 0, 0) != "", "Fora da vez não joga")
	d = _fixed([CardDuel.filler()], [])
	assert(d.play(0, 0, 1) == "", "Baixa o Recruta")
	assert(d.play(0, 0, 1) != "", "Mão vazia/fileira ocupada recusa")
	d.end_turn(0)
	assert(d.life[1] == CardDuel.START_LIFE - 2, "Fileira vazia: Poder direto na Vida")
	assert(d.current == 1, "Passa a vez")
	d.life[1] = 1
	d.end_turn(1)
	d.end_turn(0)
	assert(d.is_over() and d.winner == 0, "Vida 0 encerra")
	print("  ✓ Baralho, Éter, ataque direto e vitória")

func test_traits() -> void:
	print("\n[2/4] Elementos e traits...")
	# Terra contra um Raio inventado: +2 de dano
	var bolt := CardData.new(&"raio_teste", "Raio", "Teste", CardData.Rarity.COMMON, CardData.CardElement.LIGHTNING, 1, 1, 9)
	var d := _fixed([_card(&"element_earth")], [bolt])
	d.board[1][0] = {"card": bolt, "poise": 9, "fresh": false, "burn": 0}
	d.play(0, 0, 0)
	d.end_turn(0)
	assert(d.board[1][0].poise == 9 - (3 + CardDuel.ADVANTAGE_DAMAGE), "Terra > Raio: +2 de dano")
	# Mímico: dano dobrado no primeiro ataque
	d = _fixed([_card(&"mimic")], [])
	d.play(0, 0, 2)
	d.end_turn(0)
	assert(d.life[1] == CardDuel.START_LIFE - 14, "Emboscada Dentada dobra o primeiro ataque")
	# Colmeia devolve 1 a quem bate
	d = _fixed([CardDuel.filler()], [])
	d.board[1][1] = {"card": _card(&"beehive"), "poise": 6, "fresh": false, "burn": 0}
	d.play(0, 0, 1)
	d.end_turn(0)
	assert(d.board[0][1].poise == 2 and d.board[1][1].poise == 4, "Enxame Protetor fere o atacante")
	# Moeda compra 1 ao entrar
	d = _fixed([_card(&"coin")], [])
	var hand_before: int = d.hands[0].size()
	d.play(0, 0, 0)
	assert(d.hands[0].size() == hand_before, "Suborno de Taverna compra 1")
	# Cogumelos: caiu = +1 Éter no próximo turno do dono
	d = _fixed([], [CardDuel.filler()])
	d.board[0][0] = {"card": _card(&"trenchcoat_mushrooms"), "poise": 1, "fresh": false, "burn": 0}
	d.current = 1
	d.play(1, 0, 0)
	d.end_turn(1)
	assert(d.board[0][0].is_empty() and d.ether[0] == d.ether_max[0] + 1, "Contrabando Fúngico dá +1 Éter")
	# Fogo queima 2 por 2 rodadas
	d = _fixed([_card(&"fireball")], [])
	d.board[1][0] = {"card": _card(&"element_earth"), "poise": 20, "fresh": false, "burn": 0}
	d.play(0, 0, 0)
	d.end_turn(0)
	assert(d.board[1][0].poise == 20 - 6 - 2 and d.board[1][0].burn == 1, "Queimadura Solar: −2 no começo do turno do dono")
	print("  ✓ Vantagem de elemento, Mímico, Colmeia, Moeda, Cogumelos e Queimadura")

func test_balance() -> void:
	print("\n[3/4] Equilíbrio: baralho inicial (bot) contra a Taverneira...")
	var wins := [0, 0, 0]
	var rounds := 0
	for i in 300:
		var d := CardDuel.new()
		d.start(CardDuel.build_deck([&"element_earth", &"coin", &"trenchcoat_mushrooms"]), CardDuel.build_deck(TavernTable.HOST_DECK), i)
		var guard := 0
		while not d.is_over() and guard < 100:
			d.ai_turn(d.current)
			guard += 1
		assert(d.is_over(), "Toda partida termina")
		wins[d.winner] += 1
		rounds += d.round_num
	var rate: float = wins[0] / 300.0
	print("  bot inicial vence %d%% · empata %d%% · perde %d%% · %.1f rodadas em média" % [roundi(rate * 100), roundi(wins[2] / 3.0), roundi(wins[1] / 3.0), rounds / 300.0])
	assert(rate > 0.2 and rate < 0.6, "Taverneira desafia mas dá para ganhar jogando como bot")
	print("  ✓ Partidas terminam e a Taverneira é vencível")

func test_table() -> void:
	print("\n[4/4] Mesa: aposta, casa, prêmio de carta e obra pronta...")
	assert(TavernTable.payout(10) == 18 and TavernTable.payout(5) == 9, "2× menos 10% da casa")
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	var table := TavernTable.new()
	root.add_child(table)
	player.wallet.set_money(30)
	assert(table.start_match(player, 7) != "", "Só apostas da lista")
	assert(table.start_match(player, 10) == "" and player.wallet.money == 20, "Aposta sai da carteira")
	table.duel.winner = 0
	var r := table.settle()
	assert(r.money == 18 and player.wallet.money == 38, "Vitória paga 18 por 10")
	assert(r.card != null and r.card.id == &"beehive" and player.card_collection.is_card_unlocked(&"beehive"), "Vitória dá a Colmeia")
	table.start_match(player, 20)
	table.duel.winner = 2
	r = table.settle()
	assert(player.wallet.money == 38 and r.card == null, "Empate devolve e não dá carta")
	table.start_match(player, 5)
	table.duel.winner = 1
	table.settle()
	assert(player.wallet.money == 33, "Derrota perde a aposta")
	print("  ✓ Aposta, corte da casa, prêmio de coleção e empate")
