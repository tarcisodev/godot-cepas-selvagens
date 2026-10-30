class_name SkyIslandField
extends Node3D

## Céu de ilhas voadoras (GDD-18). Lê a agenda (seed + relógio único) a cada meio segundo, cria e
## tira ilhas e move as que derivam. Também responde à montaria voadora: o chão de cima da ilha,
## a base que não se atravessa e a Corrente de vento que leva acima do teto de 40 m (§4).

## Corrente: raio da coluna, quanto ela encosta por dentro da borda, quanto passa do topo da
## ilha e a velocidade com que sobe (m, m, m, m/s)
const CURRENT_RADIUS: float = 8.0
const CURRENT_OVERLAP: float = 2.0
const CURRENT_OVERSHOOT: float = 12.0
const CURRENT_LIFT: float = 8.0
## Até este tanto abaixo do topo a montaria ainda "está em cima" da ilha (degrau que ela sobe)
const STEP_UP: float = 1.5
const REFRESH: float = 0.5

static var instance: SkyIslandField

@export var world_seed: int = 2026
## Dia fixo (testes e prints); negativo segue o relógio único
@export var fixed_day: float = -1.0

## Ilhas no mundo, por id
var islands: Dictionary = {}
var _timer: float = 0.0

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _ready() -> void:
	add_to_group("sky_islands")
	refresh()

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = REFRESH
		refresh()

func day() -> float:
	return fixed_day if fixed_day >= 0.0 else SkyIslandSchedule.game_day()

## Põe o céu no estado da agenda: cria as que surgiram, tira as que acabaram, move as outras
func refresh(at_day: float = -1.0) -> void:
	var d := at_day if at_day >= 0.0 else day()
	var wanted := SkyIslandSchedule.islands_at(world_seed, d)
	var seen: Dictionary = {}
	for isl in wanted:
		seen[isl.id] = true
		var node: SkyIsland = islands.get(isl.id)
		if node == null:
			node = SkyIsland.new()
			# Nasce já no lugar: o corpo carrega o que toca, e criada na origem levava junto
			# quem estivesse lá (o jogador na vila) até o céu
			node.position = isl.center - global_position
			add_child(node)
			node.setup(isl)
			islands[isl.id] = node
		else:
			node.apply(isl)
	for id in islands.keys():
		if not seen.has(id):
			islands[id].queue_free()
			islands.erase(id)

func list() -> Array[SkyIsland]:
	var out: Array[SkyIsland] = []
	for n in islands.values():
		out.append(n)
	return out

# ---------------------------------------------------------------- consultas da montaria

## Chão em (x, z) para quem está na altura y: o topo de uma ilha logo abaixo, ou o terreno
static func ground_at(x: float, z: float, y: float, terrain: float) -> float:
	if not is_instance_valid(instance):
		return terrain
	var best := terrain
	for isl: SkyIsland in instance.islands.values():
		if not isl.is_solid():
			continue
		var t := isl.top_at(x, z)
		if t > -INF and y >= t - STEP_UP:
			best = maxf(best, t)
	return best

## Teto que a base de uma ilha impõe a quem está embaixo dela (INF se nenhuma)
static func underside_at(x: float, z: float, y: float) -> float:
	if not is_instance_valid(instance):
		return INF
	var best := INF
	for isl: SkyIsland in instance.islands.values():
		if not isl.is_solid():
			continue
		var t := isl.top_at(x, z)
		if t > -INF and y < t - STEP_UP:
			best = minf(best, isl.bottom_at(x, z) - 1.0)
	return best

## Ilha cuja Corrente contém o ponto (null se nenhuma)
static func current_at(p: Vector3) -> SkyIsland:
	if not is_instance_valid(instance):
		return null
	for isl: SkyIsland in instance.islands.values():
		if isl.in_current(p):
			return isl
	return null
