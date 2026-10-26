class_name EcologyKnowledgeComponent
extends Node

## Sistema de Conhecimento e Pesquisa Ecológica (GDD-04 §5, GDD-08 §5).
## Rastreia a proficiência do jogador sobre cada espécie da fauna e flora do vale.
## Níveis de Pesquisa:
## - Nível 1 (25 pts): Análise Fisiológica (Fraquezas e Partes Quebráveis).
## - Nível 2 (60 pts): Diagnóstico em Tempo Real (Integridade anatômica das partes).
## - Nível 3 (120 pts): Genética de Campo (Leitura de alelos e mutações no Modo Foto).

signal research_updated(species_id: StringName, points: int, level: int)
signal level_up(species_id: StringName, new_level: int)

const THRESHOLD_LV1: int = 25
const THRESHOLD_LV2: int = 60
const THRESHOLD_LV3: int = 120

const SPECIES_CATALOG: Dictionary = {
	&"trotador": {
		"name": "Trotador",
		"weaknesses": ["Corte", "Fogo"],
		"parts": ["Chifre", "Pele Dorsal"],
		"description": "Herbívoro veloz das planícies com chifres ramificados e postura ágil."
	},
	&"planador": {
		"name": "Planador-de-Penacho",
		"weaknesses": ["Perfuração", "Gelo"],
		"parts": ["Penacho", "Asa Direita", "Asa Esquerda"],
		"description": "Grande ave com envergadura majestosa que plana pelos cânions."
	},
	&"saltarelo": {
		"name": "Saltarelo",
		"weaknesses": ["Impacto", "Eletricidade"],
		"parts": ["Orelhas Longas", "Pernas Traseiras"],
		"description": "Pequeno quadrúpede saltador extremamente veloz e arisco."
	},
	&"rinolito": {
		"name": "Rinolito",
		"weaknesses": ["Impacto", "Fogo"],
		"parts": ["Chifre Nasal", "Placas de Carapaça", "Cauda"],
		"description": "Besta colossal encouraçada com carapaça de quartzo e chifre perfurante."
	},
	&"lobo": {
		"name": "Lobo-do-Ermo",
		"weaknesses": ["Corte", "Fogo"],
		"parts": ["Presas", "Garras"],
		"description": "Predador esguio das matas fechadas e colinas rochosas."
	},
	&"tatu": {
		"name": "Tatu-Espinho",
		"weaknesses": ["Impacto", "Água"],
		"parts": ["Carapaça Espinhosa", "Garras Escavadoras"],
		"description": "Besta quadrúpede baixa e protegida por densas placas córneas."
	},
	&"lambari": {
		"name": "Lambari-Brilho",
		"weaknesses": ["Eletricidade", "Rede"],
		"parts": ["Nadadeira Dorsal"],
		"description": "Peixe de águas rasas com escamas prateadas e reflexos luminescentes."
	},
	&"traira": {
		"name": "Traíra-do-Remanso",
		"weaknesses": ["Corte", "Fogo"],
		"parts": ["Mandíbula Denteada"],
		"description": "Peixe voraz dos remansos profundos e leitos lodosos."
	},
	&"dourado": {
		"name": "Dourado-da-Cachoeira",
		"weaknesses": ["Impacto", "Gelo"],
		"parts": ["Nadadeira Caudal Dourada"],
		"description": "Peixe lendário de coloração áurea que salta as correntezas da cachoeira."
	},
	&"pinheira": {
		"name": "Pinheira-Lume",
		"weaknesses": ["Corte", "Fogo"],
		"parts": ["Pinhas-Lume", "Casca Resinosa"],
		"description": "Árvore ancestral com tronco imponente e frutos brilhantes com lume."
	}
}

# Armazenamento: species_id (StringName) -> int (pontos acumulados)
var _research_points: Dictionary = {}

func _init() -> void:
	pass

## Normaliza chave para o catálogo
static func normalize_species(species_id: Variant) -> StringName:
	var s: String = str(species_id).to_lower().strip_edges()
	if s.contains("trotador"):
		return &"trotador"
	if s.contains("planador"):
		return &"planador"
	if s.contains("saltarelo"):
		return &"saltarelo"
	if s.contains("rinolito"):
		return &"rinolito"
	if s.contains("lobo"):
		return &"lobo"
	if s.contains("tatu"):
		return &"tatu"
	if s.contains("lambari"):
		return &"lambari"
	if s.contains("traira") or s.contains("traíra"):
		return &"traira"
	if s.contains("dourado"):
		return &"dourado"
	if s.contains("pinheira"):
		return &"pinheira"
	return StringName(s)

