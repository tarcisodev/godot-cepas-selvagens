class_name LedgerServiceAutoload
extends Node

const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const _WalletComponent = preload("res://scripts/components/wallet_component.gd")
const _StatsComponent = preload("res://scripts/components/stats_component.gd")
const _LedgerVerbs = preload("res://scripts/net/ledger_verbs.gd")
const _LedgerSources = preload("res://scripts/net/ledger_sources.gd")

## Livro-razão do servidor (ADR-0009, B41 fase 1).
## O servidor é dono do inventário e da carteira de cada personagem no mundo: um "livro" por peer,
## com um InventoryComponent e um WalletComponent fora da árvore do jogador. Toda mudança passa por
## `commit()`, que sobe a versão, grava uma linha de auditoria, salva e manda o retrato ao dono.
## No host, o livro do próprio jogador são os componentes do Player (não há cópia).
## No cliente, o livro não existe: o retrato chega por rede e é aplicado no Player (somente leitura).

const AUDIT_DIR: String = "user://server_saves/audit"

## Retrato aplicado no cliente (versão nova)
signal snapshot_applied(version: int)

## peer_id -> {"name", "holder": Node, "inventory", "wallet", "version", "own": bool, "meta": {once, escrow}}
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
	var meta: Variant = pdata.get("ledger_meta", {})
	_books[peer_id] = {"name": char_name, "holder": holder, "inventory": inv, "wallet": wallet, "version": 0, "own": false, "meta": meta.duplicate(true) if meta is Dictionary else {}}

## Livro do jogador do próprio host: usa os componentes do Player, sem cópia
func open_own_book(peer_id: int, char_name: String, player: Node) -> void:
	var inv = player.get("inventory") if player else null
	var wallet = player.get("wallet") if player else null
	if inv == null or wallet == null:
		return
	close_book(peer_id, false)
	_books[peer_id] = {"name": char_name, "holder": null, "inventory": inv, "wallet": wallet, "version": 0, "own": true, "meta": {}}

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
	var fields := to_save_fields(book.inventory, book.wallet)
	# Cofres e fontes de uso único (fase 3) ficam no save do personagem, fora do retrato
	fields["ledger_meta"] = book.get("meta", {})
	return sp.update_player_data(String(book.name), fields)

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
		if _collect != null:
			# Dentro de uma fonte de ganho: o gasto vai junto no mesmo pedido
			_collect.steps.append([String(verb), args])
		else:
			sent_seq += 1
			net.send_ledger_request(sent_seq, verb, args)
	return result

# ---------------------------------------------------------------- ganhos (B41 fase 3)

## Cliente: fonte de ganho aberta (o que o corpo deu e gastou), ou null
var _collect = null
## Ganhos sem fonte já avisados (um aviso por material, para achar ponto esquecido)
var _warned: Dictionary = {}

## Roda `body` como fonte de ganho (LedgerSources.gain). No cliente online junta o que ele deu e
## gastou e manda um pedido `source` só; no host e offline só roda.
func gain(kind: StringName, source: String, body: Callable, at: Vector3 = Vector3.INF) -> Variant:
	if not should_route() or _collect != null:
		return body.call()
	_collect = {"kind": String(kind), "source": source, "steps": [], "items": [], "gear": [], "money": 0}
	if at != Vector3.INF:
		_collect["at"] = at
	var result: Variant = body.call()
	var c: Dictionary = _collect
	_collect = null
	if not (c.steps.is_empty() and c.items.is_empty() and c.gear.is_empty() and int(c.money) == 0):
		sent_seq += 1
		net.send_ledger_request(sent_seq, &"source", c)
	return result

## Chamados pelo inventário e pela carteira do jogador local ao ganhar algo no cliente online
func note_material(id: StringName, n: int, q: int, traits: Array, memory: Dictionary) -> void:
	if _collect == null:
		_warn_unsourced(String(id))
		return
	var e := {"id": String(id), "n": n, "q": q, "traits": traits.map(func(t): return String(t))}
	if not memory.is_empty():
		e["memory"] = memory
	_collect.items.append(e)

func note_item(item: ForgedItem) -> void:
	if _collect == null:
		_warn_unsourced("peça " + item.display_name)
		return
	_collect.gear.append(item.to_dict())

func note_money(n: int) -> void:
	if _collect == null:
		_warn_unsourced("$S")
		return
	_collect.money = int(_collect.money) + n

