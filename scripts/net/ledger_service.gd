class_name LedgerServiceAutoload
extends Node

const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const _WalletComponent = preload("res://scripts/components/wallet_component.gd")
const _StatsComponent = preload("res://scripts/components/stats_component.gd")

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

## Cliente: aplica no Player o retrato que veio do servidor (ignora versão velha)
func apply_snapshot(snap: Dictionary, player: Node) -> bool:
	var version := int(snap.get("version", -1))
	if version <= client_version or player == null:
		return false
	var inv = player.get("inventory")
	var wallet = player.get("wallet")
	if inv == null or wallet == null:
		return false
	client_version = version
	load_into(inv, wallet, snap)
	snapshot_applied.emit(version)
	return true

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
