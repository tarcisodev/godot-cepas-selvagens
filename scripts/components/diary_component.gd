class_name DiaryComponent
extends Node

const _FeatLedger = preload("res://scripts/data/feat_ledger.gd")
const _ForgedItem = preload("res://scripts/data/forged_item.gd")
const _HitEvent = preload("res://scripts/data/hit_event.gd")
const _MilestoneDef = preload("res://scripts/data/milestone_def.gd")
const _MilestoneTable = preload("res://scripts/data/milestone_table.gd")
const _GuildBook = preload("res://scripts/systems/guild_book.gd")
const _GuildData = preload("res://scripts/data/guild_data.gd")

## Diário do Caçador (GDD-19 §3 a §8, B40 fases 1 a 3).
## Escuta o EventBus (ADR-0003) e escreve no FeatLedger do dono: abates, assistências e
## quedas, os ofícios (activity_done), as andanças, os recordes e os Marcos com as suas
## recompensas sem poder. Só quem tem autoridade escreve (ADR-0002); o cliente só lê.

signal page_written(page: Dictionary)
signal milestone_reached(def: _MilestoneDef)
## Outro jogador mostrou um pedaço do Diário dele (GDD-19 §7)
signal showcase_received(payload: Dictionary)
## A cópia do cliente foi trocada pela do servidor
signal snapshot_applied()
## A guilda do dono cravou um Feito da Guilda (Livro do Totem, GDD-19 §7)
signal guild_feat_reached(feat_id: String)

## Acertou o alvo nesse intervalo antes da queda dele e outro deu o golpe final: assistência
const ASSIST_WINDOW: float = 15.0
## Tamanho da célula de "lugar" das Andanças (m)
const PLACE_CELL: float = 128.0
## Pulo maior que isso num quadro é teleporte (renascer, apito), não andança
const MAX_STEP: float = 30.0
## Golpe forte: tira pelo menos esta fração da Vida máxima do dono (Marco de Lenda da Caça)
const STRONG_HIT_FRACTION: float = 0.2
## Anti-farm (GDD-19 §8): a mesma vítima só é abate digno de novo depois de 6 h reais
const WORTHY_REPEAT_SECONDS: float = 6.0 * 3600.0
## ...e precisa carregar pelo menos metade do valor do equipamento de quem abateu
const WORTHY_GEAR_RATIO: float = 0.5
## Teto de recursos que contam por lugar (célula) por dia de jogo
const GATHER_DAILY_CAP: int = 200
## Alcance para mostrar o Diário a alguém (m)
const SHOW_RANGE: float = 10.0
## O que se pode mostrar (GDD-19 §7): título, um capítulo ou uma Página
const SHOW_KINDS: Array[String] = ["titulo", "capitulo", "pagina"]
## Mostras recebidas guardadas na sessão
const MAX_SHOWCASES: int = 10

## Mostras que outros jogadores fizeram para o dono, da mais nova para a mais antiga
var showcases: Array[Dictionary] = []

var ledger: _FeatLedger = _FeatLedger.new()

## Alvos que o dono acertou: id da instância -> {t, damage, damage_type, weapon, parts, last_damage}
var _hits_dealt: Dictionary = {}
## Outros jogadores que acertaram cada alvo, mesmo antes do dono: id -> {nome -> t}
var _other_hitters: Dictionary = {}
## Último golpe que o dono levou: {damage, damage_type, part, who, weapon}
var _last_taken: Dictionary = {}
## Quem deu golpe forte no dono nesta luta: id da instância -> true
var _strong_from: Dictionary = {}
## Andanças: última posição e metros ainda não contados
var _last_pos: Variant = null
var _walk_m: float = 0.0
var _ride_m: float = 0.0

