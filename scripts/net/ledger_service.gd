class_name LedgerServiceAutoload
extends Node

const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const _WalletComponent = preload("res://scripts/components/wallet_component.gd")
const _StatsComponent = preload("res://scripts/components/stats_component.gd")
const _LedgerVerbs = preload("res://scripts/net/ledger_verbs.gd")

## Livro-razão do servidor (ADR-0009, B41 fase 1).
## O servidor é dono do inventário e da carteira de cada personagem no mundo: um "livro" por peer,
## com um InventoryComponent e um WalletComponent fora da árvore do jogador. Toda mudança passa por
## `commit()`, que sobe a versão, grava uma linha de auditoria, salva e manda o retrato ao dono.
## No host, o livro do próprio jogador são os componentes do Player (não há cópia).
## No cliente, o livro não existe: o retrato chega por rede e é aplicado no Player (somente leitura).

const AUDIT_DIR: String = "user://server_saves/audit"

## Retrato aplicado no cliente (versão nova)
signal snapshot_applied(version: int)

## peer_id -> {"name", "holder": Node, "inventory", "wallet", "version", "own": bool}
var _books: Dictionary = {}
## Última versão aplicada no cliente (retratos fora de ordem são ignorados)
var client_version: int = -1
## Cliente: pedidos mandados e o último que o servidor confirmou (ack). Enquanto houver pedido
## sem resposta, o retrato não é aplicado: a previsão local ainda não chegou ao servidor.
var sent_seq: int = 0
var client_ack: int = 0
## > 0 enquanto um verbo roda localmente (as primitivas chamadas por dentro não viram pedidos)
var _suspended: int = 0
## NetworkManager que entrega os retratos (o autoload; os testes de rede usam um por subárvore)
var net: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if net == null:
		net = get_node_or_null("/root/NetworkManager")
	if net != null and net.has_signal("peer_left"):
		net.peer_left.connect(close_book)

## Abre o livro de um peer a partir do save do personagem (`pdata`, como sai de load_player_data)
func open_book(peer_id: int, char_name: String, pdata: Dictionary) -> void:
	close_book(peer_id, false)
	var holder := Node.new()
	holder.name = "Book_%d" % peer_id
	add_child(holder)
	var stats := _StatsComponent.new()
	stats.name = "StatsComponent"
	holder.add_child(stats)
	var inv := _InventoryComponent.new()
	inv.name = "InventoryComponent"
	inv.stats = stats
	holder.add_child(inv)
	var wallet := _WalletComponent.new()
	wallet.name = "WalletComponent"
	holder.add_child(wallet)
	load_into(inv, wallet, pdata)
	_books[peer_id] = {"name": char_name, "holder": holder, "inventory": inv, "wallet": wallet, "version": 0, "own": false}

## Livro do jogador do próprio host: usa os componentes do Player, sem cópia
func open_own_book(peer_id: int, char_name: String, player: Node) -> void:
	var inv = player.get("inventory") if player else null
	var wallet = player.get("wallet") if player else null
	if inv == null or wallet == null:
		return
	close_book(peer_id, false)
	_books[peer_id] = {"name": char_name, "holder": null, "inventory": inv, "wallet": wallet, "version": 0, "own": true}

## Salva e fecha o livro (ao sair do mundo ou trocar de personagem)
func close_book(peer_id: int, save: bool = true) -> void:
	if not _books.has(peer_id):
		return
	if save:
		save_book(peer_id)
	var holder: Node = _books[peer_id].get("holder")
	if holder != null and is_instance_valid(holder):
		holder.queue_free()
	_books.erase(peer_id)

func has_book(peer_id: int) -> bool:
	return _books.has(peer_id)

func inventory_of(peer_id: int) -> InventoryComponent:
	return _books[peer_id].inventory if _books.has(peer_id) else null

func wallet_of(peer_id: int) -> WalletComponent:
	return _books[peer_id].wallet if _books.has(peer_id) else null

func version_of(peer_id: int) -> int:
	return int(_books[peer_id].version) if _books.has(peer_id) else -1

## Fecha uma mudança já feita no livro: versão, auditoria, save e retrato para o dono.
## `verb` é o que o jogador fez (ex.: &"craft"); `detail` vai para o log (fonte, receita, delta...).
func commit(peer_id: int, verb: StringName, detail: Dictionary = {}) -> void:
	if not _books.has(peer_id):
		return
	var book: Dictionary = _books[peer_id]
	book.version = int(book.version) + 1
	audit(String(book.name), verb, detail, book.wallet.money)
	save_book(peer_id)
	_push_snapshot(peer_id)

## Recusa registrada (pedido fora do plausível ou sem saldo); não muda o livro
func reject(peer_id: int, verb: StringName, reason: String, detail: Dictionary = {}) -> void:
	var name: String = _books[peer_id].name if _books.has(peer_id) else "peer_%d" % peer_id
	var d := detail.duplicate()
	d["rejected"] = reason
	audit(name, verb, d, -1)

## Retrato completo do livro (o que vai pela rede e o que o save guarda)
func snapshot(peer_id: int) -> Dictionary:
	if not _books.has(peer_id):
		return {}
	var book: Dictionary = _books[peer_id]
	var snap := to_save_fields(book.inventory, book.wallet)
	snap["version"] = book.version
	snap["ack"] = int(book.get("ack", 0))
	return snap

