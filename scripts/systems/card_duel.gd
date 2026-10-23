class_name CardDuel
extends RefCounted

## Duelo de Cepas (GDD-07 §7): regra pura da mesa da Taverna, sem tela. O servidor roda esta
## classe; o cliente só pede "baixar carta" e "encerrar turno". Jogador 0 é quem começa.

signal changed()

const START_LIFE: int = 15
const START_HAND: int = 4
const LANES: int = 3
const MAX_ETHER: int = 5
const MAX_ROUNDS: int = 15
const DECK_SIZE: int = 12
const COPIES: int = 3
const ADVANTAGE_DAMAGE: int = 2
const FILLER_ID: StringName = &"recruta"

## Quem ganha de quem: Água > Fogo > Ar > Terra > Raio > Água
const BEATS: Dictionary = {
	CardData.CardElement.WATER: CardData.CardElement.FIRE,
	CardData.CardElement.FIRE: CardData.CardElement.AIR,
	CardData.CardElement.AIR: CardData.CardElement.EARTH,
	CardData.CardElement.EARTH: CardData.CardElement.LIGHTNING,
	CardData.CardElement.LIGHTNING: CardData.CardElement.WATER,
}

var life: Array[int] = [START_LIFE, START_LIFE]
var ether: Array[int] = [0, 0]
var ether_max: Array[int] = [0, 0]
var hands: Array = [[], []]
var decks: Array = [[], []]
## board[p][lane] = {} vazio ou {"card": CardData, "poise": int, "fresh": bool, "burn": int}
var board: Array = [[{}, {}, {}], [{}, {}, {}]]
var current: int = 0
var round_num: int = 1
## -1 em jogo · 0/1 vencedor · 2 empate
var winner: int = -1
var log_lines: Array[String] = []
var _bonus_ether: Array[int] = [0, 0]
var _rng := RandomNumberGenerator.new()

## Carta de enchimento (não colecionável)
static var _filler: CardData

static func filler() -> CardData:
	if _filler == null:
		_filler = CardData.new(FILLER_ID, "Recruta de Taverna", "Taverna", CardData.Rarity.COMMON,
			CardData.CardElement.NEUTRAL, 1, 2, 3, "", "", "Freguês corajoso que topa qualquer briga de mesa.")
	return _filler

## 3 cópias de cada carta da coleção, completado com Recrutas até 12
static func build_deck(card_ids: Array) -> Array:
	var deck: Array = []
	for id in card_ids:
		var c := CardDatabase.get_card(StringName(id))
		if c:
			for k in COPIES:
				deck.append(c)
	while deck.size() < DECK_SIZE:
		deck.append(filler())
	return deck

func start(deck_a: Array, deck_b: Array, p_seed: int) -> void:
	_rng.seed = p_seed
	decks = [deck_a.duplicate(), deck_b.duplicate()]
	for p in 2:
		_shuffle(decks[p])
		for k in START_HAND:
			_draw(p)
	_log("A partida começou.")
	_begin_turn(0)

func is_over() -> bool:
	return winner != -1

func lane_free(p: int, lane: int) -> bool:
	return board[p][lane].is_empty()

## Baixa a carta `hand_index` na fileira `lane`. Devolve "" ou o motivo de não dar.
func play(p: int, hand_index: int, lane: int) -> String:
	if is_over() or p != current:
		return "Não é a sua vez"
	if hand_index < 0 or hand_index >= hands[p].size():
		return "Carta inválida"
	if lane < 0 or lane >= LANES or not lane_free(p, lane):
		return "Fileira ocupada"
	var card: CardData = hands[p][hand_index]
	if card.ether_cost > ether[p]:
		return "Falta Éter"
	ether[p] -= card.ether_cost
	hands[p].remove_at(hand_index)
	board[p][lane] = {"card": card, "poise": card.poise, "fresh": true, "burn": 0}
	_log("%s baixou %s." % [_who(p), card.title])
	_on_play(p, lane, card)
	changed.emit()
	return ""

## Fim do turno: cada carta ataca a fileira da frente; passa a vez.
func end_turn(p: int) -> void:
	if is_over() or p != current:
		return
	var foe := 1 - p
	for lane in LANES:
		var slot: Dictionary = board[p][lane]
		if slot.is_empty():
			continue
		_attack(p, lane, slot, foe)
		if is_over():
			break
	if not is_over():
		current = foe
		if current == 0:
			round_num += 1
			if round_num > MAX_ROUNDS:
				_finish_by_life()
		if not is_over():
			_begin_turn(current)
	changed.emit()