func _ready() -> void:
	var bus := get_node_or_null("/root/EventBus")
	if bus == null:
		return
	if not bus.hit_resolved.is_connected(_on_hit_resolved):
		bus.hit_resolved.connect(_on_hit_resolved)
	if not bus.entity_defeated.is_connected(_on_entity_defeated):
		bus.entity_defeated.connect(_on_entity_defeated)
	if not bus.activity_done.is_connected(_on_activity_done):
		bus.activity_done.connect(_on_activity_done)

func _physics_process(_delta: float) -> void:
	if _is_authority():
		track_movement()

func _is_authority() -> bool:
	var net := get_node_or_null("/root/NetworkManager")
	if net and net.has_method("is_server_authoritative"):
		return net.is_server_authoritative()
	return true

static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## Listener do EventBus de combate
func _on_hit_resolved(hit: _HitEvent, final_damage: float, is_part_broken: bool) -> void:
	var me := get_parent()
	if hit == null or hit.target == null or me == null or not _is_authority():
		return
	if hit.target == me:
		var my_stats: StatsComponent = me.get_node_or_null("StatsComponent") as StatsComponent
		if hit.attacker and my_stats and final_damage >= STRONG_HIT_FRACTION * my_stats.get_stat(&"max_health"):
			_strong_from[hit.attacker.get_instance_id()] = true
		_last_taken = {
			"damage": final_damage,
			"damage_type": String(DamageType.to_string_name(hit.damage_type)),
			"part": String(hit.part_id),
			"who": describe(hit.attacker),
			"weapon": weapon_of(hit.attacker),
		}
		return
	var id := hit.target.get_instance_id()
	if hit.attacker == me:
		var entry: Dictionary = _hits_dealt.get_or_add(id, {"parts": []})
		entry["t"] = _now()
		entry["damage"] = final_damage
		entry["damage_type"] = String(DamageType.to_string_name(hit.damage_type))
		entry["weapon"] = weapon_of(me)
		if is_part_broken and not entry["parts"].has(String(hit.part_id)):
			entry["parts"].append(String(hit.part_id))
			if not is_player(hit.target) and not is_bred(hit.target):
				ledger.add(&"caca", "partes_quebradas")
	elif is_player(hit.attacker):
		# Outro jogador acertou o alvo: se o dono der o golpe final, entra como ajuda na Página
		_other_hitters.get_or_add(id, {})[describe(hit.attacker)["name"]] = _now()
	if _hits_dealt.has(id):
		# Golpe sem dano em quem já caiu não é o golpe final
		_hits_dealt[id]["last_damage"] = final_damage
	_prune()

## Listener do EventBus de combate
func _on_entity_defeated(entity: Node, killer: Node) -> void:
	var me := get_parent()
	if entity == null or me == null or not _is_authority():
		return
	if entity == me:
		if float(_last_taken.get("damage", 0.0)) > 0.0:
			_write_fall(killer)
		_last_taken = {}
		_strong_from.clear()
		return
	var id := entity.get_instance_id()
	var entry: Dictionary = _hits_dealt.get(id, {})
	if entry.is_empty() or float(entry.get("last_damage", 0.0)) <= 0.0:
		_other_hitters.erase(id)
		return
	_hits_dealt.erase(id)
	entry["helpers"] = _other_hitters.get(id, {})
	_other_hitters.erase(id)
	var flawless := not _strong_from.has(id)
	_strong_from.erase(id)
	if killer == me:
		_write_kill(entity, entry, "abate", flawless)
	elif _now() - float(entry.get("t", -INF)) <= ASSIST_WINDOW:
		_write_kill(entity, entry, "assistencia")
	_check_milestones()

