class_name MountBond
extends RefCounted

## Elo entre o dono e uma montaria própria (GDD-16): 0 a 100, sobe com o que vivem juntos
## e cai com fome e dano. Cada ganho tem teto por dia de jogo (o dia vem do relógio único,
## ADR-0006). Lógica pura e serializável: no online quem chama estas funções é o servidor
## (ADR-0002); o cliente só mostra.

enum Order { STAY, FOLLOW }

const ELO_MAX: float = 100.0
## Faixas (GDD-16 §2): Arisca 0–24 · Mansa 25–49 · Parceira 50–74 · Companheira plena 75–100
const BAND_MIN: Array[float] = [0.0, 25.0, 50.0, 75.0]
const BAND_NAMES: Array[String] = ["Arisca", "Mansa", "Parceira", "Companheira plena"]
const UNLOCKS: Array[String] = ["montaria comum", "pode ser Companheira; ouve o apito a 60 m", "apito a 150 m; Faro",
	"apito a 300 m; pegada no ar; Olho de caça"]
## Alcance do apito por faixa (m); Arisca não ouve
const WHISTLE_RANGE: Array[float] = [0.0, 60.0, 150.0, 300.0]
## Elo de partida por caminho (GDD-16 §4)
const START_ELO: Dictionary = {&"laco": 10.0, &"cria": 40.0, &"ninho": 50.0, &"eclipse": 30.0}
## Andar montado: +1 a cada 2 min reais, até +6 por dia de jogo
const RIDE_SECONDS_PER_POINT: float = 120.0
const RIDE_DAY_CAP: float = 6.0
const FEED_GAIN: float = 3.0
const CARE_GAIN: float = 2.0
const FIGHT_GAIN: float = 2.0
const FIGHT_DAY_CAP: int = 2
const HURT_LOSS: float = 2.0
## Fome: depois de 2 dias de jogo sem comer, −4 por dia
const HUNGER_GRACE_DAYS: int = 2
const HUNGER_LOSS: float = 4.0
## Com Elo 50 a capturada no laço passa a aceitar só o dono
const MARK_ELO: float = 50.0
## Comida que a espécie come na natureza (GDD-04): só ela conta para o Elo
const DIET: Dictionary = {
	CreatureDNA.Species.TROTADOR: [&"frutinha", &"folha", &"erva"],
	CreatureDNA.Species.PLANADOR: [&"peixe_lambari", &"pinhao_lume"],
}

var elo: float = 0.0
var mount_name: String = ""
## Criada desde filhote ou ganha no ninho: só aceita o dono
var marked: bool = false
var companion: bool = false
var order: Order = Order.STAY
## Índole vinda do DNA (&"ousada", &"equilibrada", &"mansa", &"leal")
var temperament: StringName = &"equilibrada"
var species: CreatureDNA.Species = CreatureDNA.Species.TROTADOR

var _ride_day: int = -1
var _ride_gain_today: float = 0.0
var _ride_seconds: float = 0.0
var _fed_day: int = -1
var _care_day: int = -1
var _fight_day: int = -1
var _fights_today: int = 0
var _last_meal_day: int = 0
var _hunger_day: int = 0

## Dia de jogo do relógio único (ADR-0006); 0 sem sol (testes)
static func today() -> int:
	return DayNightCycle.instance.day_count if DayNightCycle.instance else 0

static func create(dna: CreatureDNA, origin: StringName, day: int) -> MountBond:
	var b := MountBond.new()
	b.species = dna.species
	b.temperament = dna.temperament()
	b.elo = START_ELO.get(origin, 10.0)
	b.marked = origin != &"laco"
	b._last_meal_day = day
	b._hunger_day = day
	return b

func band() -> int:
	for i in range(BAND_MIN.size() - 1, -1, -1):
		if elo >= BAND_MIN[i]:
			return i
	return 0

func band_name() -> String:
	return BAND_NAMES[band()]

func whistle_range() -> float:
	return WHISTLE_RANGE[band()]

func can_be_companion() -> bool:
	return band() >= 1

## Marcada (cria/ninho) ou capturada com Elo 50+: só o dono monta
func accepts(is_owner: bool) -> bool:
	return is_owner or not (marked or elo >= MARK_ELO)

func display_name(fallback: String) -> String:
	return mount_name if not mount_name.is_empty() else fallback

## Batiza (até 16 letras); false se o nome ficar vazio
func rename(new_name: String) -> bool:
	var n := new_name.strip_edges().left(16)
	if n.is_empty():
		return false
	mount_name = n
	return true

