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
## Conteúdo da ilha (flora, veios, baú, ninho) nasce com um jogador a NEAR metros e some quando
## não há ninguém a FAR metros (a folga evita nascer e sumir na beirada)
const CONTENT_NEAR: float = 150.0
const CONTENT_FAR: float = 200.0

static var instance: SkyIslandField

@export var world_seed: int = 2026
## Dia fixo (testes e prints); negativo segue o relógio único
@export var fixed_day: float = -1.0

## Ilhas no mundo, por id
var islands: Dictionary = {}
## O que já foi pego em cada ilha, pela chave ilha@época (SkyIslandContent.capture_state)
var content_state: Dictionary = {}
## Avisos de afundamento já dados: "id do jogador|ilha|etapa" → true
var _told: Dictionary = {}
var _timer: float = 0.0
## Rajadas, Corrente da lendária e raios (GDD-18 §8)
var hazards: SkyIslandHazards

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _ready() -> void:
	add_to_group("sky_islands")
	hazards = SkyIslandHazards.new()
	hazards.name = "Perigos"
	add_child(hazards)
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
			_drop_state(islands[id])
			for k in _told.keys():
				if ("|%s|" % id) in k:
					_told.erase(k)
			islands[id].queue_free()
			islands.erase(id)
	_update_content()
	_warn_players()
	_update_eclipse(d)

# ---------------------------------------------------------------- save (GDD-18 §5)

## Só o que muda vai para o save: forma, posição e hora saem da seed e do relógio
func get_state() -> Dictionary:
	for isl: SkyIsland in islands.values():
		store_content(isl)
	return {"content": content_state.duplicate(true)}

func apply_state(d: Dictionary) -> void:
	content_state = (d.get("content", {}) as Dictionary).duplicate(true)
	# O que está no mundo agora nasceu sem o save: refaz com o estado salvo
	for isl: SkyIsland in islands.values():
		if isl.content:
			isl.content.queue_free()
			isl.content = null
	refresh()
	# Ilhas que já saíram do céu (a rara trocou de lugar enquanto o jogo estava fechado)
	for k in content_state.keys():
		var id := StringName(String(k).get_slice("@", 0))
		if not islands.has(id):
			content_state.erase(k)

# ---------------------------------------------------------------- aviso de afundamento

## Quem está em cima de uma ilha que vai afundar recebe o aviso uma vez por etapa: quando ela
## começa a tremer (com o tempo que falta) e quando começa a descer
func _warn_players() -> void:
	for isl: SkyIsland in islands.values():
		var stage := &"afundando" if isl.data.phase == &"afundando" else (&"tremendo" if isl.data.warning else &"")
		if stage.is_empty():
			continue
		for p in get_tree().get_nodes_in_group("player"):
			if not (p is Node3D) or not on_island(isl, (p as Node3D).global_position):
				continue
			var key := "%d|%s|%s" % [p.get_instance_id(), isl.data.id, stage]
			if _told.has(key):
				continue
			_told[key] = true
			if p.has_signal("posture_changed"):
				p.posture_changed.emit(warning_text(isl, day()))

## Eclipse do Arquipélago (GDD-18 §7.4): sobe do anúncio até a subida, fica no evento e volta no
## afundamento. Todo jogador recebe uma vez o aviso de que o arquipélago vai subir.
func _update_eclipse(d: float) -> void:
	var w := SkyIslandSchedule.next_myth(world_seed, d)
	var e := eclipse_at(w, d)
	var sun := DayNightCycle.instance
	if is_instance_valid(sun):
		sun.eclipse = e
	if w != Vector3.INF and d >= w.x and d < w.y:
		var key := "anuncio|%d" % roundi(w.y * 1000.0)
		for p in get_tree().get_nodes_in_group("player"):
			var pk := "%d|%s" % [p.get_instance_id(), key]
			if _told.has(pk) or not p.has_signal("posture_changed"):
				continue
			_told[pk] = true
			var mins := maxi(1, roundi((w.y - d) * DayNightCycle.seconds_per_day() / 60.0))
			p.posture_changed.emit("🌑 O céu escurece: o Arquipélago do Eclipse sobe em ~%d min." % mins)