func _write_kill(entity: Node, entry: Dictionary, kind: String, flawless: bool = false) -> void:
	var who := describe(entity)
	var helpers: Array[String] = []
	for h in entry.get("helpers", {}):
		if _now() - float(entry["helpers"][h]) <= ASSIST_WINDOW:
			helpers.append(h)
	var page := _page(kind, entity)
	page["who"] = who
	page["with"] = entry.get("weapon", {}).merged({"damage_type": entry.get("damage_type", "")})
	page["parts"] = entry.get("parts", []).duplicate()
	page["helpers"] = helpers
	page["keep"] = who.get("boss", false)
	var player_target: bool = who["kind"] == "jogador"
	var chapter: StringName = &"sangue" if player_target else &"caca"
	# Bicho de cercado ou montaria de alguém vira Página, mas não conta (GDD-19 §8)
	if not player_target and is_bred(entity):
		page["criado"] = true
		_commit(page)
		return
	if player_target and kind == "abate":
		page["digno"] = is_worthy_kill(entity)
		ledger.recent_kills[who["name"]] = Time.get_unix_time_from_system()
		if page["digno"]:
			ledger.add(&"sangue", "abates_dignos")
			var victim_diary := entity.get_node_or_null("DiaryComponent")
			if victim_diary and victim_diary.has_lenda():
				ledger.add(&"sangue", "lendas_abatidas")
		if page["digno"] and is_invader(entity):
			_credit_guild("invasores", 1)
	if kind == "abate":
		ledger.add(chapter, "abates")
		ledger.add(&"capa", "abates")
		if not player_target:
			ledger.add(&"caca", "especie:" + who["name"])
			if page["parts"].size() >= 2:
				ledger.add(&"caca", "duas_partes")
			if who.get("boss", false):
				ledger.add(&"caca", "chefes")
				_credit_guild("chefes", 1)
				if flawless:
					ledger.add(&"caca", "chefes_ilesos")
				engrave("Derrubou %s, dia %d" % [who["name"], page["day"]])
			var stats: StatsComponent = entity.get_node_or_null("StatsComponent") as StatsComponent
			if stats:
				ledger.try_record(&"caca", "maior_caca", stats.get_stat(&"max_health"), _stamp(who["name"]))
	else:
		ledger.add(chapter, "assistencias")
	_commit(page)

func _write_fall(killer: Node) -> void:
	var page := _page("queda", get_parent())
	var who: Dictionary = _last_taken.get("who", {})
	if killer == null and _last_taken.get("part", "") == "queda":
		who = {"kind": "ambiente", "name": "Queda"}
	page["who"] = who
	page["with"] = _last_taken.get("weapon", {}).merged({"damage_type": _last_taken.get("damage_type", "")})
	ledger.add(&"capa", "quedas")
	match who.get("kind", ""):
		"jogador":
			ledger.add(&"sangue", "quedas")
		"criatura":
			ledger.add(&"caca", "quedas")
	_commit(page)

## Listener do EventBus de ofícios (GDD-19 §3)
func _on_activity_done(actor: Node, activity: StringName, info: Dictionary) -> void:
	if actor != get_parent() or not _is_authority():
		return
	_apply_activity(activity, info)
	_check_milestones()