func save_book(peer_id: int) -> bool:
	var sp := get_node_or_null("/root/ServerPersistence")
	if sp == null or not _books.has(peer_id):
		return false
	var book: Dictionary = _books[peer_id]
	return sp.update_player_data(String(book.name), to_save_fields(book.inventory, book.wallet))

## Manda o retrato atual ao dono (o host aplica direto: o livro dele já é o Player)
func send_snapshot(peer_id: int) -> void:
	_push_snapshot(peer_id)

func _push_snapshot(peer_id: int) -> void:
	if not _books.has(peer_id) or _books[peer_id].own:
		return
	if net != null and net.has_method("push_ledger"):
		net.push_ledger(peer_id, snapshot(peer_id))

## Cliente: aplica no Player o retrato que veio do servidor.
## Só aplica quando o servidor já respondeu a todos os pedidos mandados (ack) e o retrato é novo
## (versão maior, ou mesma versão com ack maior: pedido recusado que precisa desfazer a previsão).
func apply_snapshot(snap: Dictionary, player: Node) -> bool:
	var version := int(snap.get("version", -1))
	var ack := int(snap.get("ack", 0))
	if player == null or ack < sent_seq:
		return false
	if version < client_version or (version == client_version and ack <= client_ack):
		return false
	var inv = player.get("inventory")
	var wallet = player.get("wallet")
	if inv == null or wallet == null:
		return false
	client_version = version
	client_ack = ack
	_suspended += 1
	load_into(inv, wallet, snap)
	_suspended -= 1
	snapshot_applied.emit(version)
	return true

## Novo mundo: zera a contagem de versões e pedidos do cliente
func reset_client() -> void:
	client_version = -1
	client_ack = 0
	sent_seq = 0

# ---------------------------------------------------------------- pedidos (B41 fase 2)

## O componente do jogador local manda a mudança ao servidor? Só no cliente online e fora de um verbo.
func should_route() -> bool:
	return _suspended == 0 and net != null and net.has_method("is_server_authoritative") and not net.is_server_authoritative()

## Roda um verbo: localmente (previsão no cliente; a regra de verdade no host) e, no cliente online,
## manda o pedido ao servidor se deu certo aqui. `local` é o corpo da primitiva no componente;
## sem ele, roda o verbo de LedgerVerbs nos componentes do Player.
func run(verb: StringName, args: Dictionary, local: Callable = Callable()) -> Variant:
	var routing := should_route()
	_suspended += 1
	var result: Variant
	if local.is_valid():
		result = local.call()
	else:
		var p := _local_player()
		result = _LedgerVerbs.execute(verb, p.get("inventory") if p else null, p.get("wallet") if p else null, args)
	_suspended -= 1
	if routing and _LedgerVerbs.succeeded(result):
		sent_seq += 1
		net.send_ledger_request(sent_seq, verb, args)
	return result

func _local_player() -> Node:
	return get_tree().get_first_node_in_group("player") if is_inside_tree() else null

## Servidor: refaz o pedido no livro do peer. Sempre responde com o retrato e o ack,
## para o cliente desfazer a previsão quando o pedido for recusado ou descartado.
func handle_request(peer_id: int, seq: int, verb: StringName, args: Dictionary, allowed: bool = true) -> bool:
	if not _books.has(peer_id):
		return false
	var book: Dictionary = _books[peer_id]
	book.ack = maxi(int(book.get("ack", 0)), seq)
	if not allowed:
		reject(peer_id, verb, "limite_de_mensagens", {})
		_push_snapshot(peer_id)
		return false
	if not _LedgerVerbs.is_known(verb):
		reject(peer_id, verb, "verbo_desconhecido", {})
		_push_snapshot(peer_id)
		return false
	var result: Variant = _LedgerVerbs.execute(verb, book.inventory, book.wallet, args)
	if _LedgerVerbs.succeeded(result):
		commit(peer_id, verb, args)
		return true
	reject(peer_id, verb, "recusado", args)
	_push_snapshot(peer_id)
	return false

## Campos do livro no save do personagem (mesmas chaves do save local: materials, gear, money)
static func to_save_fields(inv: InventoryComponent, wallet: WalletComponent) -> Dictionary:
	return {
		"materials": inv.stacks_to_save(),
		"gear": inv.items_to_save(),
		"money": wallet.money,
	}

## Carrega pilhas, peças e dinheiro de um save ou retrato; chaves ausentes ficam como estão
static func load_into(inv: InventoryComponent, wallet: WalletComponent, data: Dictionary) -> void:
	if data.get("materials") is Array:
		inv.load_from_save(data["materials"])
	if data.get("gear") is Dictionary:
		inv.load_items(data["gear"])
	if data.has("money"):
		wallet.set_money(int(data["money"]))

## Uma linha JSON por mudança em server_saves/audit/AAAA-MM-DD.log
static func audit(char_name: String, verb: StringName, detail: Dictionary, money_after: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(AUDIT_DIR))
	var path := "%s/%s.log" % [AUDIT_DIR, Time.get_date_string_from_system()]
	var f := FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	var line := {"t": Time.get_datetime_string_from_system(), "char": char_name, "verb": String(verb), "detail": detail}
	if money_after >= 0:
		line["money"] = money_after
	f.store_line(JSON.stringify(line))
	f.close()
