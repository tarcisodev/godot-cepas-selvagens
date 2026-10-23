class_name TavernTable
extends Node3D

## Mesa do Duelo de Cepas na porta da Taverna (GDD-07 §7). A Taverneira joga contra você
## quando a obra Taverna está pronta. Aposta 0/5/10/20 $S; a casa fica com 10% do pote.
## Cada vitória dá a próxima carta da lista de prêmios que você ainda não tem.

const TABLE_SCENE = preload("res://assets/models/props/fantasy/Table_Large.gltf")
const CHAIR_SCENE = preload("res://assets/models/props/fantasy/Chair_1.gltf")
const MUG_SCENE = preload("res://assets/models/props/fantasy/Mug.gltf")

const BETS: Array[int] = [0, 5, 10, 20]
const HOUSE_CUT: float = 0.10
const HOST_DECK: Array[StringName] = [&"beehive", &"fireball", &"element_earth"]
const PRIZES: Array[StringName] = [&"beehive", &"fireball", &"polinization"]

var city: Node  # CityHub
var duel: CardDuel
var bet: int = 0
var _player: Player
var _screen: CardTableScreen

func _ready() -> void:
	var table := TABLE_SCENE.instantiate() as Node3D
	table.scale = Vector3.ONE * 0.8
	add_child(table)
	for side in [-1.0, 1.0]:
		var chair := CHAIR_SCENE.instantiate() as Node3D
		chair.position = Vector3(0, 0, side * 1.1)
		chair.rotation.y = 0.0 if side > 0 else PI
		add_child(chair)
	var mug := MUG_SCENE.instantiate() as Node3D
	mug.position = Vector3(0.4, 0.78, 0.2)
	add_child(mug)

	var host := TownNPC.new()
	host.name = "Taverneira"
	host.display_name = "Taverneira"
	host.prompt = "[E] Duelo de Cepas"
	host.idle_anim = &"Idle_Talking"
	host.position = Vector3(0, 0, -1.5)
	host.talked.connect(open_for)
	add_child(host)

	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_screen = CardTableScreen.new()
	_screen.table = self
	layer.add_child(_screen)

func is_open() -> bool:
	var taverna = city.get_project(&"taverna") if city and city.has_method("get_project") else null
	return taverna == null or taverna.is_complete()

func open_for(player: Node) -> void:
	var p := player as Player
	if p == null:
		return
	if not is_open():
		p.posture_changed.emit("Taverneira: 'A mesa só sai quando a Taverna ficar pronta. Ajude no Quadro de Obras!'")
		return
	_player = p
	_screen.open(p)

## Começa uma partida apostando `amount`. Devolve "" ou o motivo de não dar.
func start_match(player: Player, amount: int, p_seed: int = -1) -> String:
	if not is_open():
		return "A Taverna ainda está em obras"
	if not BETS.has(amount):
		return "Aposta inválida"
	if amount > 0 and (player.wallet == null or not player.wallet.spend(amount)):
		return "Falta dinheiro para a aposta"
	_player = player
	bet = amount
	var mine: Array = player.card_collection.get_unlocked_ids() if player.card_collection else []
	duel = CardDuel.new()
	duel.start(CardDuel.build_deck(mine), CardDuel.build_deck(HOST_DECK), p_seed if p_seed >= 0 else randi())
	return ""

## Paga o resultado: vitória leva 2× a aposta menos a casa e a próxima carta-prêmio; empate devolve.
## Devolve {"money": ganho, "card": CardData ou null}.
func settle() -> Dictionary:
	var out := {"money": 0, "card": null}
	if duel == null or not duel.is_over() or _player == null:
		return out
	if duel.winner == 0:
		out.money = payout(bet)
		var cards := _player.card_collection
		for id in PRIZES:
			if cards and not cards.is_card_unlocked(id):
				cards.unlock_card(id)
				out.card = CardDatabase.get_card(id)
				break
	elif duel.winner == 2:
		out.money = bet
	if out.money > 0 and _player.wallet:
		_player.wallet.add(out.money)
	duel = null
	return out

## Desistir no meio: a aposta fica com a Taverneira
func forfeit() -> void:
	duel = null

static func payout(amount: int) -> int:
	return amount * 2 - ceili(amount * 2 * HOUSE_CUT)