func _apply_activity(activity: StringName, info: Dictionary) -> void:
	var q := float(info.get("quality", 0))
	match activity:
		&"coleta":
			# Teto por lugar e por dia de jogo: ficar no mesmo canto não enche o Diário (GDD-19 §8)
			var cell := _cell_of(get_parent())
			var n := ledger.take_daily("coleta:" + cell, int(info.get("amount", 1)), GATHER_DAILY_CAP, int(_page("", null)["day"]))
			if n <= 0:
				return
			ledger.add(&"coleta", "recursos", n)
			ledger.add(&"coleta", "material:" + str(info.get("material", "")), n)
			ledger.add(&"coleta", "lugar:" + cell, n)
			ledger.try_record(&"coleta", "melhor_coleta", q, _stamp(str(info.get("material", ""))))
		&"pesca":
			ledger.add(&"coleta", "peixes")
			ledger.add(&"coleta", "especie:" + str(info.get("species", "")))
			ledger.try_record(&"coleta", "melhor_peixe", q, _stamp(str(info.get("species", ""))))
		&"forja":
			ledger.add(&"forja", "pecas")
			ledger.add(&"forja", "familia:" + str(info.get("family", "")))
			ledger.try_record(&"forja", "melhor_peca", q, _stamp(str(info.get("item", ""))))
		&"fundicao":
			ledger.add(&"forja", "barras")
		&"cozinha":
			if info.get("burned", false):
				ledger.add(&"fogao", "queimados")
			else:
				ledger.add(&"fogao", "pratos")
				ledger.add(&"fogao", "receita:" + str(info.get("result", "")))
				ledger.try_record(&"fogao", "melhor_prato", q, _stamp(str(info.get("result", ""))))
		&"captura":
			ledger.add(&"criadouro", "capturas")
			ledger.add(&"criadouro", "especie:" + str(info.get("species", "")))
		&"cria":
			ledger.add(&"criadouro", "crias")
			ledger.try_record(&"criadouro", "maior_geracao", float(info.get("generation", 1)), _stamp(str(info.get("species", ""))))
		&"elo":
			ledger.try_record(&"criadouro", "maior_elo", float(info.get("elo", 0)), _stamp(str(info.get("mount", ""))))
		&"companheira_perdida":
			ledger.add(&"criadouro", "perdidas")
			var page := _page("perda", get_parent())
			page["who"] = {"kind": "criatura", "name": str(info.get("name", "")), "species": str(info.get("species", ""))}
			page["elo"] = int(info.get("elo", 0))
			page["keep"] = true
			_commit(page)
		&"venda":
			var money := int(info.get("money", 0))
			ledger.add(&"balcao", "vendas")
			ledger.add(&"balcao", "moedas", money)
			ledger.try_record(&"balcao", "maior_venda", money, _stamp(str(info.get("item", info.get("where", "")))))
		&"compra":
			ledger.add(&"balcao", "compras")
		&"missao":
			ledger.add(&"balcao", "missoes")
			ledger.add(&"balcao", "moedas", int(info.get("money", 0)))
		&"caravana":
			ledger.add(&"balcao", "caravanas")
			ledger.add(&"balcao", "moedas", int(info.get("money", 0)))
			_credit_guild("caravanas", 1)
			_credit_guild("caravana_valor", int(info.get("money", 0)))
		&"doacao":
			var value := _GuildBook.donation_value(StringName(str(info.get("material", ""))), int(info.get("amount", 0)))
			if value > 0:
				_credit_guild("doacao", value)
			else:
				_announce_feats(_GuildBook.check_feats(my_guild()))
		&"manutencao":
			_credit_guild("manutencao", int(info.get("money", 0)))
		&"manutencao_retirada":
			# Pôr no cofre e tirar no mesmo dia não conta (GDD-19 §8)
			var guild := my_guild()
			if guild:
				_GuildBook.refund(guild, describe(get_parent())["name"], "manutencao", int(info.get("money", 0)))

## Guilda do dono (ou null)
func my_guild() -> _GuildData:
	var g = get_parent().get("guild") if get_parent() else null
	if g and g.has_method("get_guild_data"):
		return g.get_guild_data()
	return null

## Livro do Totem: credita o dono na guilda dele
func _credit_guild(kind: String, amount: int) -> void:
	var guild := my_guild()
	if guild:
		_announce_feats(_GuildBook.credit(guild, describe(get_parent())["name"], kind, amount))

func _announce_feats(ids: Array[String]) -> void:
	for id in ids:
		guild_feat_reached.emit(id)

## Invasor: jogador de fora da guilda abatido dentro do território dela
func is_invader(victim: Node) -> bool:
	var me := get_parent() as Node3D
	var mine := my_guild()
	if mine == null or me == null or not is_player(victim):
		return false
	if describe(victim).get("guild", "") == String(mine.id):
		return false
	return _GuildBook.in_territory(get_tree(), mine.id, me.global_position)

