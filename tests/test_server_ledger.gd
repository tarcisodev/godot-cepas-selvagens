extends SceneTree

## Teste do livro-razão do servidor (B41 fase 1, ADR-0009).
## Valida abrir o livro a partir do save, commit com versão, save e auditoria, recusa registrada,
## retrato aplicado no cliente só quando é mais novo, fechar salvando, e o kit do explorador
## entregue pelo servidor na criação do personagem.

const ServerPersistenceClass = preload("res://scripts/core/server_persistence.gd")
const LedgerServiceClass = preload("res://scripts/net/ledger_service.gd")
const InventoryComponentClass = preload("res://scripts/components/inventory_component.gd")
const WalletComponentClass = preload("res://scripts/components/wallet_component.gd")

const USER := "LivroTester"
const CHAR := "Livro_Alfa"

var _started: bool = false
var _sp
var _ledger

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("📒 TESTANDO O LIVRO-RAZÃO DO SERVIDOR (B41 FASE 1)")
	print("========================================================")

	_sp = root.get_node_or_null("/root/ServerPersistence")
	if _sp == null:
		_sp = ServerPersistenceClass.new()
		_sp.name = "ServerPersistence"
		root.add_child(_sp)
	_ledger = LedgerServiceClass.new()
	root.add_child(_ledger)
	_cleanup()

	_test_starter_kit_from_server()
	_test_open_commit_and_audit()
	_test_reject_is_audited()
	_test_client_applies_only_newer_snapshots()
	_test_close_book_saves()
	_test_serialize_player_keeps_inventory()

	_cleanup()
	_ledger.queue_free()
	print("\n🎉 TODOS OS TESTES DO LIVRO-RAZÃO PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _cleanup() -> void:
	for f in ["%s/%s.json" % [ServerPersistenceClass.ACCOUNTS_DIR, USER.to_lower()], "%s/%s.json" % [ServerPersistenceClass.PLAYERS_DIR, CHAR]]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))

## Jogador falso com as propriedades que o livro usa (inventory e wallet)
func _fake_player() -> Node:
	var s := GDScript.new()
	s.source_code = "extends Node3D\nvar inventory\nvar wallet\n"
	s.reload()
	var p := Node3D.new()
	p.set_script(s)
	var inv := InventoryComponentClass.new()
	var wallet := WalletComponentClass.new()
	p.add_child(inv)
	p.add_child(wallet)
	p.set("inventory", inv)
	p.set("wallet", wallet)
	root.add_child(p)
	return p

func _count(stacks: Array, id: String) -> int:
	var n := 0
	for s in stacks:
		if String(s.get("id", "")) == id:
			n += int(s.get("amount", 0))
	return n

func _test_starter_kit_from_server() -> void:
	print("  1. Verificando kit do explorador entregue pelo servidor...")
	_sp.register_account(USER, "SenhaSegura123!")
	var res: Dictionary = _sp.create_character_for_account(USER, CHAR, {})
	assert(res.get("success", false), "Personagem deve ser criado")
	var data: Dictionary = _sp.load_player_data(CHAR)
	assert(int(data.get("money", 0)) == ServerPersistenceClass.STARTER_MONEY, "Dinheiro inicial vem do servidor")
	var mats: Array = data.get("materials", [])
	assert(_count(mats, "tocha") == 1 and _count(mats, "pocao") == 2 and _count(mats, "laco_fibra") == 2, "Kit do explorador vem do servidor")
	assert(res.get("character", {}).get("materials", []).size() == ServerPersistenceClass.STARTER_MATERIALS.size(), "Resposta da criação leva o kit ao cliente")
	print("     ✓ %d $S e kit gravados na criação" % ServerPersistenceClass.STARTER_MONEY)

