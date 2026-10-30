class_name GuildBook
extends RefCounted

const _GuildData = preload("res://scripts/data/guild_data.gd")
const _GuildLedger = preload("res://scripts/data/guild_ledger.gd")
const _GuildSystem = preload("res://scripts/systems/guild_system.gd")
const _MaterialData = preload("res://scripts/data/material_data.gd")

## Livro do Totem, Feitos da Guilda e Placar das Guildas (GDD-19 §7).
## Quem escreve é o Diário de cada membro, no servidor (ADR-0002); aqui ficam as regras.

## Feitos da Guilda: [id, descrição, condição ("nivel" ou tipo do Livro), quanto, recompensa, peça da heráldica, pendente]
## A recompensa é só visual (borda ou estandarte), nunca poder (ADR-0001)
const FEATS: Array = [
	["forte_erguido", "Erguer o Forte de Madeira (sede nível 2)", "nivel", 2, "Borda de Madeira", "borda", false],
	["cidadela", "Erguer a Cidadela (sede nível 3)", "nivel", 3, "Estandarte de Ferro", "estandarte", false],
	["mil_doados", "Doar 1.000 $S em material", "doacao", 1000, "Borda Dourada", "borda", false],
	["cofre_firme", "Pagar 500 $S de manutenção", "manutencao", 500, "Borda de Pedra", "borda", false],
	["cem_caravanas", "Entregar 100 caravanas", "caravanas", 100, "Estandarte do Caminho", "estandarte", false],
	["dez_chefes", "Derrubar 10 chefes", "chefes", 10, "Borda de Presas", "borda", false],
	["vinte_invasores", "Abater 20 invasores no território", "invasores", 20, "Estandarte Vigilante", "estandarte", false],
	# Ainda não há ataque ao Totem no jogo: o feito espera o sistema de cerco
	["totem_firme", "Defender o Totem 5 vezes", "defesas", 5, "Estandarte Inabalável", "estandarte", true],
]

## Colunas do Placar das Guildas (GDD-19 §7): só guildas, nunca jogadores
const BOARD_COLUMNS: Array = [
	["contribuicao", "Mais contribuíram", "$S"],
	["defesas", "Mais defenderam", "defesas"],
	["chefes", "Mais chefes derrubados", "chefes"],
]
const BOARD_SIZE: int = 5

## Cópia do Placar recebida do servidor (cliente online só lê)
static var board_cache: Dictionary = {}

## Escreve no Livro da guilda e confere os Feitos. Devolve os ids dos Feitos novos
static func credit(guild: _GuildData, member: String, kind: String, amount: int, unix: float = -1.0) -> Array[String]:
	if guild == null or not guild.is_member(member):
		return []
	guild.book.credit(member, kind, amount, unix)
	return check_feats(guild, unix)

## Valor de mercado da doação, decidido aqui (servidor) e não pela tela. Material sem
## preço de mercado (sem ficha em resources/materials) não conta (GDD-19 §8)
static func donation_value(material_id: StringName, amount: int) -> int:
	if amount <= 0 or not ResourceLoader.exists(_MaterialData.DIR + String(material_id) + ".tres"):
		return 0
	return maxi(0, _MaterialData.of(material_id).base_value) * amount

static func refund(guild: _GuildData, member: String, kind: String, amount: int, unix: float = -1.0) -> int:
	if guild == null:
		return 0
	return guild.book.refund(member, kind, amount, unix)

static func feat_progress(guild: _GuildData, row: Array) -> int:
	if row[2] == "nivel":
		return guild.level
	return guild.book.total(row[2])

static func check_feats(guild: _GuildData, unix: float = -1.0) -> Array[String]:
	var out: Array[String] = []
	if guild == null:
		return out
	if unix < 0.0:
		unix = _GuildLedger.now()
	for row in FEATS:
		if row[6] or guild.book.feats.has(row[0]):
			continue
		if feat_progress(guild, row) >= int(row[3]):
			guild.book.feats[row[0]] = _GuildLedger.week_of(unix)
			out.append(row[0])
	return out

## Peças de heráldica que a guilda já pode usar
static func heraldry_unlocks(guild: _GuildData) -> Array[String]:
	var out: Array[String] = []
	for row in FEATS:
		if guild != null and guild.book.feats.has(row[0]):
			out.append(row[4])
	return out

