extends SceneTree

## Teste das fontes de ganho do livro-razão (B41 fase 3, ADR-0009).
## Valida que no cliente online o ganho só vai ao servidor dentro de uma fonte (com os gastos juntos),
## e que o servidor recusa e audita ganho forjado: item fora da fonte, acima do teto, recurso fora da
## semente ou longe do jogador, recarga, baú repetido, troca sem pagamento, cofre vazio e teto por hora.
## Recusas demais na hora derrubam a sessão.

const LedgerServiceClass = preload("res://scripts/net/ledger_service.gd")
const LedgerSourcesClass = preload("res://scripts/net/ledger_sources.gd")
const InventoryComponentClass = preload("res://scripts/components/inventory_component.gd")
const WalletComponentClass = preload("res://scripts/components/wallet_component.gd")
const GatherableSpawnerClass = preload("res://scripts/gatherable_spawner.gd")
const GatherableResourceClass = preload("res://scripts/gatherable_resource.gd")
const LandscapeClass = preload("res://scripts/landscape_generator.gd")

const PEER := 7

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🪙 TESTANDO AS FONTES DE GANHO DO LIVRO (B41 FASE 3)")
	print("========================================================")

	_test_client_collects_sources()
	_test_forged_gains_rejected_and_audited()
	_test_gather_by_seed_and_recharge()
	_test_trades_and_escrow()
	_test_once_hour_cap_and_kick()
	_test_seed_list_matches_real_spawner()

	print("\n🎉 TODOS OS TESTES DAS FONTES DE GANHO PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

## Rede falsa: `client` = cliente online que guarda os pedidos; senão servidor com posição e expulsão
func _fake_net(client: bool) -> Node:
	var s := GDScript.new()
	s.source_code = "extends Node\nvar client: bool = %s\nvar sent: Array = []\nvar kicked: Array = []\nvar pos: Variant = null\nfunc is_server_authoritative() -> bool:\n\treturn not client\nfunc send_ledger_request(seq: int, verb: StringName, args: Dictionary) -> void:\n\tsent.append([seq, verb, args])\nfunc push_ledger(_p: int, _s: Dictionary) -> void:\n\tpass\nfunc player_position(_p: int) -> Variant:\n\treturn pos\nfunc disconnect_peer_safe(p: int) -> void:\n\tkicked.append(p)\n" % ("true" if client else "false")
	s.reload()
	var n := Node.new()
	n.set_script(s)
	root.add_child(n)
	return n

func _server(net: Node, money: int = 100, materials: Array = []) -> Node:
	var ledger = LedgerServiceClass.new()
	ledger.net = net
	root.add_child(ledger)
	ledger.open_book(PEER, "Fontes_Teste", {"money": money, "materials": materials})
	return ledger

func _source(ledger: Node, seq: int, kind: String, source: String, extra: Dictionary = {}) -> bool:
	var args := {"kind": kind, "source": source, "steps": [], "items": [], "gear": [], "money": 0}
	args.merge(extra, true)
	return ledger.handle_request(PEER, seq, &"source", args)

func _test_client_collects_sources() -> void:
	print("  1. Verificando o cliente: ganho vai ao servidor só dentro de uma fonte...")
	var net := _fake_net(true)
	var ledger = LedgerServiceClass.new()
	ledger.net = net
	root.add_child(ledger)
	var inv := InventoryComponentClass.new()
	var wallet := WalletComponentClass.new()
	root.add_child(inv)
	root.add_child(wallet)
	inv.load_from_save([])
	inv.ledger = ledger
	wallet.ledger = ledger
	wallet.set_money(100)

	# Compra na loja: o gasto e o item vão no mesmo pedido `source`
	var ok = ledger.gain(&"shop", "pocao", func():
		if not wallet.spend(15):
			return false
		inv.add_material(&"pocao", 1)
		return true)
	assert(ok and inv.get_material_count(&"pocao") == 1 and wallet.money == 85, "Previsão local da compra")
	assert(net.sent.size() == 1 and net.sent[0][1] == &"source", "Compra vira um pedido de fonte só")
	var req: Dictionary = net.sent[0][2]
	assert(req.kind == "shop" and req.steps.size() == 1 and req.steps[0][0] == "spend" and req.items.size() == 1, "Pedido leva o gasto e o ganho")

	# Ganho fora de fonte: aplica localmente (vai sumir no retrato) e não manda nada
	inv.add_material(&"madeira", 99)
	wallet.add(500)
	assert(net.sent.size() == 1, "Ganho sem fonte não vira pedido")

	# Fonte que não fez nada não manda pedido; fonte dentro de fonte entra na de fora
	ledger.gain(&"chest", "vazio", func(): return false)
	assert(net.sent.size() == 1, "Fonte vazia não manda pedido")
	ledger.gain(&"chest", "fora", func():
		wallet.add(10)
		ledger.gain(&"chest", "dentro", func(): inv.add_material(&"oleo_peixe", 2, 3)))
	assert(net.sent.size() == 2 and int(net.sent[1][2].money) == 10 and net.sent[1][2].items.size() == 1, "Fonte aninhada vai junto na de fora")

	inv.queue_free()
	wallet.queue_free()
	ledger.queue_free()
	net.queue_free()
	print("     ✓ Fonte junta gasto e ganho; ganho sem fonte não é mandado")

func _test_forged_gains_rejected_and_audited() -> void:
	print("  2. Verificando ganho forjado recusado e no log de auditoria...")
	var net := _fake_net(false)
	var ledger := _server(net)
	var inv: InventoryComponent = ledger.inventory_of(PEER)
	var wallet: WalletComponent = ledger.wallet_of(PEER)

	assert(_source(ledger, 1, "skin", "Cervo", {"items": [{"id": "couro_trotador", "n": 2, "q": 2, "traits": []}]}), "Esfola honesta passa")
	assert(inv.get_material_count(&"couro_trotador") == 2 and ledger.version_of(PEER) == 1, "Livro entrega a esfola")

	assert(not _source(ledger, 2, "skin", "Cervo", {"items": [{"id": "couro_trotador", "n": 500, "q": 5, "traits": []}]}), "Quantidade forjada é recusada")
	assert(not _source(ledger, 3, "fishing", "Lambari", {"items": [{"id": "ambar_estelar", "n": 1, "q": 1, "traits": []}]}), "Item fora da fonte é recusado")
	assert(not _source(ledger, 4, "fishing", "Lambari", {"items": [{"id": "peixe_lambari", "n": 1, "q": 5, "traits": []}]}), "Qualidade acima do teto é recusada")
	assert(not _source(ledger, 5, "caravan", "c1", {"money": 99999}), "Dinheiro acima do teto é recusado")
	assert(not _source(ledger, 6, "dar_ouro", "x", {"money": 10}), "Fonte desconhecida é recusada")
	assert(not _source(ledger, 7, "skin", "Cervo", {"gear": [{"recipe_id": "espada_ferro", "quality": 5}]}), "Peça forjada em fonte sem peça é recusada")
	assert(not _source(ledger, 8, "skin", "Cervo", {"items": [{"id": "couro_trotador", "n": -5, "q": 1, "traits": []}]}), "Quantidade negativa é recusada")
	assert(inv.get_material_count(&"couro_trotador") == 2 and wallet.money == 100 and ledger.version_of(PEER) == 1, "Recusas não mexem no livro")
	assert(int(ledger.snapshot(PEER).ack) == 8, "Toda recusa devolve o ack")

	# O log do dia tem a recusa com o motivo
	var path := "%s/%s.log" % [LedgerServiceClass.AUDIT_DIR, Time.get_date_string_from_system()]
	var text := FileAccess.get_file_as_string(path)
	assert(text.contains("\"rejected\":\"acima_do_teto\"") and text.contains("Fontes_Teste"), "Recusa aparece no log de auditoria")
	assert(text.contains("\"rejected\":\"fonte_desconhecida\""), "Fonte desconhecida aparece no log")

	ledger.close_book(PEER, false)
	ledger.queue_free()
	net.queue_free()
	print("     ✓ Ganho forjado recusado, livro intacto e recusa auditada")

func _test_gather_by_seed_and_recharge() -> void:
	print("  3. Verificando coleta pela semente, distância e recarga...")
	# Lista da semente sem relevo (nos dois lados): o servidor monta e o teste pega um recurso real
	LedgerSourcesClass.build_gather_spots(null)
	var sp = GatherableSpawnerClass.new()
	sp.dry_run = true
	sp.spawn_all_resources_seeded()
	var spot: Dictionary = {}
	for s in sp.spots:
		if s.type == GatherableResourceClass.Type.MADEIRA:
			spot = s
			break
	sp.free()
	assert(not spot.is_empty(), "A semente gera madeira")
	var at: Vector3 = spot.pos
	var key := LedgerSourcesClass.spot_key(at)
	var wood := {"items": [{"id": "madeira", "n": 2, "q": 1, "traits": []}], "at": at}

	var net := _fake_net(false)
	var ledger := _server(net)
	var inv: InventoryComponent = ledger.inventory_of(PEER)
	net.pos = at + Vector3(2, 0, 0)

	assert(_source(ledger, 1, "gather", key, wood), "Madeira da semente perto do jogador passa")
	assert(inv.get_material_count(&"madeira") == 2, "Livro entrega a madeira")
	assert(not _source(ledger, 2, "gather", key, wood), "Mesmo tronco antes de voltar é recusado (recarga)")
	ledger.clock_offset_msec += 60 * 1000
	assert(_source(ledger, 3, "gather", key, wood), "Depois da recarga o tronco volta")

	var fake_at := at + Vector3(37.3, 0, 41.9)
	net.pos = fake_at
	assert(not _source(ledger, 4, "gather", LedgerSourcesClass.spot_key(fake_at), {"items": wood.items, "at": fake_at}), "Recurso fora da semente é recusado")
	net.pos = at + Vector3(80, 0, 0)
	ledger.clock_offset_msec += 60 * 1000
	assert(not _source(ledger, 5, "gather", key, wood), "Recurso longe do jogador é recusado")
	net.pos = at
	assert(not _source(ledger, 6, "gather", key, {"items": [{"id": "madeira", "n": 9, "q": 1, "traits": []}], "at": at}), "Mais madeira que o tronco dá é recusada")
	assert(not _source(ledger, 7, "gather", key, {"items": [{"id": "madeira", "n": 2, "q": 5, "traits": []}], "at": at}), "Qualidade acima da coleta é recusada")
	assert(not _source(ledger, 8, "gather", key, {"items": wood.items}), "Coleta sem posição é recusada")
	assert(inv.get_material_count(&"madeira") == 4, "Só as duas coletas válidas entraram")

	LedgerSourcesClass.clear_gather_spots()
	ledger.close_book(PEER, false)
	ledger.queue_free()
	net.queue_free()
	print("     ✓ Semente, distância, teto e recarga conferidos no servidor")

func _test_trades_and_escrow() -> void:
	print("  4. Verificando trocas e cofres...")
	var net := _fake_net(false)
	var ledger := _server(net, 100, [{"id": "ossos", "quality": 1, "traits": [], "amount": 4}])
	var inv: InventoryComponent = ledger.inventory_of(PEER)
	var wallet: WalletComponent = ledger.wallet_of(PEER)

	# Loja: paga e recebe; sem pagar, recusa
	assert(_source(ledger, 1, "shop", "pocao", {"steps": [["spend", {"amount": 15}]], "items": [{"id": "pocao", "n": 1, "q": 1, "traits": []}]}), "Compra paga passa")
	assert(wallet.money == 85 and inv.get_material_count(&"pocao") == 1, "Livro cobra e entrega")
	assert(not _source(ledger, 2, "shop", "pocao", {"items": [{"id": "pocao", "n": 1, "q": 1, "traits": []}]}), "Compra sem pagar é recusada")
	assert(not _source(ledger, 3, "shop", "pocao", {"steps": [["spend", {"amount": 5000}]], "items": [{"id": "pocao", "n": 1, "q": 1, "traits": []}]}), "Compra sem saldo é recusada")
	assert(wallet.money == 85 and inv.get_material_count(&"pocao") == 1, "Recusa desfaz o gasto do bloco")

	# Venda: o que paga não passa do valor do que foi dado
	var bone_value := LedgerSourcesClass.material_value(&"ossos", 1)
	assert(not _source(ledger, 4, "sale", "npc", {"steps": [["consume_materials", {"req": {"ossos": 1}}]], "money": bone_value * 3 + LedgerSourcesClass.DEFAULT_FREE + 50}), "Venda acima do valor é recusada")
	assert(inv.get_material_count(&"ossos") == 4, "Venda recusada devolve os ossos")
	assert(_source(ledger, 5, "sale", "npc", {"steps": [["consume_materials", {"req": {"ossos": 1}}]], "money": maxi(1, bone_value)}), "Venda pelo valor passa")
	assert(inv.get_material_count(&"ossos") == 3, "Venda gasta os ossos")

	# Cofre da taverna: aposta entra, prêmio sai até 2×; sem aposta, nada
	assert(not _source(ledger, 6, "tavern", "", {"money": 20}), "Prêmio sem aposta é recusado")
	assert(_source(ledger, 7, "tavern_bet", "10", {"steps": [["spend", {"amount": 10}]]}), "Aposta entra no cofre")
	assert(not _source(ledger, 8, "tavern", "", {"money": 21}), "Prêmio acima de 2× a aposta é recusado")
	assert(_source(ledger, 9, "tavern", "", {"money": 18}), "Prêmio dentro do cofre passa")
	assert(not _source(ledger, 10, "tavern", "", {"money": 18}), "Cofre esvaziado não paga de novo")

	ledger.close_book(PEER, false)
	ledger.queue_free()
	net.queue_free()
	print("     ✓ Trocas conferidas pelo valor e cofres limitados ao que entrou")

func _test_once_hour_cap_and_kick() -> void:
	print("  5. Verificando baú único, teto por hora e desconexão...")
	var net := _fake_net(false)
	var ledger := _server(net)
	var wallet: WalletComponent = ledger.wallet_of(PEER)
	net.pos = Vector3.ZERO

	var chest := {"money": 35, "items": [{"id": "oleo_peixe", "n": 2, "q": 3, "traits": ["puro"]}], "at": Vector3(1, 0, 1)}
	assert(_source(ledger, 1, "chest", "wild_chest_1", chest), "Baú abre uma vez")
	assert(not _source(ledger, 2, "chest", "wild_chest_1", chest), "Mesmo baú de novo é recusado")
	assert(ledger.snapshot(PEER).money == 135, "Só o primeiro baú pagou")
	# O uso único vai para o save do personagem
	assert(ledger._books[PEER].meta.once.has("chest|wild_chest_1"), "Baú aberto fica marcado no livro")

	# Teto por hora: caravana aceita 10 por hora
	var seq := 3
	for i in 10:
		assert(_source(ledger, seq, "caravan", "c%d" % i, {"money": 40}), "Caravana %d dentro do teto" % i)
		seq += 1
	assert(not _source(ledger, seq, "caravan", "c11", {"money": 40}), "Caravana acima do teto por hora é recusada")
	seq += 1
	ledger.clock_offset_msec += LedgerServiceClass.HOUR_MSEC
	assert(_source(ledger, seq, "caravan", "c12", {"money": 40}), "Na hora seguinte volta a valer")
	seq += 1
	assert(wallet.money == 135 + 11 * 40, "Pagou só as caravanas dentro do teto")

	# 20 recusas na hora derrubam a sessão
	assert(net.kicked.is_empty(), "Ninguém foi derrubado ainda")
	for i in LedgerServiceClass.STRIKES_TO_KICK:
		_source(ledger, seq, "skin", "x", {"items": [{"id": "madeira", "n": 9999, "q": 5, "traits": []}]})
		seq += 1
	assert(net.kicked == [PEER], "Recusas demais na hora desconectam o peer")

	ledger.close_book(PEER, false)
	ledger.queue_free()
	net.queue_free()
	print("     ✓ Baú único, teto por hora e desconexão por abuso")

func _test_seed_list_matches_real_spawner() -> void:
	print("  6. Verificando que a lista do servidor bate com o spawner de verdade...")
	# Relevo de verdade (fora da árvore: só a função de altura) e o spawner do mundo criando os nós
	var land = LandscapeClass.new()
	LedgerSourcesClass.build_gather_spots(land)
	var sp = GatherableSpawnerClass.new()
	sp.landscape = land
	sp.spawn_all_resources_seeded()
	var total := 0
	for g in sp.get_children():
		assert(g.seeded, "Recurso do spawner sai marcado como da semente")
		assert(LedgerSourcesClass.is_seeded_spot(g.material_id, g.position), "Recurso %s em %s está na lista do servidor" % [g.type, g.position])
		total += 1
	assert(total > 300, "O spawner cria os recursos do mapa (%d)" % total)
	sp.free()
	land.free()
	LedgerSourcesClass.clear_gather_spots()
	print("     ✓ %d recursos do spawner conferem com a lista do servidor" % total)
