class_name MilestoneTable
extends RefCounted

const _MilestoneDef = preload("res://scripts/data/milestone_def.gd")

## Tabela dos Marcos do Diário do Caçador (GDD-19 §6): três graus por capítulo.
## Para criar um Marco basta uma linha aqui; o DiaryComponent confere todos a cada feito.
## Colunas: id, capítulo, grau, tipo, chave, alvo, descrição, título, extras (carta, adorno, acesso, pendente)

const R := _MilestoneDef.Tier.RASTRO
const T := _MilestoneDef.Tier.TRILHA
const L := _MilestoneDef.Tier.LENDA
const C := _MilestoneDef.Kind.COUNTER
const D := _MilestoneDef.Kind.DISTINCT
const K := _MilestoneDef.Kind.RECORD

const ROWS: Array = [
	[&"caca_rastro", &"caca", R, C, "abates", 10, "Abater 10 criaturas", "Rastreador", {}],
	[&"caca_trilha", &"caca", T, C, "duas_partes", 10, "Quebrar duas partes de 10 criaturas antes da queda", "Quebra-Ossos", {"access": true}],
	[&"caca_lenda", &"caca", L, C, "chefes_ilesos", 1, "Abater um chefe sem levar golpe forte dele", "Intocável", {"card": &"beast_horn", "adorno": &"presa_dourada"}],
	[&"coleta_rastro", &"coleta", R, C, "recursos", 50, "Colher 50 recursos", "Catador", {}],
	[&"coleta_trilha", &"coleta", T, D, "lugar:", 5, "Colher em 5 lugares diferentes", "Colhedor de Longe", {"card": &"beehive"}],
	[&"coleta_lenda", &"coleta", L, K, "melhor_peixe", 4, "Pescar um peixe mutante de porte máximo", "Anzol Raro", {"adorno": &"escama_iridescente"}],
	[&"forja_rastro", &"forja", R, C, "pecas", 5, "Forjar 5 peças", "Aprendiz de Bigorna", {}],
	[&"forja_trilha", &"forja", T, D, "familia:", 3, "Forjar uma peça de cada família", "Três Famílias", {"access": true}],
	[&"forja_lenda", &"forja", L, K, "melhor_peca", 5, "Forjar uma peça de qualidade máxima", "Mão de Brasa", {"adorno": &"martelo_de_brasa"}],
	[&"fogao_rastro", &"fogao", R, C, "pratos", 10, "Cozinhar 10 pratos", "Cozinheiro de Fogueira", {}],
	[&"fogao_trilha", &"fogao", T, D, "receita:", 5, "Cozinhar 5 receitas diferentes", "Panela Cheia", {"access": true}],
	[&"fogao_lenda", &"fogao", L, K, "melhor_prato", 5, "Cozinhar um prato de qualidade máxima", "Chef dos Ermos", {"adorno": &"colher_de_osso"}],
	[&"criadouro_rastro", &"criadouro", R, C, "capturas", 1, "Capturar uma montaria", "Laçador", {}],
	[&"criadouro_trilha", &"criadouro", T, K, "maior_elo", 100, "Elo 100 com uma montaria", "Alma Gêmea", {"card": &"polinization"}],
	[&"criadouro_lenda", &"criadouro", L, K, "maior_geracao", 3, "Criar uma cria de terceira geração", "Guardião de Linhagens", {"adorno": &"pena_de_linhagem"}],
	[&"sangue_rastro", &"sangue", R, C, "abates_dignos", 1, "Primeiro abate digno", "Primeiro Sangue", {}],
	[&"sangue_trilha", &"sangue", T, C, "abates_dignos", 25, "25 abates dignos", "Duelista", {}],
	[&"sangue_lenda", &"sangue", L, C, "lendas_abatidas", 1, "Derrubar quem já tem um Marco de Lenda", "Matador de Lendas", {"card": &"fireball", "adorno": &"capa_rasgada"}],
	[&"andancas_rastro", &"andancas", R, C, "lugares", 5, "Pisar em 5 lugares", "Pé na Estrada", {}],
	[&"andancas_trilha", &"andancas", T, C, "lugares", 40, "Pisar em 40 lugares", "Cartógrafo de Botas", {"card": &"mimic", "access": true}],
	[&"andancas_lenda", &"andancas", L, C, "ilhas", 1, "Pisar em todas as ilhas voadoras (aguarda o B39)", "Pés nas Nuvens", {"adorno": &"pluma_do_ceu", "pending": true}],
	[&"balcao_rastro", &"balcao", R, C, "vendas", 20, "Vender 20 vezes", "Mascate", {}],
	[&"balcao_trilha", &"balcao", T, C, "caravanas", 10, "Entregar 10 caravanas", "Tropeiro", {}],
	[&"balcao_lenda", &"balcao", L, C, "missoes", 50, "Concluir 50 missões do Quadro", "Braço do Quadro", {"adorno": &"selo_do_quadro"}],
]

static var _all: Array[_MilestoneDef] = []

static func all() -> Array[_MilestoneDef]:
	if _all.is_empty():
		for row in ROWS:
			var m := _MilestoneDef.new()
			m.id = row[0]
			m.chapter = row[1]
			m.tier = row[2]
			m.kind = row[3]
			m.key = row[4]
			m.threshold = float(row[5])
			m.description = row[6]
			m.title = row[7]
			var extra: Dictionary = row[8]
			m.card_id = extra.get("card", &"")
			m.adorno = extra.get("adorno", &"")
			m.board_access = extra.get("access", false)
			m.pending = extra.get("pending", false)
			_all.append(m)
	return _all

static func get_def(id: StringName) -> _MilestoneDef:
	for m in all():
		if m.id == id:
			return m
	return null