## Território da guilda no ponto: o Totem dela cobre a posição?
static func in_territory(tree: SceneTree, guild_id: StringName, pos: Vector3) -> bool:
	if tree == null or guild_id.is_empty():
		return false
	for t in tree.get_nodes_in_group("guild_totems"):
		var g = t.get("guild_data")
		if g and g.id == guild_id and t is Node3D:
			if (t as Node3D).global_position.distance_to(pos) <= g.get_territory_radius():
				return true
	return false

## Placar da semana: por coluna, as guildas com mais pontos (as zeradas não entram)
static func scoreboard(week: int = -1) -> Dictionary:
	if week < 0:
		week = _GuildLedger.week_of(_GuildLedger.now())
	var out := {"week": week}
	for col in BOARD_COLUMNS:
		var rows: Array = []
		for g in _GuildSystem.get_instance().guilds.values():
			var value: int = g.book.week_contribution(week) if col[0] == "contribuicao" else g.book.week_total(col[0], week)
			if value > 0:
				rows.append({"guild": g.name, "tag": g.tag, "value": value})
		rows.sort_custom(func(a, b):
			if a["value"] != b["value"]:
				return a["value"] > b["value"]
			return String(a["guild"]) < String(b["guild"]))
		out[col[0]] = rows.slice(0, BOARD_SIZE)
	return out

## O Livro que um membro pode ler: as linhas da semana e os Feitos. Fora da guilda, nada
static func book_view(guild: _GuildData, reader: String, week: int = -1) -> Dictionary:
	if guild == null or not guild.is_member(reader):
		return {}
	if week < 0:
		week = _GuildLedger.week_of(_GuildLedger.now())
	return {
		"guild": guild.name,
		"tag": guild.tag,
		"week": week,
		"rows": guild.book.week_rows(week),
		"feats": guild.book.feats.duplicate(),
		"totals": guild.book.totals.duplicate(),
		"level": guild.level,
	}

# ---------------------------------------------------------------- Leitura (telas)

const KIND_NAMES: Dictionary = {
	"doacao": "doado", "manutencao": "cofre", "caravanas": "caravanas",
	"chefes": "chefes", "invasores": "invasores", "defesas": "defesas",
}

## Livro e Placar para a tela de quem lê. No servidor (ou sozinho) calcula na hora;
## no cliente online pede ao servidor e devolve a última cópia recebida
static func view_for(player: Node) -> Dictionary:
	var net := _net()
	if net and not net.is_server_authoritative():
		net.request_guild_board()
		return board_cache
	var out := {"board": scoreboard()}
	var g = player.get("guild") if player else null
	var guild: _GuildData = g.get_guild_data() if g and g.has_method("get_guild_data") else null
	# Mesmo nome que o Diário usa ao creditar o membro
	var diary = player.get("diary") if player else null
	var reader: String = str(diary.describe(player)["name"]) if diary else ""
	var book := book_view(guild, reader)
	if not book.is_empty():
		out["book"] = book
	return out

static func _net() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("NetworkManager") if tree else null

## "Ana — 340 $S · doado 200 · cofre 40 · caravanas 2 · chefes 1"
static func row_text(row: Dictionary) -> String:
	var parts: Array[String] = []
	for kind in KIND_NAMES:
		if int(row.get(kind, 0)) > 0:
			parts.append("%s %d" % [KIND_NAMES[kind], int(row[kind])])
	return "%s — %d $S%s" % [row.get("member", "?"), int(row.get("contribuicao", 0)), ("  ·  " + " · ".join(parts)) if not parts.is_empty() else ""]

## Feitos da Guilda com progresso, a partir de um book_view (serve no cliente)
static func feat_lines(book: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var feats: Dictionary = book.get("feats", {})
	var totals: Dictionary = book.get("totals", {})
	for row in FEATS:
		var have: int = int(book.get("level", 1)) if row[2] == "nivel" else int(totals.get(row[2], 0))
		var mark := "✔" if feats.has(row[0]) else ("…" if row[6] else "·")
		var tail := "aguardando" if row[6] and not feats.has(row[0]) else "%d/%d" % [mini(have, int(row[3])), int(row[3])]
		out.append("%s %s (%s) → %s" % [mark, row[1], tail, row[4]])
	return out

## Linhas do Placar: [[título da coluna, ["1. [TAG] Nome — 340 $S", ...]], ...]
static func board_lines(board: Dictionary) -> Array:
	var out: Array = []
	for col in BOARD_COLUMNS:
		var lines: Array[String] = []
		var i := 0
		for r in board.get(col[0], []):
			i += 1
			lines.append("%d. [%s] %s — %d %s" % [i, r.get("tag", ""), r.get("guild", ""), int(r.get("value", 0)), col[2]])
		out.append([col[1], lines])
	return out
