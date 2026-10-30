class_name GuildLedger
extends RefCounted

## Livro do Totem (GDD-19 §7): o que cada membro deu à guilda, por semana de 7 dias reais.
## Só o servidor escreve (ADR-0002). Os membros leem o Livro inteiro; fora da guilda
## só aparece o total da guilda no Placar das Guildas.

## O que o Livro conta. "doacao" é em valor de mercado; "manutencao" e "caravana_valor" em $S
const KINDS: Array[String] = ["doacao", "manutencao", "caravanas", "caravana_valor", "chefes", "invasores", "defesas"]
const WEEK_SECONDS: int = 7 * 86400
## 1970-01-01 foi uma quinta: com 4 dias de deslocamento a semana começa na segunda
const WEEK_OFFSET: int = 4 * 86400
## Semanas guardadas (as mais velhas saem do Livro; o total desde sempre fica)
const KEEP_WEEKS: int = 8

## Semana (String) -> membro -> tipo -> quantidade
var weeks: Dictionary = {}
## Total desde sempre por tipo (base dos Feitos da Guilda)
var totals: Dictionary = {}
## Crédito do dia por "membro|tipo|dia": devolver no mesmo dia anula (GDD-19 §8)
var day_credit: Dictionary = {}
## Feitos da Guilda conquistados: id -> semana
var feats: Dictionary = {}

static func week_of(unix: float) -> int:
	return int(floor((unix - WEEK_OFFSET) / WEEK_SECONDS))

static func day_of(unix: float) -> int:
	return int(floor(unix / 86400.0))

static func now() -> float:
	return Time.get_unix_time_from_system()

## Primeiro dia (data) de uma semana, para mostrar "semana de 2026-10-26"
static func week_start_text(week: int) -> String:
	var unix := week * WEEK_SECONDS + WEEK_OFFSET
	return Time.get_date_string_from_unix_time(unix)

func credit(member: String, kind: String, amount: int, unix: float = -1.0) -> void:
	if member.is_empty() or amount <= 0 or not KINDS.has(kind):
		return
	if unix < 0.0:
		unix = now()
	_shift(member, kind, amount, week_of(unix))
	var key := "%s|%s|%d" % [member, kind, day_of(unix)]
	day_credit[key] = int(day_credit.get(key, 0)) + amount
	_prune(unix)

## Desfaz o que o membro deu hoje (ex.: tirou do cofre o que tinha posto). Devolve o quanto desfez
func refund(member: String, kind: String, amount: int, unix: float = -1.0) -> int:
	if unix < 0.0:
		unix = now()
	var key := "%s|%s|%d" % [member, kind, day_of(unix)]
	var back := mini(amount, int(day_credit.get(key, 0)))
	if back <= 0:
		return 0
	day_credit[key] = int(day_credit[key]) - back
	_shift(member, kind, -back, week_of(unix))
	return back

func _shift(member: String, kind: String, amount: int, week: int) -> void:
	var w: Dictionary = weeks.get(str(week), {})
	var m: Dictionary = w.get(member, {})
	m[kind] = int(m.get(kind, 0)) + amount
	w[member] = m
	weeks[str(week)] = w
	totals[kind] = int(totals.get(kind, 0)) + amount

func _prune(unix: float) -> void:
	var current_week := week_of(unix)
	for k in weeks.keys():
		if int(k) <= current_week - KEEP_WEEKS:
			weeks.erase(k)
	var today := day_of(unix)
	for k in day_credit.keys():
		if int(String(k).get_slice("|", 2)) < today - 1:
			day_credit.erase(k)

func amount(member: String, kind: String, week: int) -> int:
	return int(weeks.get(str(week), {}).get(member, {}).get(kind, 0))

func week_total(kind: String, week: int) -> int:
	var n := 0
	for member in weeks.get(str(week), {}):
		n += int(weeks[str(week)][member].get(kind, 0))
	return n

func total(kind: String) -> int:
	return int(totals.get(kind, 0))

## Contribuição em $S: material doado, cofre pago e lucro das caravanas
static func contribution_of(row: Dictionary) -> int:
	return int(row.get("doacao", 0)) + int(row.get("manutencao", 0)) + int(row.get("caravana_valor", 0))

func week_contribution(week: int) -> int:
	var n := 0
	for member in weeks.get(str(week), {}):
		n += contribution_of(weeks[str(week)][member])
	return n

## Linhas da semana para o Livro, quem mais contribuiu primeiro: [{member, ...tipos, contribuicao}]
func week_rows(week: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var w: Dictionary = weeks.get(str(week), {})
	for member in w:
		var row: Dictionary = (w[member] as Dictionary).duplicate()
		row["member"] = member
		row["contribuicao"] = contribution_of(row)
		out.append(row)
	out.sort_custom(func(a, b):
		if a["contribuicao"] != b["contribuicao"]:
			return a["contribuicao"] > b["contribuicao"]
		return String(a["member"]) < String(b["member"]))
	return out

func to_dict() -> Dictionary:
	return {"weeks": weeks.duplicate(true), "totals": totals.duplicate(), "day_credit": day_credit.duplicate(), "feats": feats.duplicate()}

func from_dict(d: Dictionary) -> void:
	weeks = {}
	var w_in: Dictionary = d.get("weeks", {})
	for week in w_in:
		var w: Dictionary = {}
		for member in w_in[week]:
			var m: Dictionary = {}
			for kind in w_in[week][member]:
				m[String(kind)] = int(w_in[week][member][kind])
			w[String(member)] = m
		weeks[str(int(week))] = w
	totals = {}
	for k in d.get("totals", {}):
		totals[String(k)] = int(d["totals"][k])
	day_credit = {}
	for k in d.get("day_credit", {}):
		day_credit[String(k)] = int(d["day_credit"][k])
	feats = {}
	for k in d.get("feats", {}):
		feats[String(k)] = int(d["feats"][k])
