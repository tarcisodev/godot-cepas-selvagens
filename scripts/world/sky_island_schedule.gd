class_name SkyIslandSchedule
extends RefCounted

## Agenda do céu (GDD-18 §5): função pura de seed do mundo + relógio único → ilhas ativas.
## Todo cliente calcula a mesma coisa (como o terreno do mapa); nenhuma ilha depende de quem
## está logado. O servidor só guarda o que muda (veio, baú, chefe), nunca posição nem hora.
## Tempo em dias de jogo (DayNightCycle.day_count + hora / 24).

enum Rarity { COMUM, INCOMUM, RARA, LENDARIA, MITICA }

const NAMES: Array[String] = ["Ilhota", "Ilha de Musgo", "Ilha da Ventania", "Ilha-Ruína", "Arquipélago do Eclipse"]
const RARITY_NAMES: Array[String] = ["Comum", "Incomum", "Rara", "Lendária", "Mítica"]
## Artigo do nome (o Arquipélago é masculino)
const ARTICLES: Array[String] = ["A", "A", "A", "A", "O"]

## Por raridade: quantas ao mesmo tempo, diâmetro (m), altura do chão da ilha acima do vale (m)
## e relevo do topo (m). As faixas de altura não se encostam: o topo mais alto de uma raridade
## (altura + relevo) fica abaixo da base mais funda da seguinte (SkyIslandShape.max_drop).
const SPECS: Dictionary = {
	Rarity.COMUM: {"count": 6, "diam": Vector2(18.0, 28.0), "height": Vector2(55.0, 65.0), "relief": 1.2},
	Rarity.INCOMUM: {"count": 3, "diam": Vector2(30.0, 45.0), "height": Vector2(80.0, 90.0), "relief": 2.0},
	Rarity.RARA: {"count": 2, "diam": Vector2(45.0, 65.0), "height": Vector2(105.0, 115.0), "relief": 2.0},
	Rarity.LENDARIA: {"count": 1, "diam": Vector2(65.0, 90.0), "height": Vector2(130.0, 140.0), "relief": 2.0},
	Rarity.MITICA: {"count": 1, "diam": Vector2(90.0, 90.0), "height": Vector2(155.0, 165.0), "relief": 2.0},
}
## Base em cone: fundura = diâmetro × DEPTH_RATIO, no máximo MAX_DEPTH
const DEPTH_RATIO: float = 0.35
const MAX_DEPTH: float = 10.0
## Ilhas ficam dentro desta fração do vale e longe da vila
const AREA: float = 0.8
const VILLAGE_MARGIN: float = 30.0
## Distância mínima entre bordas de ilhas da mesma raridade (m)
const GAP: float = 12.0
## Ilhotas com ninho de Planador (GDD-18 §3), sorteadas pela seed
const NEST_COMMONS: int = 2

## Incomum: gira em volta de um ponto fixo (~2 m por minuto real com o dia de 5 min);
## o conteúdo se renova a cada RENEW_DAYS
const ORBIT_RADIUS: float = 18.0
const ORBIT_SPEED: float = 0.55
const RENEW_DAYS: float = 4.0
## Rara: deriva em linha reta e troca de lugar a cada RARE_DAYS; a segunda vaga anda meia
## volta atrás e fica na outra metade do vale (x > 0), para as duas nunca se encostarem
const RARE_DAYS: float = 2.0
const RARE_DRIFT: float = 40.0
## Lendária e mítica contam em tempo real (P7 do GDD-18): com o dia de jogo curto, horas de jogo
## virariam minutos e não dariam tempo de subir, lutar e minerar. Viram dias de jogo pela duração
## do dia do relógio único (DayNightCycle.seconds_per_day), igual em todo cliente.
## Lendária: uma a cada ~4 h reais, por 45 min
const LEGEND_CYCLE_S: float = 4.0 * 3600.0
const LEGEND_S: float = 45.0 * 60.0
## Mítica: uma a cada ~12 h reais, por 20 min, anunciada 5 min antes
const MYTH_CYCLE_S: float = 12.0 * 3600.0
const MYTH_S: float = 20.0 * 60.0
const ANNOUNCE_S: float = 5.0 * 60.0
## Surgir e afundar levam 1 min real e percorrem SINK_DEPTH metros
const RISE_S: float = 60.0
const SINK_DEPTH: float = 40.0
## Antes de afundar, a ilha treme e racha por 2 min reais: tempo de quem está em cima ir embora
const WARN_S: float = 120.0
## Ilhotas satélites do Arquipélago do Eclipse (GDD-18 §7.4): quantas, diâmetro, quanto ficam abaixo
## do chão do núcleo, folga até a borda dele (m) e quantas têm ninho do Eclipse
const SATELLITES: int = 4
const SAT_DIAM: Vector2 = Vector2(14.0, 20.0)
const SAT_DROP: float = 1.5
const SAT_GAP: float = 10.0
const SAT_NESTS: int = 2

