class_name CardDatabase
extends RefCounted

## Banco de dados estático das Cartas 3D Colecionáveis de Cepa Selvagem (GDD-07 e B08).
## Mapeia modelos 3D, renders e parâmetros de jogabilidade do mini-game.

static var _cards: Dictionary = {}
static var _initialized: bool = false

static func _ensure_initialized() -> void:
	if _initialized:
		return
	
	_cards.clear()
	
	# 1. Elemento Terra (Magia / Terra)
	_register(CardData.new(
		&"element_earth",
		"Elemento Terra",
		"Magia",
		CardData.Rarity.UNCOMMON,
		CardData.CardElement.EARTH,
		2, 3, 7,
		"Resonância Telúrica",
		"+2 de postura para aliados adjacentes na fileira.",
		"Concentração elemental de rocha e poeira densa da fronteira.",
		"Os andarilhos canalizam a solidez do solo em escudos impenetráveis.",
		"res://assets/cards_3d/card_kit/glTF/25_Element_Earth.gltf",
		"res://assets/cards_3d/card_kit/Renders/25_Element_Earth.png"
	))
	
	# 2. Polinização Arcana (Ecologia / Terra)
	_register(CardData.new(
		&"polinization",
		"Polinização Arcana",
		"Ecologia",
		CardData.Rarity.RARE,
		CardData.CardElement.EARTH,
		3, 4, 6,
		"Germinação Rápida",
		"Restaura 3 pontos de postura ao ser jogada.",
		"Cruzamento genético de esporos que aceleram a maturação de cepas.",
		"Sem abelhas de silício e esporos mágicos, o solo não geraria plantas medicinais.",
		"res://assets/cards_3d/card_kit/glTF/11_Polinization.gltf",
		"res://assets/cards_3d/card_kit/Renders/11_Polinization.png"
	))
	
	# 3. Cogumelos de Sobretudo (Economia / Trevas)
	_register(CardData.new(
		&"trenchcoat_mushrooms",
		"Cogumelos de Sobretudo",
		"Economia",
		CardData.Rarity.UNCOMMON,
		CardData.CardElement.DARK,
		1, 2, 4,
		"Contrabando Fúngico",
		"Gera +1 de Éter quando é descartada ou destruída.",
		"Esporos saprófitos comercializados nas sombras do Mercado Negro.",
		"Sob a capa de couro puído, os fungos crescem em segredo longe das autoridades.",
		"res://assets/cards_3d/card_kit/glTF/2_TrenchcoatMushrooms.gltf",
		"res://assets/cards_3d/card_kit/Renders/2_TrenchcoatMushrooms.png"
	))
	
	# 4. Mímico da Sucata (Bestiário / Trevas)
	_register(CardData.new(
		&"mimic",
		"Mímico da Sucata",
		"Bestiário",
		CardData.Rarity.RARE,
		CardData.CardElement.DARK,
		4, 7, 5,
		"Emboscada Dentada",
		"Causa dano dobrado no primeiro turno em que entra em combate.",
		"Uma criatura parasita que assume o formato de baú de suprimentos.",
		"Nunca confie em um fecho que pisca para você no meio da Zona Selvagem.",
		"res://assets/cards_3d/card_kit/glTF/12_Mimic.gltf",
		"res://assets/cards_3d/card_kit/Renders/12_Mimic.png"
	))
	
	# 5. Colmeia Fúngica (Ecologia / Terra)
	_register(CardData.new(
		&"beehive",
		"Colmeia Fúngica",
		"Ecologia",
		CardData.Rarity.COMMON,
		CardData.CardElement.EARTH,
		2, 2, 6,
		"Enxame Protetor",
		"Retalia com 1 de dano a qualquer atacante direto.",
		"Ninho biológico adaptado para resistir às tempestades do deserto.",
		"Os colonos utilizam o mel amargo como base para tônicos de vigor.",
		"res://assets/cards_3d/card_kit/glTF/10_Beehive.gltf",
		"res://assets/cards_3d/card_kit/Renders/10_Beehive.png"
	))
	
	# 6. Moeda Clandestina (Economia / Neutro)
	_register(CardData.new(
		&"coin",
		"Moeda Clandestina",
		"Economia",
		CardData.Rarity.COMMON,
		CardData.CardElement.NEUTRAL,
		1, 1, 3,
		"Suborno de Taverna",
		"Permite comprar 1 carta adicional da pilha de compra.",
		"Moeda forjada com sucata de latão aceita nas apostas de duelo.",
		"O que o dinheiro dos nobres não compra, a moeda clandestina resolve com discrição.",
		"res://assets/cards_3d/card_kit/glTF/14_Coin.gltf",
		"res://assets/cards_3d/card_kit/Renders/14_Coin.png"
	))
	
	# 7. Esfera de Fogo (Magia / Fogo)
	_register(CardData.new(
		&"fireball",
		"Esfera de Fogo",
		"Magia",
		CardData.Rarity.UNCOMMON,
		CardData.CardElement.FIRE,
		3, 6, 3,
		"Queimadura Solar",
		"Causa 2 de dano de fogo adicional por 2 rodadas.",
		"Plasma térmico concentrado em um orbe incandescente.",
		"Um clarão súbito que rompe a noite fria e derrete placas de carapaça.",
		"res://assets/cards_3d/card_kit/glTF/1_Fireball.gltf",
		"res://assets/cards_3d/card_kit/Renders/1_Fireball.png"
	))
	
	# 8. Besta Chifre-de-Pedra (Bestiário / Terra) - Conquista da Quebra Anatômica
	_register(CardData.new(
		&"beast_horn",
		"Besta de Chifre-de-Pedra",
		"Bestiário",
		CardData.Rarity.LEGENDARY,
		CardData.CardElement.EARTH,
		5, 8, 10,
		"Chifre Quebrador",
		"Ignora 50% da postura defensiva do alvo em ataques frontais.",
		"Registro de caça anatômica obtido após quebrar o chifre do monstro.",
		"Apenas quem domina a mecânica de foco anatômico consegue extrair esse troféu lendário.",
		"res://assets/cards_3d/card_kit/glTF/29_Block.gltf",
		"res://assets/cards_3d/card_kit/Renders/29_Block.png"
	))
	
	_initialized = true

static func _register(card: CardData) -> void:
	if card != null and not card.id.is_empty():
		_cards[card.id] = card

## Retorna uma carta pelo identificador
static func get_card(id: StringName) -> CardData:
	_ensure_initialized()
	return _cards.get(id, null)

## Retorna todas as cartas cadastradas
static func get_all_cards() -> Array[CardData]:
	_ensure_initialized()
	var list: Array[CardData] = []
	for id in _cards.keys():
		list.append(_cards[id])
	return list

## Retorna as cartas pertencentes a uma categoria específica
static func get_cards_by_category(category_name: String) -> Array[CardData]:
	_ensure_initialized()
	var list: Array[CardData] = []
	for id in _cards.keys():
		var c: CardData = _cards[id]
		if c.category.to_lower() == category_name.to_lower():
			list.append(c)
	return list

## Retorna o total de cartas registradas no jogo
static func get_total_count() -> int:
	_ensure_initialized()
	return _cards.size()