## Quanto do eclipse em `d`, para a janela [anúncio, subida, fim] da mítica
static func eclipse_at(w: Vector3, d: float) -> float:
	if w == Vector3.INF or d < w.x or d >= w.z:
		return 0.0
	if d < w.y:
		return clampf((d - w.x) / maxf(w.y - w.x, 0.0001), 0.0, 1.0)
	var rise := SkyIslandSchedule.days(SkyIslandSchedule.RISE_S)
	return clampf((w.z - d) / rise, 0.0, 1.0)

## Texto do aviso para quem está na ilha
static func warning_text(isl: SkyIsland, at_day: float) -> String:
	var name := "%s %s" % [SkyIslandSchedule.ARTICLES[isl.rarity()], SkyIslandSchedule.NAMES[isl.rarity()]]
	if isl.data.phase == &"afundando":
		return "⚠️ %s está afundando! Saia agora ou caia junto." % name
	var secs := maxf(0.0, (float(isl.data.sinks_at) - at_day) * DayNightCycle.seconds_per_day())
	var left := "~%d min" % roundi(secs / 60.0) if secs >= 90.0 else "~%d s" % roundi(secs)
	return "⚠️ %s está tremendo e rachando: afunda em %s." % [name, left]

## (x, y, z) está em cima da ilha (no topo ou até 6 m acima dele, a pé ou montado)?
static func on_island(isl: SkyIsland, p: Vector3) -> bool:
	var t := isl.top_at(p.x, p.z)
	return t > -INF and p.y >= t - STEP_UP and p.y <= t + 6.0

## Ilha rara ou acima em que o ponto está (no topo): Zona Selvagem, PvP e full loot (GDD-18 §8)
static func wild_island_at(p: Vector3) -> SkyIsland:
	if not is_instance_valid(instance):
		return null
	for isl: SkyIsland in instance.islands.values():
		if isl.is_solid() and isl.rarity() >= SkyIslandSchedule.Rarity.RARA and on_island(isl, p):
			return isl
	return null

## Cria o conteúdo das ilhas com gente perto, guarda e tira o das que ficaram sozinhas, e troca o
## das que viraram de época (a incomum se renova a cada 4 dias de jogo)
func _update_content() -> void:
	var players: Array[Vector3] = []
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node3D:
			players.append((p as Node3D).global_position)
	for isl: SkyIsland in islands.values():
		var c := isl.content
		var key := SkyIslandContent.key_for(isl.data)
		if c and c.key != key:
			c.queue_free()
			isl.content = null
			c = null
		_drop_state(isl, key)
		var near := INF
		for p in players:
			near = minf(near, p.distance_to(isl.global_position))
		if c == null and isl.is_solid() and near <= CONTENT_NEAR:
			c = SkyIslandContent.new()
			isl.add_child(c)
			c.setup(isl, content_state.get(key, {}))
			isl.content = c
		elif c and (near > CONTENT_FAR or not isl.is_solid()) and not c.busy():
			store_content(isl)
			c.queue_free()
			isl.content = null

## Guarda o estado do conteúdo que está no mundo (antes de ele sumir, ou para o save)
func store_content(isl: SkyIsland) -> void:
	if isl.content == null:
		return
	var st := isl.content.capture_state()
	if st.is_empty():
		content_state.erase(isl.content.key)
	else:
		content_state[isl.content.key] = st

## Esquece o que foi pego nas épocas da ilha que não são `keep` (sem `keep`: todas). A ilha saiu
## do céu (a rara trocou de lugar, a lendária afundou) ou se renovou: o que tinha nela acabou.
func _drop_state(isl: SkyIsland, keep: String = "") -> void:
	var prefix := String(isl.data.id) + "@"
	for k in content_state.keys():
		if String(k).begins_with(prefix) and k != keep:
			content_state.erase(k)

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