## Andanças: metros a pé e montado e lugares novos (células de PLACE_CELL m)
func track_movement() -> void:
	var me := get_parent() as Node3D
	if me == null or not me.is_inside_tree():
		return
	var pos := me.global_position
	if _last_pos != null:
		var step := Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z).length()
		if step <= MAX_STEP:
			if me.get("mounted_on") != null:
				_ride_m += step
			else:
				_walk_m += step
	_last_pos = pos
	if _walk_m >= 1.0:
		ledger.add(&"andancas", "metros_a_pe", floori(_walk_m))
		_walk_m -= floorf(_walk_m)
	if _ride_m >= 1.0:
		ledger.add(&"andancas", "metros_montado", floori(_ride_m))
		_ride_m -= floorf(_ride_m)
	var cell := _cell_of(me)
	if not ledger.places.has(cell):
		ledger.places[cell] = int(_page("", null)["day"])
		ledger.add(&"andancas", "lugares")
		_check_milestones()

func _cell_of(n: Node) -> String:
	var pos: Vector3 = (n as Node3D).global_position if n is Node3D and n.is_inside_tree() else Vector3.ZERO
	return "%d,%d" % [floori(pos.x / PLACE_CELL), floori(pos.z / PLACE_CELL)]

# ---------------------------------------------------------------- Marcos (GDD-19 §6)

## Confere a tabela inteira; é barato (poucas dezenas de linhas) e pega Marcos de qualquer capítulo
func _check_milestones() -> void:
	for def in _MilestoneTable.all():
		if not ledger.has_milestone(def.id) and def.reached(ledger):
			_grant(def)

## Crava o Marco e dá as recompensas: título, carta, adorno, acesso no Quadro e, na Lenda, memória na arma
func _grant(def: _MilestoneDef) -> void:
	var day := int(_page("", null)["day"])
	ledger.milestones[String(def.id)] = day
	if def.title != "" and not ledger.titles.has(def.title):
		ledger.titles.append(def.title)
	if def.adorno != &"" and not ledger.adornos.has(String(def.adorno)):
		ledger.adornos.append(String(def.adorno))
	if def.board_access and not ledger.board_access.has(String(def.chapter)):
		ledger.board_access.append(String(def.chapter))
	var cards = get_parent().get("card_collection") if get_parent() else null
	if def.card_id != &"" and cards:
		cards.unlock_card(def.card_id)
	if def.tier == _MilestoneDef.Tier.LENDA:
		engrave("Marco de Lenda: %s, dia %d" % [def.title, day])
	var page := _page("marco", get_parent())
	page["who"] = {"kind": "marco", "name": def.title, "id": String(def.id), "tier": _MilestoneDef.TIER_NAMES[def.tier]}
	page["keep"] = true
	_commit(page)
	milestone_reached.emit(def)

func has_lenda() -> bool:
	for id in ledger.milestones:
		var def := _MilestoneTable.get_def(StringName(id))
		if def and def.tier == _MilestoneDef.Tier.LENDA:
			return true
	return false

## Contratos de Mestre do Quadro (B28) liberados por Marco de Trilha
func has_board_access(chapter: StringName) -> bool:
	return ledger.board_access.has(String(chapter))

## Memória na arma (GDD-19 §5): só texto na peça da mão principal, nenhum poder
func engrave(text: String) -> void:
	var me := get_parent()
	var inv = me.get("inventory") if me else null
	if inv == null or not inv.has_method("equipped_in"):
		return
	var item: _ForgedItem = inv.equipped_in(_ForgedItem.Slot.MAIN_HAND)
	if item == null:
		return
	var feats: Array = item.memory.get_or_add("feitos", [])
	if not feats.has(text):
		feats.append(text)

# ---------------------------------------------------------------- anti-farm (GDD-19 §8)

