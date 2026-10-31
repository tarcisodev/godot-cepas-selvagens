extends SceneTree

## Teste dos pedidos do livro-razão (B41 fase 2, ADR-0009).
## Valida que quantidade negativa não cria item, que o servidor refaz primitivas e trocas no livro
## (craft, forja, cozinha, espeto com teto de qualidade, desmanche, fundição), que pedido recusado
## também devolve o ack, e que no cliente online o gasto vira pedido e o retrato só entra com tudo confirmado.

const LedgerServiceClass = preload("res://scripts/net/ledger_service.gd")
const LedgerVerbsClass = preload("res://scripts/net/ledger_verbs.gd")
const LedgerExchangesClass = preload("res://scripts/net/ledger_exchanges.gd")
const InventoryComponentClass = preload("res://scripts/components/inventory_component.gd")
const WalletComponentClass = preload("res://scripts/components/wallet_component.gd")
const ForgeClass = preload("res://scripts/systems/forge.gd")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🧾 TESTANDO OS PEDIDOS DO LIVRO-RAZÃO (B41 FASE 2)")
	print("========================================================")

	_test_negative_amounts_never_create_items()
	_test_server_replays_primitives_with_ack()
	_test_server_replays_exchanges()
	_test_client_routes_spends_and_reconciles()

	print("\n🎉 TODOS OS TESTES DOS PEDIDOS DO LIVRO PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _book() -> Array:
	var inv := InventoryComponentClass.new()
	var wallet := WalletComponentClass.new()
	root.add_child(inv)
	root.add_child(wallet)
	inv.load_from_save([])
	return [inv, wallet]

## Rede falsa: cliente online (não autoritativo) que guarda os pedidos mandados
func _fake_client_net() -> Node:
	var s := GDScript.new()
	s.source_code = "extends Node\nvar sent: Array = []\nfunc is_server_authoritative() -> bool:\n\treturn false\nfunc send_ledger_request(seq: int, verb: StringName, args: Dictionary) -> void:\n\tsent.append([seq, verb, args])\nfunc push_ledger(_p: int, _s: Dictionary) -> void:\n\tpass\n"
	s.reload()
	var n := Node.new()
	n.set_script(s)
	root.add_child(n)
	return n

func _test_negative_amounts_never_create_items() -> void:
	print("  1. Verificando que quantidade negativa não cria item...")
	var b := _book()
	var inv: InventoryComponent = b[0]
	inv.add_material(&"madeira", 2)
	assert(not inv.consume_materials({&"madeira": -5}), "Consumir negativo deve falhar")
	assert(inv.get_material_count(&"madeira") == 2, "Consumir negativo não pode somar madeira")
	assert(not inv.consume_stack(inv.get_stacks(&"madeira")[0], -3), "Pilha com quantidade negativa deve falhar")
	assert(inv.get_material_count(&"madeira") == 2, "Pilha negativa não pode somar madeira")
	assert(not LedgerVerbsClass.succeeded(LedgerVerbsClass.execute(&"consume_materials", inv, b[1], {"req": {"madeira": -5}})), "Servidor recusa quantidade negativa")
	assert(not LedgerVerbsClass.succeeded(LedgerVerbsClass.execute(&"consume_materials", inv, b[1], {"req": {"madeira": 99999}})), "Servidor recusa quantidade acima do teto")
	assert(not LedgerVerbsClass.succeeded(LedgerVerbsClass.execute(&"spend", inv, b[1], {"amount": -100})), "Gasto negativo é recusado")
	assert(b[1].money == WalletComponentClass.STARTING_MONEY, "Gasto negativo não mexe no saldo")
	print("     ✓ Negativos e acima do teto são recusados")

func _test_server_replays_primitives_with_ack() -> void:
	print("  2. Verificando primitivas refeitas no livro com ack...")
	var ledger = LedgerServiceClass.new()
	root.add_child(ledger)
	ledger.open_book(5, "Pedidos_Teste", {"money": 100, "materials": [{"id": "pocao", "quality": 1, "traits": [], "amount": 3}]})
	# Sem ServerPersistence o save falha em silêncio; o que importa aqui é o livro
	assert(ledger.handle_request(5, 1, &"consume_materials", {"req": {"pocao": 1}}), "Consumo válido passa")
	assert(ledger.inventory_of(5).get_material_count(&"pocao") == 2 and ledger.version_of(5) == 1, "Livro gasta e sobe a versão")
	assert(not ledger.handle_request(5, 2, &"spend", {"amount": 500}), "Gasto acima do saldo é recusado")
	assert(ledger.wallet_of(5).money == 100 and ledger.version_of(5) == 1, "Recusa não mexe no livro")
	assert(int(ledger.snapshot(5).get("ack", 0)) == 2, "Recusa também confirma o pedido (ack) para o cliente desfazer")
	assert(not ledger.handle_request(5, 3, &"dar_ouro_infinito", {}), "Verbo desconhecido é recusado")
	assert(not ledger.handle_request(5, 4, &"consume_materials", {"req": {"pocao": 1}}, false), "Pedido acima do teto de mensagens é descartado")
	assert(ledger.inventory_of(5).get_material_count(&"pocao") == 2 and int(ledger.snapshot(5).ack) == 4, "Descartado não mexe, mas confirma")
	ledger.close_book(5, false)
	ledger.queue_free()
	print("     ✓ Livro aplica o válido, recusa o resto e sempre devolve o ack")

func _test_server_replays_exchanges() -> void:
	print("  3. Verificando trocas refeitas pelo servidor...")
	var b := _book()
	var inv: InventoryComponent = b[0]
	var wallet: WalletComponent = b[1]

	# Craft simples
	inv.add_material(&"galho", 2)
	inv.add_material(&"fibra", 1)
	assert(LedgerVerbsClass.succeeded(LedgerVerbsClass.execute(&"craft", inv, wallet, {"recipe": "tocha"})), "Craft de tocha no livro")
	assert(inv.get_material_count(&"tocha") == 1 and inv.get_material_count(&"galho") == 0, "Craft gasta e entrega")
	assert(not LedgerVerbsClass.succeeded(LedgerVerbsClass.execute(&"craft", inv, wallet, {"recipe": "espada_lendaria"})), "Receita inexistente é recusada")

	# Espeto: o cliente pede 5★ de carne mal passada; o servidor limita à qualidade da carne
	inv.add_material(&"carne_crua", 1, 1)
	var meat := InventoryComponentClass.stack_key(inv.get_stacks(&"carne_crua")[0])
	assert(LedgerVerbsClass.succeeded(LedgerVerbsClass.execute(&"roast", inv, wallet, {"meat": meat, "result": "carne_mal_passada", "q": 5})), "Espeto no livro")
	assert(inv.get_stacks(&"carne_mal_passada")[0].quality == 1, "Qualidade pedida acima do teto é cortada")
	assert(not LedgerVerbsClass.succeeded(LedgerVerbsClass.execute(&"roast", inv, wallet, {"meat": meat, "result": "carne_mal_passada", "q": 1})), "Sem carne crua não há espeto")
	assert(not LedgerVerbsClass.succeeded(LedgerVerbsClass.execute(&"roast", inv, wallet, {"meat": meat, "result": "barra_de_ouro", "q": 1})), "Resultado fora da lista é recusado")

	# Forja de verdade com as pilhas do livro (o cliente manda só as chaves)
	var recipe_id: StringName = ForgeClass.RECIPES.keys()[0]
	var r: Dictionary = ForgeClass.RECIPES[recipe_id]
	inv.add_material(r.core[0].id, int(r.core[0].n), 2)
	inv.add_material(r.coat[0].id, int(r.coat[0].n), 2)
	var args := {
		"recipe": String(recipe_id),
		"core": InventoryComponentClass.stack_key(inv.get_stacks(r.core[0].id)[0]),
		"coat": InventoryComponentClass.stack_key(inv.get_stacks(r.coat[0].id)[0]),
		"temper": {}, "level": 9999, "public": false, "temper_ok": false, "crit": 5.0,
	}
	var items_before := inv.items.size()
	assert(LedgerVerbsClass.succeeded(LedgerVerbsClass.execute(&"forge", inv, wallet, args)), "Forja no livro")
	assert(inv.items.size() == items_before + 1, "Peça forjada entra no livro")
	assert(not LedgerVerbsClass.succeeded(LedgerVerbsClass.execute(&"forge", inv, wallet, args)), "Sem material não forja de novo")

	# Desmanche pelo índice
	assert(LedgerVerbsClass.succeeded(LedgerVerbsClass.execute(&"salvage", inv, wallet, {"index": items_before})), "Desmanche no livro")
	assert(inv.items.size() == items_before, "Peça sai do livro no desmanche")
	assert(not LedgerVerbsClass.succeeded(LedgerVerbsClass.execute(&"salvage", inv, wallet, {"index": 42})), "Índice inexistente é recusado")

	inv.queue_free()
	wallet.queue_free()
	print("     ✓ Craft, espeto com teto, forja e desmanche refeitos no livro")

func _test_client_routes_spends_and_reconciles() -> void:
	print("  4. Verificando o cliente online: previsão, pedido e retrato...")
	var net := _fake_client_net()
	var ledger = LedgerServiceClass.new()
	ledger.net = net
	root.add_child(ledger)

	var b := _book()
	var inv: InventoryComponent = b[0]
	var wallet: WalletComponent = b[1]
	inv.ledger = ledger
	wallet.ledger = ledger
	inv.add_material(&"pocao", 3)
	wallet.set_money(100)

	assert(inv.consume_materials({&"pocao": 1}), "Gasto local acontece na hora (previsão)")
	assert(inv.get_material_count(&"pocao") == 2, "Previsão aplicada no cliente")
	assert(net.sent.size() == 1 and net.sent[0][1] == &"consume_materials", "Gasto vira pedido ao servidor")
	assert(wallet.spend(30) and net.sent.size() == 2 and net.sent[1][1] == &"spend", "Gastar dinheiro vira pedido")
	assert(not wallet.spend(999) and net.sent.size() == 2, "Gasto que falha aqui nem é mandado")
	wallet.add(50)
	assert(net.sent.size() == 2, "Ganho não vira pedido de primitiva (vem de verbo com fonte, fase 3)")
	assert(inv.drop_stack(inv.get_stacks(&"pocao")[0], 1).is_empty() and inv.get_material_count(&"pocao") == 2, "Soltar no chão fica desligado no online")
	assert(LedgerExchangesClass.roast(inv, {}, &"carne_mal_passada", 1) == false and net.sent.size() == 2, "Troca que falha local não é mandada")

	# Retrato com ack atrasado não desfaz a previsão; com tudo confirmado, o servidor manda
	var holder := Node3D.new()
	var s := GDScript.new()
	s.source_code = "extends Node3D\nvar inventory\nvar wallet\n"
	s.reload()
	holder.set_script(s)
	holder.set("inventory", inv)
	holder.set("wallet", wallet)
	root.add_child(holder)
	var stale := {"version": 1, "ack": 1, "money": 100, "materials": [{"id": "pocao", "quality": 1, "traits": [], "amount": 2}], "gear": {}}
	assert(not ledger.apply_snapshot(stale, holder), "Retrato sem confirmar todos os pedidos não é aplicado")
	var final := {"version": 2, "ack": 2, "money": 70, "materials": [{"id": "pocao", "quality": 1, "traits": [], "amount": 2}], "gear": {}}
	assert(ledger.apply_snapshot(final, holder), "Retrato com todos os pedidos confirmados é aplicado")
	assert(wallet.money == 70, "Ganho local sem fonte some: o saldo é o do servidor")
	assert(net.sent.size() == 2, "Aplicar o retrato não gera pedidos")

	holder.queue_free()
	ledger.queue_free()
	net.queue_free()
	print("     ✓ Gasto vira pedido, ganho local não vale, retrato manda")
