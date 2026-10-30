class_name Compendium
extends RefCounted

## Compêndio do Arquivista (B38, GDD-17 §6): capítulos com páginas curtas que se abrem
## fazendo a coisa pela primeira vez ou conversando com quem sabe. Cada página tem um
## "Mostre-me" (bairro da Costelária ou NPC) para a bússola. Capítulo completo dá Reputação.

const CHAPTER_REPUTATION: int = 10

## [{"id", "title", "icon", "pages": [{"id", "title", "text", "hint", "show"}]}]
## `show`: id de NPC da Costelária ou de bairro (CostelariaLayout.DISTRICTS)
const CHAPTERS: Array[Dictionary] = [
	{"id": &"combate", "title": "Combate", "icon": "⚔️", "pages": [
		{"id": &"combate_golpe", "title": "Golpe que acerta ensina", "hint": "Acerte um golpe em qualquer coisa viva (ou num boneco do Pátio).", "show": &"corisca",
			"text": "Não há nível de personagem. A arma que você usa aprende com cada golpe que acerta; a armadura aprende com o dano que segura."},
		{"id": &"combate_postura", "title": "Postura", "hint": "Quebre a postura de alguém.", "show": &"pelvis",
			"text": "Todo corpo tem Postura. Quebrada, o alvo cambaleia e fica aberto. Impacto quebra postura mais rápido que corte."},
		{"id": &"combate_mestres", "title": "Os Mestres", "hint": "Converse com a Mestra Corisca.", "show": &"corisca",
			"text": "No marco 10, 25, 50, 75 e 100 de uma maestria, um mestre ensina a Técnica. Sem mestre, o marco não libera nada."},
	]},
	{"id": &"caca", "title": "Caça anatômica", "icon": "🦴", "pages": [
		{"id": &"caca_parte", "title": "Quebrar a parte certa", "hint": "Quebre uma parte do corpo de um bicho (ou do boneco).", "show": &"esfola_fino",
			"text": "Você escolhe onde bater. Chifre quebrado rende chifre; parte destruída no golpe errado vira lasca de menos valor."},
		{"id": &"caca_esfola", "title": "Esfola", "hint": "Esfole um corpo segurando [E].", "show": &"esfola_fino",
			"text": "O corpo dura alguns minutos. Segure [E] para tirar cada parte. Mão treinada esfola mais rápido, com a Técnica do Mestre Esfolador."},
		{"id": &"caca_mestre", "title": "O Mestre Esfolador", "hint": "Converse com o Mestre Esfola-Fino.", "show": &"esfola_fino",
			"text": "Esfola-Fino ensina onde fica o ponto fraco e onde fica o ouro de cada bicho. Raramente são o mesmo lugar."},
	]},
	{"id": &"forja", "title": "Forja e encaixes", "icon": "⚒️", "pages": [
		{"id": &"forja_peca", "title": "A primeira peça", "hint": "Forje qualquer peça numa bigorna.", "show": &"pulmao_oeste",
			"text": "Núcleo, revestimento e tempero. A família da peça vem do revestimento; a qualidade, dos materiais e da mão."},
		{"id": &"forja_mestre", "title": "Mão de Tempero", "hint": "Converse com a Mestra Bigorna Velha.", "show": &"bigorna_velha",
			"text": "O encaixe de tempero só abre com forja 10 e a Técnica Mão de Tempero, que a Mestra Bigorna Velha ensina."},
	]},
	{"id": &"economia", "title": "Economia", "icon": "💰", "pages": [
		{"id": &"eco_comprar", "title": "Lojas", "hint": "Compre alguma coisa numa loja da Costelária.", "show": &"costelas",
			"text": "Lojas repõem o estoque ao amanhecer. Quem ajuda a cidade paga menos: Reputação alta dá desconto."},
		{"id": &"eco_vender", "title": "Bolsa do dia", "hint": "Venda alguma coisa para um comprador.", "show": &"seu_graxa",
			"text": "Comprador tem bolsa do dia. Cada unidade que a cidade vende baixa o preço daquele material até amanhã."},
		{"id": &"eco_encomenda", "title": "Encomendas", "hint": "Entregue uma encomenda ao Seu Graxa.", "show": &"seu_graxa",
			"text": "Duas por dia, para a cidade inteira. Quem chega primeiro com a parte boa leva o prêmio e Reputação."},
	]},
	{"id": &"ciclo", "title": "Ciclo do dia", "icon": "🌗", "pages": [
		{"id": &"ciclo_relogio", "title": "Um relógio só", "hint": "Converse com o Arquivista.", "show": &"pena_de_osso",
			"text": "O dia é o mesmo para todo mundo e ninguém pula a noite. A cidade vive por ele: lojas fecham, mestres descansam, o Ventre acorda."},
		{"id": &"ciclo_ventre", "title": "A Feira do Ventre", "hint": "Fale com o Mascate Sombra.", "show": &"ventre",
			"text": "Das 20h às 4h, debaixo da espinha, o Mascate vende coisa rara e compra qualquer coisa pela metade."},
	]},
	{"id": &"montarias", "title": "Montarias", "icon": "🐴", "pages": [
		{"id": &"mont_elo", "title": "Elo", "hint": "Converse com a Domadora Ventania.", "show": &"ventania",
			"text": "O Elo cresce andando junto, comendo o que a espécie come, sendo cuidado e lutando lado a lado. Tem teto por dia."},
		{"id": &"mont_seleiro", "title": "Laço e isca", "hint": "Converse com o Zé Cabresto.", "show": &"ze_cabresto",
			"text": "Sedativo cansa, isca atrai, laço segura. Bicho bravo arrebenta laço fraco."},
	]},
	{"id": &"treino", "title": "Treino", "icon": "🎯", "pages": [
		{"id": &"treino_licao", "title": "Lição", "hint": "Complete uma Lição de um mestre.", "show": &"pelvis",
			"text": "Lição é um desafio curto. O XP vem do que você fez; a primeira de cada faixa ainda dá um bônus."},
		{"id": &"treino_tecnica", "title": "Técnica", "hint": "Aprenda uma Técnica com um mestre.", "show": &"cranio",
			"text": "Técnica custa a Prova (a Lição da faixa) e uma taxa. Depois de aprendida, é sua para sempre."},
	]},
]

## Página por id ({} se não existir)
static func page(id: StringName) -> Dictionary:
	for c in CHAPTERS:
		for p in c["pages"]:
			if p["id"] == id:
				return p
	return {}

static func chapter_of(page_id: StringName) -> Dictionary:
	for c in CHAPTERS:
		for p in c["pages"]:
			if p["id"] == page_id:
				return c
	return {}

static func chapter_complete(chapter: Dictionary, unlocked: Array) -> bool:
	for p in chapter["pages"]:
		if not unlocked.has(p["id"]):
			return false
	return true

static func total_pages() -> int:
	var n := 0
	for c in CHAPTERS:
		n += c["pages"].size()
	return n

## Conversar com estes NPCs abre a página
const TALK_PAGES: Dictionary = {
	&"corisca": &"combate_mestres", &"esfola_fino": &"caca_mestre", &"bigorna_velha": &"forja_mestre",
	&"pena_de_osso": &"ciclo_relogio", &"mascate_sombra": &"ciclo_ventre", &"ventania": &"mont_elo",
	&"ze_cabresto": &"mont_seleiro",
}