## Adiciona pontos de pesquisa a uma espécie e devolve o total atual
func add_research(species_id: Variant, amount: int) -> int:
	if amount <= 0:
		return get_points(species_id)
	
	var key := normalize_species(species_id)
	var old_points: int = _research_points.get(key, 0)
	var old_level: int = calculate_level(old_points)
	
	var new_points: int = old_points + amount
	_research_points[key] = new_points
	
	var new_level: int = calculate_level(new_points)
	research_updated.emit(key, new_points, new_level)
	
	if new_level > old_level:
		level_up.emit(key, new_level)
	
	return new_points

## Retorna a pontuação de pesquisa atual
func get_points(species_id: Variant) -> int:
	var key := normalize_species(species_id)
	return _research_points.get(key, 0)

## Retorna o nível de pesquisa (0 a 3)
func get_level(species_id: Variant) -> int:
	return calculate_level(get_points(species_id))

## Calcula nível de acordo com pontuação
static func calculate_level(points: int) -> int:
	if points >= THRESHOLD_LV3:
		return 3
	elif points >= THRESHOLD_LV2:
		return 2
	elif points >= THRESHOLD_LV1:
		return 1
	return 0

## Nível 1: Fraquezas e partes anatômicas reveladas
func has_unlocked_weaknesses(species_id: Variant) -> bool:
	return get_level(species_id) >= 1

## Nível 2: HUD em tempo real e integridade das partes quebráveis
func has_unlocked_anatomy_hud(species_id: Variant) -> bool:
	return get_level(species_id) >= 2

## Nível 3: Diagnóstico genético no visor do Modo Foto (alelos TT/Tt/tt e mutações)
func has_unlocked_genetics(species_id: Variant) -> bool:
	return get_level(species_id) >= 3

## Lista de fraquezas conhecidas da espécie (ou vazia se não desbloqueada)
func get_species_weaknesses(species_id: Variant) -> Array:
	var key := normalize_species(species_id)
	if not has_unlocked_weaknesses(key):
		return []
	var data: Dictionary = SPECIES_CATALOG.get(key, {})
	return data.get("weaknesses", []).duplicate()

## Lista de partes anatômicas da espécie (ou vazia se não desbloqueada)
func get_species_parts(species_id: Variant) -> Array:
	var key := normalize_species(species_id)
	if not has_unlocked_weaknesses(key):
		return []
	var data: Dictionary = SPECIES_CATALOG.get(key, {})
	return data.get("parts", []).duplicate()

## Ficha detalhada da espécie com status de pesquisa
func get_species_entry(species_id: Variant) -> Dictionary:
	var key := normalize_species(species_id)
	var pts: int = get_points(key)
	var lvl: int = calculate_level(pts)
	var base_info: Dictionary = SPECIES_CATALOG.get(key, {
		"name": str(species_id).capitalize(),
		"weaknesses": ["Desconhecido"],
		"parts": ["Corpo Principal"],
		"description": "Espécime em estudo no Vale das Cepas."
	})
	
	var next_threshold: int = THRESHOLD_LV1
	if lvl == 1:
		next_threshold = THRESHOLD_LV2
	elif lvl == 2:
		next_threshold = THRESHOLD_LV3
	elif lvl >= 3:
		next_threshold = THRESHOLD_LV3
	
	return {
		"id": key,
		"name": base_info.get("name", str(key).capitalize()),
		"level": lvl,
		"points": pts,
		"next_threshold": next_threshold,
		"description": base_info.get("description", ""),
		"weaknesses": get_species_weaknesses(key),
		"parts": get_species_parts(key),
		"can_view_genetics": has_unlocked_genetics(key),
		"can_view_anatomy": has_unlocked_anatomy_hud(key)
	}

## Serialização para Save
func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for k in _research_points.keys():
		out[String(k)] = _research_points[k]
	return out

## Desserialização do Save
func from_dict(data: Dictionary) -> void:
	_research_points.clear()
	for k in data.keys():
		_research_points[StringName(k)] = int(data[k])