## Vez da Taverneira (ou de um bot): baixa o que der, das mais caras para as mais baratas, e encerra.
func ai_turn(p: int) -> void:
	if is_over() or p != current:
		return
	var foe := 1 - p
	var played := true
	while played:
		played = false
		var order: Array = range(hands[p].size())
		order.sort_custom(func(a, b): return hands[p][a].ether_cost > hands[p][b].ether_cost)
		for i in order:
			var card: CardData = hands[p][i]
			if card.ether_cost > ether[p]:
				continue
			var lane := _best_lane(p, foe, card)
			if lane >= 0 and play(p, i, lane) == "":
				played = true
				break
	end_turn(p)

# ---------------------------------------------------------------- regras

func _begin_turn(p: int) -> void:
	ether_max[p] = mini(MAX_ETHER, ether_max[p] + 1)
	ether[p] = ether_max[p] + _bonus_ether[p]
	_bonus_ether[p] = 0
	# Queimadura: a carta queimada perde 2 no começo do turno do dono
	for lane in LANES:
		var slot: Dictionary = board[p][lane]
		if not slot.is_empty() and slot.burn > 0:
			slot.burn -= 1
			_hurt(p, lane, 2, "queimadura")
	if decks[p].is_empty():
		life[p] -= 1
		_log("%s não tem carta para comprar e perde 1 de Vida." % _who(p))
		_check_life()
	else:
		_draw(p)

func _on_play(p: int, lane: int, card: CardData) -> void:
	match card.id:
		&"element_earth":
			for side in [lane - 1, lane + 1]:
				if side >= 0 and side < LANES and not board[p][side].is_empty():
					board[p][side].poise += 2
		&"polinization":
			var worst := -1
			var lost := 0
			for l in LANES:
				var s: Dictionary = board[p][l]
				if l != lane and not s.is_empty() and s.card.poise - s.poise > lost:
					lost = s.card.poise - s.poise
					worst = l
			if worst >= 0:
				board[p][worst].poise = mini(board[p][worst].card.poise, board[p][worst].poise + 3)
		&"coin":
			_draw(p)

func _attack(p: int, lane: int, slot: Dictionary, foe: int) -> void:
	var card: CardData = slot.card
	var target: Dictionary = board[foe][lane]
	var dmg := card.power
	if slot.fresh and card.id == &"mimic":
		dmg *= 2
	slot.fresh = false
	if target.is_empty():
		life[foe] -= dmg
		_log("%s acerta %s direto: −%d de Vida." % [card.title, "você" if foe == 0 else "a Taverneira", dmg])
		_check_life()
		return
	if BEATS.get(card.element, -1) == target.card.element:
		dmg += ADVANTAGE_DAMAGE
	if card.id == &"beast_horn":
		dmg = ceili(dmg * 1.5)
	if card.id == &"fireball":
		target.burn = 2
	_log("%s bate em %s: −%d de Postura." % [card.title, target.card.title, dmg])
	var target_card: CardData = target.card
	_hurt(foe, lane, dmg, "")
	# Enxame Protetor: quem bate na colmeia leva 1
	if target_card.id == &"beehive":
		_hurt(p, lane, 1, "enxame")

func _hurt(p: int, lane: int, dmg: int, why: String) -> void:
	var slot: Dictionary = board[p][lane]
	if slot.is_empty():
		return
	slot.poise -= dmg
	if why != "":
		_log("%s sofre %d (%s)." % [slot.card.title, dmg, why])
	if slot.poise <= 0:
		_log("%s caiu." % slot.card.title)
		if slot.card.id == &"trenchcoat_mushrooms":
			_bonus_ether[p] += 1
		board[p][lane] = {}

func _best_lane(p: int, foe: int, card: CardData) -> int:
	var best := -1
	var best_score := -INF
	for lane in LANES:
		if not lane_free(p, lane):
			continue
		var enemy: Dictionary = board[foe][lane]
		var score := 0.0
		if enemy.is_empty():
			score = 1.0  # bate direto na Vida
		else:
			# Prefere segurar a carta mais forte do rival e ganhar no elemento
			score = enemy.card.power * 0.6 + (3.0 if BEATS.get(card.element, -1) == enemy.card.element else 0.0)
			score += 2.0 if card.power >= enemy.poise else 0.0
		if score > best_score:
			best_score = score
			best = lane
	return best

func _check_life() -> void:
	if life[0] <= 0 and life[1] <= 0:
		winner = 2
	elif life[0] <= 0:
		winner = 1
	elif life[1] <= 0:
		winner = 0
	if winner != -1:
		_log("Fim de jogo.")

func _finish_by_life() -> void:
	winner = 2 if life[0] == life[1] else (0 if life[0] > life[1] else 1)
	_log("Acabaram as rodadas: decide a Vida.")

func _draw(p: int) -> void:
	if not decks[p].is_empty():
		hands[p].append(decks[p].pop_back())

func _shuffle(deck: Array) -> void:
	for i in range(deck.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = deck[i]
		deck[i] = deck[j]
		deck[j] = t

func _who(p: int) -> String:
	return "Você" if p == 0 else "A Taverneira"

func _log(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > 40:
		log_lines.pop_front()