## Abate digno: vítima de outra guilda, não abatida por você nas últimas 6 h reais e com
## equipamento de pelo menos metade do valor do seu
func is_worthy_kill(victim: Node) -> bool:
	var me := get_parent()
	var my_guild = me.get("guild") if me else null
	var their_guild = victim.get("guild")
	if my_guild and their_guild and String(my_guild.guild_id) != "" and my_guild.guild_id == their_guild.guild_id:
		return false
	var last := float(ledger.recent_kills.get(describe(victim)["name"], -INF))
	if Time.get_unix_time_from_system() - last < WORTHY_REPEAT_SECONDS:
		return false
	return gear_value(victim) >= WORTHY_GEAR_RATIO * gear_value(me)

## Valor do equipamento: soma da qualidade das peças vestidas (o servidor decide; ADR-0002)
static func gear_value(n: Node) -> float:
	var inv = n.get("inventory") if n else null
	if inv == null or not ("equipped_items" in inv):
		return 0.0
	var total := 0.0
	for slot in inv.equipped_items:
		var item = inv.equipped_items[slot]
		if item:
			total += float(item.quality)
	return total

## Montaria de alguém ou bicho nascido em cercado
static func is_bred(n: Node) -> bool:
	return n != null and (n.get("bond") != null or n.has_meta("criado"))

# ---------------------------------------------------------------- utilidades

## Dia e lugar de um recorde
func _stamp(label: String) -> Dictionary:
	var p := _page("", get_parent())
	return {"label": label, "day": p["day"], "pos": p["pos"]}

func _commit(page: Dictionary) -> void:
	ledger.add_page(page)
	page_written.emit(page)

## Dia, hora e lugar da Página (GDD-19 §5)
func _page(kind: String, where: Node) -> Dictionary:
	var page := {"kind": kind, "day": 0, "hour": 0.0, "pos": [0, 0]}
	var sun: Node = null
	if is_inside_tree() and get_tree().current_scene:
		sun = get_tree().current_scene.get_node_or_null("Sun")
	if sun and "day_count" in sun:
		page["day"] = int(sun.day_count)
		page["hour"] = snappedf(float(sun.current_time_hours), 0.1)
	if where is Node3D and where.is_inside_tree():
		var p: Vector3 = (where as Node3D).global_position
		page["pos"] = [roundi(p.x), roundi(p.z)]
	return page

func _prune() -> void:
	var now := _now()
	for id in _hits_dealt.keys():
		if now - float(_hits_dealt[id].get("t", now)) > ASSIST_WINDOW * 2.0:
			_hits_dealt.erase(id)
	for id in _other_hitters.keys():
		var hitters: Dictionary = _other_hitters[id]
		for h in hitters.keys():
			if now - float(hitters[h]) > ASSIST_WINDOW:
				hitters.erase(h)
		if hitters.is_empty():
			_other_hitters.erase(id)

static func is_player(n: Node) -> bool:
	return n != null and (n.is_in_group("player") or n.is_in_group("remote_players"))

## Quem é, para a Página: jogador (nome e guilda), criatura (espécie, chefe) ou ambiente
static func describe(n: Node) -> Dictionary:
	if n == null or not is_instance_valid(n):
		return {"kind": "ambiente", "name": "?"}
	if is_player(n):
		var p_name: String = str(n.get("character_name")) if n.get("character_name") else ""
		if p_name.is_empty() and n.has_meta("player_name"):
			p_name = str(n.get_meta("player_name"))
		var save := n.get_node_or_null("/root/SaveGame") if n.is_inside_tree() else null
		if p_name.is_empty() and n.is_in_group("player") and save and str(save.get("character_name")) != "":
			p_name = str(save.get("character_name"))
		if p_name.is_empty():
			p_name = String(n.name)
		var g = n.get("guild")
		return {"kind": "jogador", "name": p_name, "guild": String(g.guild_id) if g else ""}
	var c_name: String = String(n.name)
	var dna = n.get("dna")
	if dna and dna.has_method("species_name"):
		c_name = dna.species_name()
	elif n.get("display_name"):
		c_name = str(n.get("display_name"))
	return {"kind": "criatura", "name": c_name, "boss": n.is_in_group("boss")}