## Segundos reais em dias de jogo
static func days(seconds: float) -> float:
	return seconds / DayNightCycle.seconds_per_day()

## Dia de jogo corrido, com fração (0 sem sol no mundo)
static func game_day() -> float:
	var sun := DayNightCycle.instance
	if not is_instance_valid(sun):
		return 0.0
	return float(sun.day_count) + sun.current_time_hours / 24.0

## Ilhas ativas no dia `day`: lista de dicionários com
## id, rarity, slot, epoch, center (x, topo, z), radius, depth, relief, shape_seed, current_angle,
## phase (&"anunciada", &"surgindo", &"firme", &"afundando"), warning (treme antes de afundar),
## sinks_at e ends_at (dias), solid e nest.
static func islands_at(world_seed: int, day: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var commons := _commons(world_seed)
	out.append_array(commons)
	for slot in SPECS[Rarity.INCOMUM].count:
		out.append(_uncommon(world_seed, slot, day, commons))
	for slot in SPECS[Rarity.RARA].count:
		out.append(_rare(world_seed, slot, day, commons))
	var legend := _event(world_seed, Rarity.LENDARIA, day, days(LEGEND_CYCLE_S), days(LEGEND_S), 0.0, commons)
	if not legend.is_empty():
		out.append(legend)
	var myth := _event(world_seed, Rarity.MITICA, day, days(MYTH_CYCLE_S), days(MYTH_S), days(ANNOUNCE_S), commons)
	if not myth.is_empty():
		out.append(myth)
		out.append_array(_satellites(world_seed, myth))
	return out

## Próxima ilha mítica a partir de `day`: [início do anúncio, subida, fim] em dias
static func next_myth(world_seed: int, day: float) -> Vector3:
	return next_event(world_seed, Rarity.MITICA, day)

## Próxima lendária ou mítica que ainda não acabou em `day`: [início do anúncio, subida, fim]
## em dias (sem anúncio, o início é a subida)
static func next_event(world_seed: int, rarity: int, day: float) -> Vector3:
	var myth := rarity == Rarity.MITICA
	var cycle := days(MYTH_CYCLE_S if myth else LEGEND_CYCLE_S)
	var dur := days(MYTH_S if myth else LEGEND_S)
	var announce := days(ANNOUNCE_S) if myth else 0.0
	var k := floori(day / cycle)
	for i in 3:
		var w := _event_window(world_seed, rarity, k + i, cycle, dur, announce)
		if w.y + dur > day:
			return Vector3(w.x, w.y, w.y + dur)
	return Vector3.INF

# ---------------------------------------------------------------- por raridade

static func _commons(world_seed: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rng := _rng(world_seed, Rarity.COMUM, 0, 0)
	for slot in SPECS[Rarity.COMUM].count:
		var isl := _base(world_seed, Rarity.COMUM, slot, 0, rng)
		for attempt in 200:
			var p := _spot(rng, isl.radius, 0.0)
			if _clear(p, isl.radius, out):
				isl.center = Vector3(p.x, isl.center.y, p.y)
				break
		isl.current_angle = _current_angle(isl, [])
		out.append(isl)
	var slots := range(out.size())
	for i in slots.size():
		var j := rng.randi_range(i, slots.size() - 1)
		var t: int = slots[i]
		slots[i] = slots[j]
		slots[j] = t
	for i in mini(NEST_COMMONS, slots.size()):
		out[slots[i]].nest = true
	return out

static func _uncommon(world_seed: int, slot: int, day: float, commons: Array[Dictionary]) -> Dictionary:
	# Ponto fixo para sempre (as três sorteadas juntas, sem se encostar com a órbita)
	var rng := _rng(world_seed, Rarity.INCOMUM, 0, 0)
	var anchors: Array[Dictionary] = []
	var mine: Dictionary
	for s in slot + 1:
		var a := _base(world_seed, Rarity.INCOMUM, s, 0, rng)
		for attempt in 200:
			var p := _spot(rng, a.radius, ORBIT_RADIUS)
			if _clear(p, a.radius + ORBIT_RADIUS, anchors, ORBIT_RADIUS):
				a.center = Vector3(p.x, a.center.y, p.y)
				break
		anchors.append(a)
		mine = a
	var isl := mine.duplicate()
	var ang := day * ORBIT_SPEED + float(slot) * TAU / 3.0
	isl.center += Vector3(cos(ang), 0.0, sin(ang)) * ORBIT_RADIUS
	isl.epoch = floori(day / RENEW_DAYS)
	isl.ends_at = float(isl.epoch + 1) * RENEW_DAYS
	isl.current_angle = _current_angle(isl, commons)
	return isl

static func _rare(world_seed: int, slot: int, day: float, commons: Array[Dictionary]) -> Dictionary:
	var shifted := day - float(slot) * RARE_DAYS * 0.5
	var epoch := floori(shifted / RARE_DAYS)
	var rng := _rng(world_seed, Rarity.RARA, slot, epoch)
	var isl := _base(world_seed, Rarity.RARA, slot, epoch, rng)
	var side := -1.0 if slot == 0 else 1.0
	var half := WorldBounds.HALF * AREA
	var x := side * rng.randf_range(isl.radius + RARE_DRIFT * 0.5, half - isl.radius)
	var z := rng.randf_range(-half + isl.radius, half - isl.radius)
	var dir := Vector2.from_angle(rng.randf() * TAU)
	var t := shifted / RARE_DAYS - float(epoch)
	var p := Vector2(x, z) + dir * (t - 0.5) * RARE_DRIFT
	isl.center = Vector3(clampf(p.x, -half, half), isl.center.y, clampf(p.y, -half, half))
	var start := float(epoch) * RARE_DAYS + float(slot) * RARE_DAYS * 0.5
	_apply_life(isl, day, start, start + RARE_DAYS)
	isl.current_angle = _current_angle(isl, commons)
	return isl

## Lendária e mítica: no máximo uma por ciclo, numa janela sorteada (nunca na mesma hora)
static func _event(world_seed: int, rarity: int, day: float, cycle: float, duration: float, announce: float, commons: Array[Dictionary]) -> Dictionary:
	var k := floori(day / cycle)
	for kk in [k, k + 1]:
		var w := _event_window(world_seed, rarity, kk, cycle, duration, announce)
		if day < w.x or day >= w.y + duration:
			continue
		var rng := _rng(world_seed, rarity, 0, kk)
		var isl := _base(world_seed, rarity, 0, kk, rng)
		for attempt in 200:
			var p := _spot(rng, isl.radius, 0.0)
			if _clear(p, isl.radius, [], 0.0):
				isl.center = Vector3(p.x, isl.center.y, p.y)
				break
		_apply_life(isl, day, w.y, w.y + duration)
		if day < w.y:
			isl.phase = &"anunciada"
			isl.solid = false
		isl.current_angle = _current_angle(isl, commons)
		return isl
	return {}

## [início do anúncio, subida] do ciclo k
static func _event_window(world_seed: int, rarity: int, k: int, cycle: float, duration: float, announce: float) -> Vector2:
	var rng := _rng(world_seed, rarity, 99, k)
	var room := cycle - duration - announce - days(RISE_S)
	var rise := float(k) * cycle + announce + rng.randf() * room
	return Vector2(rise - announce, rise)

## Ilhotas em volta do núcleo da mítica: mesma vida (surgem, afundam e somem junto), um pouco mais
## baixas, ligadas a ele por uma Corrente lateral (o `current_angle` aponta para o núcleo)
static func _satellites(world_seed: int, core: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rng := _rng(world_seed, Rarity.MITICA, 50, int(core.epoch))
	var base := rng.randf() * TAU
	var half := WorldBounds.HALF - 4.0
	for i in SATELLITES:
		var diam := rng.randf_range(SAT_DIAM.x, SAT_DIAM.y)
		var r := diam * 0.5
		var a := base + float(i) * TAU / float(SATELLITES) + rng.randf_range(-0.25, 0.25)
		var c: Vector3 = core.center
		var d := float(core.radius) + SAT_GAP + r
		var p := Vector2(c.x, c.z) + Vector2.from_angle(a) * d
		p = Vector2(clampf(p.x, -half + r, half - r), clampf(p.y, -half + r, half - r))
		var sat := core.duplicate()
		sat.merge({
			"id": StringName("%s_%d_%d" % [RARITY_NAMES[Rarity.MITICA].to_lower(), i + 1, int(core.epoch)]),
			"slot": i + 1, "radius": r, "depth": minf(MAX_DEPTH, diam * DEPTH_RATIO), "relief": 1.2,
			"shape_seed": hash([world_seed, "satelite", i, int(core.epoch)]),
			"center": Vector3(p.x, c.y - SAT_DROP, p.y), "satellite": true, "core_center": c,
			"core_radius": float(core.radius), "nest": i < SAT_NESTS,
		}, true)
		var to_core := Vector2(c.x - p.x, c.z - p.y)
		sat.current_angle = atan2(to_core.y, to_core.x)
		out.append(sat)
	return out

# ---------------------------------------------------------------- partes

static func _rng(world_seed: int, rarity: int, slot: int, epoch: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, "ilha", rarity, slot, epoch])
	return rng

static func _base(world_seed: int, rarity: int, slot: int, epoch: int, rng: RandomNumberGenerator) -> Dictionary:
	var spec: Dictionary = SPECS[rarity]
	var diam: float = rng.randf_range(spec.diam.x, spec.diam.y)
	return {
		"id": StringName("%s_%d_%d" % [RARITY_NAMES[rarity].to_lower(), slot, epoch]),
		"rarity": rarity, "slot": slot, "epoch": epoch,
		"center": Vector3(0.0, rng.randf_range(spec.height.x, spec.height.y), 0.0),
		"radius": diam * 0.5,
		"depth": minf(MAX_DEPTH, diam * DEPTH_RATIO),
		"relief": spec.relief,
		"shape_seed": hash([world_seed, rarity, slot, epoch, "forma"]),
		"current_angle": 0.0,
		"phase": &"firme", "ends_at": INF, "sinks_at": INF, "warning": false, "solid": true, "nest": false,
	}

## Ponto do vale (x, z) longe da vila; `extra` é o que a ilha anda além do raio
static func _spot(rng: RandomNumberGenerator, radius: float, extra: float) -> Vector2:
	var half := WorldBounds.HALF * AREA - radius - extra
	for i in 50:
		var p := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		if not CityHub.in_village(p.x, p.y, VILLAGE_MARGIN + radius):
			return p
	return Vector2(half, half)

static func _clear(p: Vector2, radius: float, others: Array, extra: float = 0.0) -> bool:
	for o in others:
		var c: Vector3 = o.center
		if p.distance_to(Vector2(c.x, c.z)) < radius + o.radius + extra + GAP:
			return false
	return true

## Lado da ilha onde sobe a Corrente: o primeiro, de 8, cuja coluna não passa por baixo de uma
## comum (as comuns são fixas; as outras raridades ficam acima delas e não cruzam a coluna)
static func _current_angle(isl: Dictionary, commons: Array) -> float:
	var base := float(int(isl.shape_seed) % 628) / 100.0
	for i in 8:
		var a := base + float(i) * TAU / 8.0
		var c: Vector3 = isl.center
		var p := Vector2(c.x, c.z) + Vector2.from_angle(a) * (float(isl.radius) + SkyIslandField.CURRENT_RADIUS)
		var blocked := false
		for o in commons:
			if o.id == isl.id:
				continue
			if p.distance_to(Vector2(o.center.x, o.center.z)) < float(o.radius) + SkyIslandField.CURRENT_RADIUS + 2.0:
				blocked = true
				break
		if not blocked:
			return a
	return base

## Surgir, firme e afundar dentro de [start, end): a ilha sobe SINK_DEPTH metros de um banco de
## nuvens e, no fim, desce os mesmos metros e some. Quem estiver em cima cai junto.
static func _apply_life(isl: Dictionary, day: float, start: float, end: float) -> void:
	var rise := days(RISE_S)
	isl.ends_at = end
	isl.sinks_at = end - rise
	isl.warning = day >= isl.sinks_at - days(WARN_S)
	if day < start + rise:
		isl.phase = &"surgindo"
		isl.center.y -= (1.0 - clampf((day - start) / rise, 0.0, 1.0)) * SINK_DEPTH
	elif day >= end - rise:
		isl.phase = &"afundando"
		isl.center.y -= clampf((day - (end - rise)) / rise, 0.0, 1.0) * SINK_DEPTH
