class_name FeatLedger
extends RefCounted

## Diário do Caçador (GDD-19, B40): o registro de feitos de um personagem.
## Só guarda dados; quem escreve é o DiaryComponent, no servidor (ADR-0002).

## Capítulos do Diário (GDD-19 §3) e a capa, com os totais
const CHAPTERS: Array[StringName] = [&"capa", &"caca", &"coleta", &"forja", &"fogao", &"criadouro", &"sangue", &"andancas", &"balcao"]
## Páginas guardadas por personagem; as marcadas "keep" (chefes, Marcos) não contam no limite
const MAX_PAGES: int = 50

## capítulo -> { chave -> int }
var counters: Dictionary = {}
## Páginas da mais antiga para a mais nova (GDD-19 §5)
var pages: Array[Dictionary] = []
## Recordes (GDD-19 §4): capítulo -> { chave -> {value, label, day, pos} }
var records: Dictionary = {}
## Lugares por onde andou (Andanças): "x,z" da célula -> dia da primeira visita
var places: Dictionary = {}
## Marcos cravados (GDD-19 §6): id -> dia
var milestones: Dictionary = {}
## Recompensas sem poder: títulos, adornos e capítulos com Contratos de Mestre no Quadro
var titles: Array[String] = []
var adornos: Array[String] = []
var board_access: Array[String] = []
## Título que aparece embaixo do nome ("" = nenhum)
var active_title: String = ""
## Anti-farm (GDD-19 §8): vítima -> hora real (Unix) do último abate dela
var recent_kills: Dictionary = {}
## Teto diário: {"day": dia de jogo, "counts": {chave -> int}}
var daily: Dictionary = {"day": -1, "counts": {}}

func add(chapter: StringName, key: String, amount: int = 1) -> void:
	if not CHAPTERS.has(chapter):
		push_warning("FeatLedger: capítulo desconhecido '%s'" % chapter)
		return
	var c: Dictionary = counters.get_or_add(String(chapter), {})
	c[key] = int(c.get(key, 0)) + amount

func count(chapter: StringName, key: String) -> int:
	return int(counters.get(String(chapter), {}).get(key, 0))

## Quantas chaves diferentes com o prefixo têm contagem (ex.: "receita:" = receitas diferentes)
func distinct(chapter: StringName, prefix: String) -> int:
	var n := 0
	for key in counters.get(String(chapter), {}):
		if String(key).begins_with(prefix) and int(counters[String(chapter)][key]) > 0:
			n += 1
	return n

## Quanto ainda cabe no teto do dia para a chave; já conta o que entrou
func take_daily(key: String, amount: int, cap: int, day: int) -> int:
	if int(daily.get("day", -1)) != day:
		daily = {"day": day, "counts": {}}
	var used: int = int(daily["counts"].get(key, 0))
	var allowed := clampi(cap - used, 0, amount)
	daily["counts"][key] = used + allowed
	return allowed

func has_milestone(id: StringName) -> bool:
	return milestones.has(String(id))

func set_title(t: String) -> bool:
	if t != "" and not titles.has(t):
		return false
	active_title = t
	return true

## Guarda o recorde se bater o anterior; devolve true se bateu
func try_record(chapter: StringName, key: String, value: float, entry: Dictionary = {}) -> bool:
	var c: Dictionary = records.get_or_add(String(chapter), {})
	if c.has(key) and float(c[key].get("value", 0.0)) >= value:
		return false
	var rec := entry.duplicate()
	rec["value"] = value
	c[key] = rec
	return true

func record(chapter: StringName, key: String) -> Dictionary:
	return records.get(String(chapter), {}).get(key, {})

## Escreve uma Página; passa do limite, some a mais antiga que não é para sempre
func add_page(page: Dictionary) -> void:
	pages.append(page)
	var loose := 0
	for p in pages:
		if not p.get("keep", false):
			loose += 1
	while loose > MAX_PAGES:
		for i in pages.size():
			if not pages[i].get("keep", false):
				pages.remove_at(i)
				loose -= 1
				break

## Páginas de um tipo ("abate", "assistencia", "queda"), da mais nova para a mais antiga
func pages_of(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(pages.size() - 1, -1, -1):
		if pages[i].get("kind", "") == kind:
			out.append(pages[i])
	return out

func to_dict() -> Dictionary:
	return {"counters": counters.duplicate(true), "pages": pages.duplicate(true), "records": records.duplicate(true), "places": places.duplicate(),
		"milestones": milestones.duplicate(), "titles": titles.duplicate(), "adornos": adornos.duplicate(), "board_access": board_access.duplicate(),
		"active_title": active_title, "recent_kills": recent_kills.duplicate(), "daily": daily.duplicate(true)}

func from_dict(data: Dictionary) -> void:
	counters = {}
	var raw: Dictionary = data.get("counters", {})
	for chapter in raw:
		var c: Dictionary = {}
		for key in raw[chapter]:
			c[String(key)] = int(raw[chapter][key])
		counters[String(chapter)] = c
	records = (data.get("records", {}) as Dictionary).duplicate(true)
	places = {}
	for cell in data.get("places", {}):
		places[String(cell)] = int(data["places"][cell])
	milestones = {}
	for id in data.get("milestones", {}):
		milestones[String(id)] = int(data["milestones"][id])
	titles.assign(Array(data.get("titles", [])).map(func(t): return String(t)))
	adornos.assign(Array(data.get("adornos", [])).map(func(t): return String(t)))
	board_access.assign(Array(data.get("board_access", [])).map(func(t): return String(t)))
	active_title = String(data.get("active_title", ""))
	recent_kills = {}
	for v in data.get("recent_kills", {}):
		recent_kills[String(v)] = float(data["recent_kills"][v])
	daily = (data.get("daily", {"day": -1, "counts": {}}) as Dictionary).duplicate(true)
	pages.clear()
	for p in data.get("pages", []):
		if p is Dictionary:
			pages.append(p)