## Ganho fora de fonte no cliente online: vale só até o próximo retrato do servidor
func _warn_unsourced(what: String) -> void:
	if _warned.has(what):
		return
	_warned[what] = true
	push_warning("[Livro] Ganho sem fonte no cliente online (%s): o servidor não entrega" % what)

## Servidor: refaz um pedido `source` no livro. Gastos primeiro (os mesmos verbos de sempre), depois a
## regra da fonte confere os ganhos; se algo não cabe, o livro volta como estava. "" = aceito.
func _apply_source(peer_id: int, args: Dictionary) -> String:
	var book: Dictionary = _books[peer_id]
	var kind := StringName(str(args.get("kind", "")))
	if not _LedgerSources.is_known(kind):
		return "fonte_desconhecida"
	var rule := _LedgerSources.rule(kind)
	var source := str(args.get("source", "")).left(64)
	var inv: InventoryComponent = book.inventory
	var wallet: WalletComponent = book.wallet
	var meta: Dictionary = book.meta
	var key := "%s|%s" % [kind, source]
	var now := now_msec()

	# Teto por hora e recarga por fonte (antes de mexer no livro)
	var hour: Dictionary = _hour_of(String(book.name), kind, now)
	if int(hour.events) >= int(rule.get("per_hour", 60)):
		return "acima_do_teto_por_hora"
	if bool(rule.get("once", false)) and meta.get("once", {}).has(key):
		return "fonte_ja_usada"
	var limit: Array = rule.get("per_source", [])
	var req_items: Array = args.get("items", []) if args.get("items") is Array else []
	if (kind == &"gather" or kind == &"gather_wild") and not req_items.is_empty() and req_items[0] is Dictionary:
		var first: Dictionary = req_items[0]
		limit = _LedgerSources.gather_limit(StringName(str(first.get("id", ""))))
	var uses: Array = []
	if not limit.is_empty():
		uses = _source_uses(String(book.name), key, now, float(limit[1]))
		if uses.size() >= int(limit[0]):
			return "fonte_em_recarga"

	# Onde a fonte está: perto do jogador que o servidor conhece, e na lista da semente
	var at: Variant = args.get("at")
	if rule.has("near"):
		if not (at is Vector3) or not at.is_finite():
			return "fonte_sem_posicao"
		var pos: Variant = net.player_position(peer_id) if net != null and net.has_method("player_position") else null
		if pos is Vector3 and (pos as Vector3).distance_to(at) > float(rule.near):
			return "fonte_longe_do_jogador"

	# Gastos do bloco
	var before := to_save_fields(inv, wallet)
	var value_before := _LedgerSources.book_value(inv, wallet)
	for step in args.get("steps", []):
		if not (step is Array) or step.size() != 2 or not (step[1] is Dictionary):
			load_into(inv, wallet, before)
			return "gasto_invalido"
		var verb := StringName(str(step[0]))
		if verb == &"source" or not _LedgerVerbs.is_known(verb) or not _LedgerVerbs.succeeded(_LedgerVerbs.execute(verb, inv, wallet, step[1])):
			load_into(inv, wallet, before)
			return "gasto_recusado"
	var given := maxi(0, value_before - _LedgerSources.book_value(inv, wallet))

	# Ganhos pedidos
	var gains := {"items": [], "money": int(args.get("money", 0)), "gear": []}
	for e in args.get("items", []):
		if not (e is Dictionary):
			load_into(inv, wallet, before)
			return "item_invalido"
		gains.items.append(e)
	for d in args.get("gear", []):
		gains.gear.append(ForgedItem.from_dict(d) if d is Dictionary else null)
	if kind == &"gather":
		if not _LedgerSources.has_gather_spots():
			var land := _find_landscape()
			if land != null:
				_LedgerSources.build_gather_spots(land)
		for e in gains.items:
			if not _LedgerSources.is_seeded_spot(StringName(str(e.get("id", ""))), at):
				load_into(inv, wallet, before)
				return "fonte_fora_da_semente"
	var bin := StringName(str(rule.get("escrow_out", "")))
	var escrow: int = int(meta.get("escrow", {}).get(String(bin), 0))
	var reason := _LedgerSources.check_gains(kind, gains, given, inv, escrow)
	if reason.is_empty() and int(hour.money) + int(gains.money) > int(rule.get("money_hour", 1 << 30)):
		reason = "dinheiro_por_hora"
	if not reason.is_empty():
		load_into(inv, wallet, before)
		return reason

	for e in gains.items:
		inv.add_material(StringName(str(e.id)), int(e.n), int(e.get("q", 1)), (e.get("traits", []) as Array).map(func(t): return StringName(str(t))), e.get("memory", {}) if e.get("memory") is Dictionary else {})
	for it in gains.gear:
		inv.add_item(it)
	if int(gains.money) > 0:
		wallet.add(int(gains.money))

	# Contadores: hora, recarga, uso único e cofres
	hour.events = int(hour.events) + 1
	hour.money = int(hour.money) + int(gains.money)
	if not limit.is_empty():
		uses.append(now)
	if bool(rule.get("once", false)):
		if not meta.has("once"):
			meta["once"] = {}
		meta.once[key] = true
	if rule.has("escrow_in") or rule.has("escrow_out"):
		if not meta.has("escrow"):
			meta["escrow"] = {}
		if rule.has("escrow_in"):
			var b := String(rule.escrow_in)
			meta.escrow[b] = int(meta.escrow.get(b, 0)) + given
		else:
			meta.escrow[String(bin)] = maxi(0, escrow - _LedgerSources.escrow_cost(kind, gains))
	return ""