func _test_open_commit_and_audit() -> void:
	print("  2. Verificando abrir o livro, commit, save e auditoria...")
	_ledger.open_book(7, CHAR, _sp.load_player_data(CHAR))
	assert(_ledger.has_book(7) and _ledger.version_of(7) == 0, "Livro abre na versão 0")
	assert(_ledger.wallet_of(7).money == ServerPersistenceClass.STARTER_MONEY, "Carteira do livro vem do save")
	assert(_ledger.inventory_of(7).get_material_count(&"pocao") == 2, "Inventário do livro vem do save")

	_ledger.inventory_of(7).add_material(&"madeira", 5)
	_ledger.wallet_of(7).add(30)
	_ledger.commit(7, &"teste_ganho", {"source": "teste", "delta": {"madeira": 5, "money": 30}})
	assert(_ledger.version_of(7) == 1, "Commit sobe a versão")
	var saved: Dictionary = _sp.load_player_data(CHAR)
	assert(int(saved.get("money", 0)) == ServerPersistenceClass.STARTER_MONEY + 30, "Commit salva a carteira")
	assert(_count(saved.get("materials", []), "madeira") == 5, "Commit salva as pilhas")
	var snap: Dictionary = _ledger.snapshot(7)
	assert(int(snap.get("version", -1)) == 1 and int(snap.get("money", 0)) == ServerPersistenceClass.STARTER_MONEY + 30, "Retrato leva versão e saldo")

	var log_path := "%s/%s.log" % [LedgerServiceClass.AUDIT_DIR, Time.get_date_string_from_system()]
	assert(FileAccess.file_exists(log_path), "Auditoria do dia deve existir")
	var lines := FileAccess.get_file_as_string(log_path).strip_edges().split("\n")
	var last: Variant = JSON.parse_string(lines[lines.size() - 1])
	assert(last is Dictionary and last.get("verb") == "teste_ganho" and last.get("char") == CHAR, "Última linha registra o verbo e o personagem")
	assert(int(last.get("money", -1)) == ServerPersistenceClass.STARTER_MONEY + 30, "Auditoria registra o saldo depois da mudança")
	print("     ✓ Versão, save e linha de auditoria a cada commit")

func _test_reject_is_audited() -> void:
	print("  3. Verificando recusa registrada sem mudar o livro...")
	_ledger.reject(7, &"teste_ganho", "fonte_inexistente", {"source": "arvore_fantasma"})
	assert(_ledger.version_of(7) == 1, "Recusa não sobe a versão")
	var log_path := "%s/%s.log" % [LedgerServiceClass.AUDIT_DIR, Time.get_date_string_from_system()]
	var lines := FileAccess.get_file_as_string(log_path).strip_edges().split("\n")
	var last: Variant = JSON.parse_string(lines[lines.size() - 1])
	assert(last is Dictionary and last.get("detail", {}).get("rejected") == "fonte_inexistente", "Recusa vai para a auditoria com o motivo")
	print("     ✓ Recusa auditada")

func _test_client_applies_only_newer_snapshots() -> void:
	print("  4. Verificando retrato aplicado no cliente só quando é mais novo...")
	var p := _fake_player()
	_ledger.client_version = -1
	var snap1: Dictionary = _ledger.snapshot(7)
	assert(_ledger.apply_snapshot(snap1, p), "Primeiro retrato é aplicado")
	assert(p.wallet.money == ServerPersistenceClass.STARTER_MONEY + 30 and p.inventory.get_material_count(&"madeira") == 5, "Cliente espelha o livro")

	p.wallet.set_money(999999)
	assert(not _ledger.apply_snapshot(snap1, p), "Mesmo retrato de novo é ignorado")
	var old := snap1.duplicate(true)
	old["version"] = 0
	old["money"] = 1
	assert(not _ledger.apply_snapshot(old, p), "Retrato velho é ignorado")

	_ledger.wallet_of(7).spend(10)
	_ledger.commit(7, &"teste_gasto", {"money": -10})
	assert(_ledger.apply_snapshot(_ledger.snapshot(7), p), "Retrato novo é aplicado")
	assert(p.wallet.money == ServerPersistenceClass.STARTER_MONEY + 20, "Saldo forjado no cliente volta ao do servidor")
	p.queue_free()
	print("     ✓ Versão manda: o cliente só segue o servidor")

func _test_close_book_saves() -> void:
	print("  5. Verificando fechar o livro salvando...")
	_ledger.inventory_of(7).add_material(&"pedra", 3)
	_ledger.close_book(7)
	assert(not _ledger.has_book(7), "Livro fechado sai da memória")
	assert(_count(_sp.load_player_data(CHAR).get("materials", []), "pedra") == 3, "Fechar salva o que estava no livro")
	print("     ✓ Saída do mundo salva o livro")

func _test_serialize_player_keeps_inventory() -> void:
	print("  6. Verificando save do jogador do host com inventário (antes chamava inv.serialize(), que não existe)...")
	var p := _fake_player()
	p.inventory.load_from_save([])
	p.inventory.add_material(&"couro", 4)
	p.wallet.set_money(77)
	var data := ServerPersistenceClass.serialize_player(p)
	assert(_count(data.get("materials", []), "couro") == 4, "serialize_player grava as pilhas")
	assert(data.get("gear") is Dictionary, "serialize_player grava as peças")
	var q := _fake_player()
	ServerPersistenceClass.apply_player_data(q, JSON.parse_string(JSON.stringify(data)))
	assert(q.inventory.get_material_count(&"couro") == 4 and q.wallet.money == 77, "apply_player_data recarrega pilhas e carteira")
	p.queue_free()
	q.queue_free()
	print("     ✓ Inventário do host salvo e recarregado")