func eats(food: StringName) -> bool:
	return DIET.get(species, []).has(food)

## Segundos montado; devolve o Elo ganho agora
func add_ride_time(seconds: float, day: int) -> float:
	if day != _ride_day:
		_ride_day = day
		_ride_gain_today = 0.0
	if _ride_gain_today >= RIDE_DAY_CAP:
		return 0.0
	_ride_seconds += seconds
	var gain := 0.0
	while _ride_seconds >= RIDE_SECONDS_PER_POINT and _ride_gain_today < RIDE_DAY_CAP:
		_ride_seconds -= RIDE_SECONDS_PER_POINT
		_ride_gain_today += 1.0
		gain += 1.0
	return _add(gain)

## Alimenta: a fome zera sempre; o Elo só sobe com a comida da espécie, 1× por dia de jogo
func feed(food: StringName, day: int) -> float:
	if not eats(food):
		return 0.0
	_last_meal_day = day
	_hunger_day = day
	if _fed_day == day:
		return 0.0
	_fed_day = day
	return _add(FEED_GAIN * _mult(&"mansa", &"ousada"))

## Escovar e tratar no estábulo, 1× por dia de jogo
func care(day: int) -> float:
	if _care_day == day:
		return 0.0
	_care_day = day
	return _add(CARE_GAIN * (2.0 if temperament == &"mansa" else 1.0))

## Inimigo ferido ou fuga com ela montada; até 2 vezes por dia de jogo
func fight(day: int) -> float:
	if day != _fight_day:
		_fight_day = day
		_fights_today = 0
	if _fights_today >= FIGHT_DAY_CAP:
		return 0.0
	_fights_today += 1
	return _add(FIGHT_GAIN * _mult(&"ousada", &"mansa"))

## Golpe forte nela com o dono montado
func hurt() -> float:
	return _add(-HURT_LOSS * (2.0 if temperament == &"mansa" else 1.0))

## Passa os dias de jogo até `day`: cada dia além da carência sem comer tira Elo (Leal não perde)
func tick_hunger(day: int) -> float:
	var lost := 0.0
	while _hunger_day < day:
		_hunger_day += 1
		if _hunger_day - _last_meal_day > HUNGER_GRACE_DAYS and temperament != &"leal":
			lost += _add(-HUNGER_LOSS)
	return lost

func is_hungry(day: int) -> bool:
	return day - _last_meal_day >= HUNGER_GRACE_DAYS

## Trocou de Companheira: a antiga volta a Arisca (ciúme), menos a Leal
func jealous() -> void:
	companion = false
	order = Order.STAY
	if temperament != &"leal":
		elo = minf(elo, BAND_MIN[1] - 1.0)

func to_dict() -> Dictionary:
	return {"elo": elo, "name": mount_name, "marked": marked, "companion": companion, "order": int(order),
		"meal": _last_meal_day, "hunger": _hunger_day, "fed": _fed_day, "care": _care_day,
		"ride_day": _ride_day, "ride_gain": _ride_gain_today, "ride_s": _ride_seconds,
		"fight_day": _fight_day, "fights": _fights_today}

static func from_dict(d: Dictionary, dna: CreatureDNA) -> MountBond:
	var b := MountBond.new()
	b.species = dna.species
	b.temperament = dna.temperament()
	b.elo = clampf(float(d.get("elo", START_ELO[&"laco"])), 0.0, ELO_MAX)
	b.mount_name = str(d.get("name", ""))
	b.marked = bool(d.get("marked", false))
	b.companion = bool(d.get("companion", false))
	b.order = int(d.get("order", 0)) as Order
	b._last_meal_day = int(d.get("meal", 0))
	b._hunger_day = int(d.get("hunger", b._last_meal_day))
	b._fed_day = int(d.get("fed", -1))
	b._care_day = int(d.get("care", -1))
	b._ride_day = int(d.get("ride_day", -1))
	b._ride_gain_today = float(d.get("ride_gain", 0.0))
	b._ride_seconds = float(d.get("ride_s", 0.0))
	b._fight_day = int(d.get("fight_day", -1))
	b._fights_today = int(d.get("fights", 0))
	return b

func _mult(double_for: StringName, half_for: StringName) -> float:
	return 2.0 if temperament == double_for else (0.5 if temperament == half_for else 1.0)

func _add(amount: float) -> float:
	var before := elo
	elo = clampf(elo + amount, 0.0, ELO_MAX)
	return elo - before
