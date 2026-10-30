class_name MasterTechniques
extends RefCounted

## Técnicas de marco (B38, GDD-17 §5 e GDD-02 §5). Chegar ao nível 10/25/50/75/100 de uma
## maestria só deixa a Técnica **pronta**: quem libera é o mestre, com a Prova (a Lição da
## faixa) e uma taxa em $S (ralo de moeda). O XP continua vindo só da ação.
##
## Cada Técnica soma um bônus num `stat` lido pelos sistemas:
## - dmg_slash / dmg_impact / dmg_magic: dano do tipo (CombatResolver)
## - part_break: dano em parte anatômica · poise: dano de postura (CombatResolver)
## - esfola_step: libera o degrau de tempo de esfola (Player.get_harvest_time)
## - speed_<tag>: encurta a coleta daquela maestria (GatherableResource.get_gather_time)
## - temper_slot: libera o encaixe de tempero na forja · forge_crit: crítico de forja
## - food_duration: o efeito da comida dura mais

const MILESTONES: Array[int] = [10, 25, 50, 75, 100]
const COST: Dictionary = {10: 60, 25: 150, 50: 400, 75: 900, 100: 2000}

## tag → {marco: {"name", "desc", "stat", "value"}}
const TECHNIQUES: Dictionary = {
	&"lâmina": {
		10: {"name": "Corte Firme", "desc": "+5% de dano de corte", "stat": &"dmg_slash", "value": 0.05},
		25: {"name": "Talho no Osso", "desc": "+15% de dano em partes do corpo", "stat": &"part_break", "value": 0.15},
		50: {"name": "Fio Vivo", "desc": "+8% de dano de corte", "stat": &"dmg_slash", "value": 0.08},
		75: {"name": "Golpe de Postura", "desc": "+15% de dano de postura", "stat": &"poise", "value": 0.15},
		100: {"name": "Lâmina de Mestre", "desc": "+12% de dano de corte", "stat": &"dmg_slash", "value": 0.12},
	},
	&"concussão": {
		10: {"name": "Pancada Seca", "desc": "+5% de dano de impacto", "stat": &"dmg_impact", "value": 0.05},
		25: {"name": "Racha-Casco", "desc": "+15% de dano em partes do corpo", "stat": &"part_break", "value": 0.15},
		50: {"name": "Peso Morto", "desc": "+15% de dano de postura", "stat": &"poise", "value": 0.15},
		75: {"name": "Martelo Fundo", "desc": "+8% de dano de impacto", "stat": &"dmg_impact", "value": 0.08},
		100: {"name": "Terremoto de Mão", "desc": "+12% de dano de impacto", "stat": &"dmg_impact", "value": 0.12},
	},
	&"canalização": {
		10: {"name": "Respiro Terpênico", "desc": "+5% de dano mágico", "stat": &"dmg_magic", "value": 0.05},
		25: {"name": "Foco de Éter", "desc": "+6% de dano mágico", "stat": &"dmg_magic", "value": 0.06},
		50: {"name": "Choque de Cepa", "desc": "+10% de dano de postura", "stat": &"poise", "value": 0.10},
		75: {"name": "Canal Aberto", "desc": "+8% de dano mágico", "stat": &"dmg_magic", "value": 0.08},
		100: {"name": "Tempestade Terpênica", "desc": "+12% de dano mágico", "stat": &"dmg_magic", "value": 0.12},
	},
	&"esfola": {
		10: {"name": "Faca Treinada", "desc": "Esfola em 2,5 s por parte", "stat": &"esfola_step", "value": 1.0},
		25: {"name": "Corte Limpo", "desc": "+10% de dano em partes do corpo", "stat": &"part_break", "value": 0.10},
		50: {"name": "Mão Leve", "desc": "Esfola em 1,5 s por parte", "stat": &"esfola_step", "value": 1.0},
		75: {"name": "Olho de Açougueiro", "desc": "+10% de dano em partes do corpo", "stat": &"part_break", "value": 0.10},
		100: {"name": "Esfola Relâmpago", "desc": "Esfola em 0,5 s por parte", "stat": &"esfola_step", "value": 1.0},
	},
	&"forja": {
		10: {"name": "Mão de Tempero", "desc": "Libera o encaixe de tempero", "stat": &"temper_slot", "value": 1.0},
		25: {"name": "Brasa Certa", "desc": "+3% de crítico de forja", "stat": &"forge_crit", "value": 0.03},
		50: {"name": "Martelada Justa", "desc": "+4% de crítico de forja", "stat": &"forge_crit", "value": 0.04},
		75: {"name": "Têmpera Fina", "desc": "+5% de crítico de forja", "stat": &"forge_crit", "value": 0.05},
		100: {"name": "Mestre Forjador", "desc": "+10% de crítico de forja", "stat": &"forge_crit", "value": 0.10},
	},
	&"mineracao": {
		10: {"name": "Veio à Vista", "desc": "Minera 10% mais rápido", "stat": &"speed_mineracao", "value": 0.10},
		25: {"name": "Picareta Firme", "desc": "Minera mais 10% mais rápido", "stat": &"speed_mineracao", "value": 0.10},
		50: {"name": "Rocha Mansa", "desc": "Minera mais 10% mais rápido", "stat": &"speed_mineracao", "value": 0.10},
		75: {"name": "Ouvido de Pedra", "desc": "Minera mais 5% mais rápido", "stat": &"speed_mineracao", "value": 0.05},
		100: {"name": "Mestre Mineiro", "desc": "Minera mais 5% mais rápido", "stat": &"speed_mineracao", "value": 0.05},
	},
	&"coleta": {
		10: {"name": "Mão no Mato", "desc": "Coleta 10% mais rápido", "stat": &"speed_coleta", "value": 0.10},
		25: {"name": "Olho de Colhedor", "desc": "Coleta mais 10% mais rápido", "stat": &"speed_coleta", "value": 0.10},
		50: {"name": "Passo Leve", "desc": "Coleta mais 10% mais rápido", "stat": &"speed_coleta", "value": 0.10},
		75: {"name": "Raiz Inteira", "desc": "Coleta mais 5% mais rápido", "stat": &"speed_coleta", "value": 0.05},
		100: {"name": "Mestre do Mato", "desc": "Coleta mais 5% mais rápido", "stat": &"speed_coleta", "value": 0.05},
	},
	&"culinaria": {
		10: {"name": "Paladar", "desc": "Comida dura 10% mais", "stat": &"food_duration", "value": 0.10},
		25: {"name": "Tempero de Mão", "desc": "Comida dura mais 10%", "stat": &"food_duration", "value": 0.10},
		50: {"name": "Fogo Baixo", "desc": "Comida dura mais 15%", "stat": &"food_duration", "value": 0.15},
		75: {"name": "Panela Velha", "desc": "Comida dura mais 15%", "stat": &"food_duration", "value": 0.15},
		100: {"name": "Banquete", "desc": "Comida dura mais 25%", "stat": &"food_duration", "value": 0.25},
	},
}