## Relógio do servidor para recarga e teto por hora (os testes avançam com `clock_offset_msec`)
var clock_offset_msec: int = 0
## nome do personagem -> {"kind|fonte": [msec de cada uso]}
var _uses: Dictionary = {}
## nome do personagem -> {kind: {"start", "events", "money"}}
var _hours: Dictionary = {}
## peer -> [início da janela, recusas]: a partir de STRIKES_TO_KICK por hora, desconecta (decisão 3 do B41)
var _strikes: Dictionary = {}
const STRIKES_TO_KICK: int = 20
const HOUR_MSEC: int = 3600 * 1000

## Relevo do mundo do servidor (a lista da semente usa a mesma altura que o cliente)
func _find_landscape() -> Node:
	var scene := get_tree().current_scene if is_inside_tree() else null
	return scene.get_node_or_null("Landscape") if scene else null

func now_msec() -> int:
	return Time.get_ticks_msec() + clock_offset_msec

func _hour_of(char_name: String, kind: StringName, now: int) -> Dictionary:
	if not _hours.has(char_name):
		_hours[char_name] = {}
	var h: Dictionary = _hours[char_name].get(kind, {})
	if h.is_empty() or now - int(h.start) >= HOUR_MSEC:
		h = {"start": now, "events": 0, "money": 0}
		_hours[char_name][kind] = h
	return h

func _source_uses(char_name: String, key: String, now: int, window_sec: float) -> Array:
	if not _uses.has(char_name):
		_uses[char_name] = {}
	var list: Array = _uses[char_name].get(key, [])
	list = list.filter(func(t): return now - int(t) < int(window_sec * 1000.0))
	_uses[char_name][key] = list
	return list

## Recusa fora do plausível: conta e, passando do teto por hora, derruba a sessão
func _strike(peer_id: int) -> void:
	var now := now_msec()
	var s: Array = _strikes.get(peer_id, [now, 0])
	if now - int(s[0]) >= HOUR_MSEC:
		s = [now, 0]
	s[1] = int(s[1]) + 1
	_strikes[peer_id] = s
	if int(s[1]) >= STRIKES_TO_KICK and net != null and net.has_method("disconnect_peer_safe"):
		print("[Livro] Peer %d passou de %d pedidos fora do plausível na hora. Desconectando." % [peer_id, STRIKES_TO_KICK])
		_strikes.erase(peer_id)
		net.disconnect_peer_safe(peer_id)

func strikes_of(peer_id: int) -> int:
	return int(_strikes.get(peer_id, [0, 0])[1])

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
	if verb == &"source":
		var reason := _apply_source(peer_id, args)
		if reason.is_empty():
			commit(peer_id, verb, args)
			return true
		reject(peer_id, verb, reason, args)
		_strike(peer_id)
		_push_snapshot(peer_id)
		return false
	if not _LedgerVerbs.is_known(verb):
		reject(peer_id, verb, "verbo_desconhecido", {})
		_strike(peer_id)
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