## Com o quê: a peça na mão principal (nome e família)
static func weapon_of(n: Node) -> Dictionary:
	if n == null or not is_instance_valid(n):
		return {}
	var inv = n.get("inventory")
	if inv and inv.has_method("equipped_in"):
		var item: _ForgedItem = inv.equipped_in(_ForgedItem.Slot.MAIN_HAND)
		if item:
			return {"weapon": item.display_name, "family": String(item.family)}
	return {}

# ---------------------------------------------------------------- mostrar o Diário (GDD-19 §7)

## Monta o pedaço que o dono escolheu mostrar; o Diário inteiro nunca sai daqui
func build_showcase(kind: String, arg: Variant = null) -> Dictionary:
	var payload := {"kind": kind, "from": describe(get_parent())["name"], "title": ledger.active_title}
	match kind:
		"titulo":
			payload["marcos"] = ledger.milestones.size()
			payload["lenda"] = has_lenda()
		"capitulo":
			var chapter := String(arg)
			if not _FeatLedger.CHAPTERS.has(StringName(chapter)):
				return {}
			payload["chapter"] = chapter
			payload["counters"] = ledger.counters.get(chapter, {}).duplicate()
			payload["records"] = ledger.records.get(chapter, {}).duplicate(true)
			payload["milestones"] = ledger.milestones.keys().filter(func(id): return String(id).begins_with(chapter + "_"))
		"pagina":
			var i := int(arg) if arg != null else -1
			if i < 0 or i >= ledger.pages.size():
				return {}
			payload["page"] = ledger.pages[i].duplicate(true)
		_:
			return {}
	return payload

## Mostra para alguém perto: no mesmo processo entrega direto; online vai pelo servidor
func show_to(target: Node, kind: String, arg: Variant = null) -> bool:
	var me := get_parent() as Node3D
	if target == null or me == null or target == me or not is_player(target):
		return false
	if target is Node3D and me.global_position.distance_to((target as Node3D).global_position) > SHOW_RANGE:
		return false
	var payload := build_showcase(kind, arg)
	if payload.is_empty():
		return false
	var other := target.get_node_or_null("DiaryComponent")
	if other:
		other.receive_showcase(payload)
		return true
	var net := get_node_or_null("/root/NetworkManager")
	if net and net.has_method("send_diary_showcase"):
		return net.send_diary_showcase(target, payload)
	return false

## Recebe uma mostra; só os campos conhecidos passam (vem de outro jogador)
func receive_showcase(payload: Dictionary) -> void:
	var kind := str(payload.get("kind", ""))
	if not SHOW_KINDS.has(kind):
		return
	var clean := {"kind": kind, "from": str(payload.get("from", "?")).left(32), "title": str(payload.get("title", "")).left(48)}
	for key in ["marcos", "lenda", "chapter", "counters", "records", "milestones", "page"]:
		if payload.has(key):
			clean[key] = payload[key]
	showcases.push_front(clean)
	if showcases.size() > MAX_SHOWCASES:
		showcases.resize(MAX_SHOWCASES)
	showcase_received.emit(clean)

## Jogadores perto o bastante para receber uma mostra
func nearby_players() -> Array[Node]:
	var out: Array[Node] = []
	var me := get_parent() as Node3D
	if me == null or not me.is_inside_tree():
		return out
	for group in ["player", "remote_players"]:
		for n in me.get_tree().get_nodes_in_group(group):
			if n != me and n is Node3D and me.global_position.distance_to(n.global_position) <= SHOW_RANGE:
				out.append(n)
	return out

## Cópia que o cliente recebe do servidor (ADR-0002): troca tudo, sem conferir Marcos
func apply_snapshot(data: Dictionary) -> void:
	ledger.from_dict(data)
	snapshot_applied.emit()

func to_dict() -> Dictionary:
	return ledger.to_dict()

func from_dict(data: Dictionary) -> void:
	ledger.from_dict(data)