const TAG_NAMES: Dictionary = {
	&"lâmina": "Lâmina", &"concussão": "Impacto", &"canalização": "Canalização", &"esfola": "Esfola",
	&"forja": "Forja", &"mineracao": "Mineração", &"coleta": "Coleta", &"culinaria": "Culinária", &"elo": "Elo com montarias",
}

static func tag_name(tag: StringName) -> String:
	return TAG_NAMES.get(tag, String(tag).capitalize())

static func get_technique(tag: StringName, milestone: int) -> Dictionary:
	return TECHNIQUES.get(tag, {}).get(milestone, {})

## Faixa do nível: 0 (1–9), 1 (10–24), 2 (25–49), 3 (50–74), 4 (75–99), 5 (100)
static func band_of(level: int) -> int:
	var b := 0
	for m in MILESTONES:
		if level >= m:
			b += 1
	return b

## Próximo marco ainda não aprendido que o nível já alcançou; 0 = nenhum pronto
static func ready_milestone(tag: StringName, level: int, learned: Array) -> int:
	for m in MILESTONES:
		if level >= m and not learned.has(m) and TECHNIQUES.get(tag, {}).has(m):
			return m
	return 0

## Soma dos bônus de `stat` nas Técnicas aprendidas ({tag: [marcos]})
static func bonus(learned: Dictionary, stat: StringName) -> float:
	var total := 0.0
	for tag in learned:
		var table: Dictionary = TECHNIQUES.get(tag, {})
		for m in learned[tag]:
			var t: Dictionary = table.get(int(m), {})
			if t.get("stat", &"") == stat:
				total += float(t["value"])
	return total

static func has(learned: Dictionary, tag: StringName, milestone: int) -> bool:
	return learned.get(tag, []).has(milestone)
