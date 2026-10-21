class_name CardCollectionComponent
extends Node

## Gerencia o catálogo de Cartas 3D colecionáveis do jogador (GDD-07 e B08).
## Registra cartas descobertas por marcos de caça, mutação e economia.

signal card_unlocked(card: CardData)
## Só para descobertas em jogo (não para cartas iniciais nem restauradas do save): dispara a animação de carta nova
signal card_discovered(card: CardData)
signal collection_updated()

@export var give_starter_cards: bool = true

# Lista de IDs de cartas já destrancadas pelo jogador
var _unlocked_ids: Array[StringName] = []

func _init(p_starter: bool = true) -> void:
	give_starter_cards = p_starter
	if give_starter_cards:
		add_starter_cards()

func _ready() -> void:
	if give_starter_cards and _unlocked_ids.is_empty():
		add_starter_cards()

## Concede as cartas iniciais do andarilho
func add_starter_cards() -> void:
	unlock_card(&"element_earth", false)
	unlock_card(&"coin", false)
	unlock_card(&"trenchcoat_mushrooms", false)

## Destranca uma nova carta pelo ID. announce = false para restaurar o save sem anunciar
func unlock_card(card_id: StringName, announce: bool = true) -> bool:
	if card_id.is_empty() or is_card_unlocked(card_id):
		return false
	
	var card: CardData = CardDatabase.get_card(card_id)
	if card == null:
		push_warning("CardCollectionComponent: Carta não encontrada no banco: %s" % card_id)
		return false
	
	_unlocked_ids.append(card_id)
	card_unlocked.emit(card)
	if announce:
		card_discovered.emit(card)
	collection_updated.emit()
	return true

## Verifica se uma carta já foi destrancada
func is_card_unlocked(card_id: StringName) -> bool:
	return _unlocked_ids.has(card_id)

## Retorna lista de IDs destrancados
func get_unlocked_ids() -> Array[StringName]:
	return _unlocked_ids.duplicate()

## Retorna instâncias de CardData de todas as cartas destrancadas
func get_unlocked_cards() -> Array[CardData]:
	var list: Array[CardData] = []
	for id in _unlocked_ids:
		var c: CardData = CardDatabase.get_card(id)
		if c != null:
			list.append(c)
	return list

## Retorna métricas de progresso da coleção
func get_progress() -> Dictionary:
	var total: int = CardDatabase.get_total_count()
	var unlocked: int = _unlocked_ids.size()
	var ratio: float = float(unlocked) / float(maxi(total, 1))
	return {
		"unlocked": unlocked,
		"total": total,
		"ratio": ratio,
		"percent": ratio * 100.0
	}
