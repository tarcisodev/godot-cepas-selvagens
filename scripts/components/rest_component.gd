class_name RestComponent
extends Node

## Descansar (GDD-10 §10.2–§10.4, ADR-0006): o tempo do mundo não pula; descansar só mexe no
## personagem. Sentado (ou deitado na sua cama) a Vida volta com a taxa do lugar; 60 s numa
## fogueira, banco ou cama dão o buff Descansado (+25% na volta de Vigor e Éter por 15 min reais).

signal rested_changed(active: bool)

## Fração da Vida máxima por segundo em cada lugar
const RATE_GROUND: float = 0.005
const RATE_CAMP: float = 0.02
const RATE_BED: float = 0.03
## Alcance da fogueira e do banco (m)
const FIRE_RANGE: float = 4.0
const BENCH_RANGE: float = 1.3
## Combate recente (dano dado ou recebido) impede começar a descansar
const COMBAT_LOCK: float = 10.0
## Descansado: tempo bom de descanso para ganhar, duração (s reais) e bônus
const RESTED_AFTER: float = 60.0
const RESTED_DURATION: float = 900.0
const RESTED_BONUS: float = 0.25
const RESTED_STATS: Array[StringName] = [&"vigor_regen", &"ether_regen"]

enum Spot { NONE, GROUND, CAMP, BED }

var player: Node3D
var pools: PoolsComponent
var stats: StatsComponent

## Segundos desde o último dano dado ou recebido (começa liberado)
var since_combat: float = COMBAT_LOCK
## Tempo seguido descansando em fogueira, banco ou cama
var good_rest_time: float = 0.0
## Segundos que faltam do buff Descansado (0 = sem buff)
var rested_left: float = 0.0
## Cama em que o jogador está deitado agora (só a dele)
var bed: Node3D

## Fonte única dos modificadores do buff (ADR-0003: um modificador com origem rastreável)
var _source := RefCounted.new()
## Última Vida vista, para notar dano vindo de qualquer lugar
var _last_health: float = INF

func _ready() -> void:
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("hit_resolved"):
		eb.hit_resolved.connect(_on_hit_resolved)
	if pools:
		_last_health = pools.current_health
		if not pools.health_changed.is_connected(_on_health_changed):
			pools.health_changed.connect(_on_health_changed)

func is_resting() -> bool:
	return player != null and bool(player.get("is_sitting")) and not bool(player.get("is_downed"))

## Pode começar a descansar? Devolve "" ou o motivo para mostrar no HUD
func block_reason() -> String:
	if since_combat < COMBAT_LOCK:
		return "Em combate: descanse em %.0f s" % ceilf(COMBAT_LOCK - since_combat)
	if player and (player.get("mounted_on") != null or bool(player.get("is_swimming"))):
		return "Não dá para descansar aqui"
	return ""

## Onde o jogador está descansando agora (decide a taxa de Vida e se conta para o buff)
func current_spot() -> Spot:
	if not is_resting():
		return Spot.NONE
	if bed and is_instance_valid(bed):
		return Spot.BED
	var tree := player.get_tree() if player.is_inside_tree() else null
	if tree:
		for f in tree.get_nodes_in_group("rest_fires"):
			if f is Node3D and bool(f.get("lit")) and _flat_dist(f) <= FIRE_RANGE:
				return Spot.CAMP
		for b in tree.get_nodes_in_group("rest_benches"):
			if b is Node3D and _flat_dist(b) <= BENCH_RANGE:
				return Spot.CAMP
	return Spot.GROUND

static func rate_for(spot: Spot) -> float:
	match spot:
		Spot.BED:
			return RATE_BED
		Spot.CAMP:
			return RATE_CAMP
		Spot.GROUND:
			return RATE_GROUND
	return 0.0

func _process(delta: float) -> void:
	since_combat += delta
	if rested_left > 0.0:
		rested_left -= delta
		if rested_left <= 0.0:
			clear_rested()
	if player == null:
		return
	if is_resting() and block_reason() != "":
		# Montou ou caiu na água sentado: o descanso acaba
		stop_resting()
		return
	var spot := current_spot()
	if spot == Spot.NONE:
		good_rest_time = 0.0
		if bed and not bool(player.get("is_sitting")):
			bed = null
		return
	if pools and stats and pools.current_health > 0.0:
		pools.heal(stats.get_stat(&"max_health") * rate_for(spot) * delta)
	if spot == Spot.GROUND:
		good_rest_time = 0.0
		return
	good_rest_time += delta
	if good_rest_time >= RESTED_AFTER:
		good_rest_time = 0.0
		apply_rested()

## Liga (ou renova) o Descansado. Não acumula: sempre um par de modificadores só.
func apply_rested(duration: float = RESTED_DURATION) -> void:
	var was := rested_left > 0.0
	if stats:
		stats.remove_modifiers_from_source(_source)
		for s in RESTED_STATS:
			stats.add_modifier(ModifierData.new(s, ModifierData.Op.PCT_ADD, RESTED_BONUS, _source))
	rested_left = duration
	if not was:
		rested_changed.emit(true)
		if player and player.has_signal("posture_changed"):
			player.posture_changed.emit("✨ Descansado: Vigor e Éter voltam 25% mais rápido")

func clear_rested() -> void:
	var was := rested_left > 0.0
	rested_left = 0.0
	if stats:
		stats.remove_modifiers_from_source(_source)
	if was:
		rested_changed.emit(false)

func has_rested() -> bool:
	return rested_left > 0.0

## Caído: o buff some e o descanso para
func on_downed() -> void:
	clear_rested()
	stop_resting()

func stop_resting() -> void:
	good_rest_time = 0.0
	bed = null
	if player and bool(player.get("is_sitting")) and player.has_method("toggle_sit"):
		player.toggle_sit(false)

## Texto curto para o HUD: descansando (taxa) e/ou buff com o tempo que falta
func status_text() -> String:
	var parts: Array[String] = []
	var spot := current_spot()
	if spot != Spot.NONE:
		var where: String = {Spot.GROUND: "no chão", Spot.CAMP: "no acampamento", Spot.BED: "na cama"}[spot]
		var line := "🔥 Descansando %s · Vida +%s%%/s" % [where, String.num(rate_for(spot) * 100.0, 1)]
		if spot != Spot.GROUND and not has_rested():
			line += " · Descansado em %.0f s" % ceilf(RESTED_AFTER - good_rest_time)
		parts.append(line)
	if has_rested():
		var left := int(ceilf(rested_left))
		parts.append("✨ Descansado %d:%02d" % [left / 60, left % 60])
	return "   ".join(parts)

func get_state() -> Dictionary:
	return {"rested_left": snappedf(rested_left, 0.1)}

func apply_state(data: Dictionary) -> void:
	var left := float(data.get("rested_left", 0.0))
	if left > 0.0:
		apply_rested(left)
	else:
		clear_rested()

func _on_hit_resolved(hit: HitEvent, dmg: float, _broken: bool) -> void:
	if dmg > 0.0 and hit and (hit.attacker == player or hit.target == player):
		mark_combat()

func _on_health_changed(current: float, _max_val: float) -> void:
	# Levou dano por qualquer caminho (afogar, queda, golpe): para de descansar
	if current < _last_health - 0.001:
		mark_combat()
		if is_resting():
			stop_resting()
	_last_health = current

func mark_combat() -> void:
	since_combat = 0.0

func _flat_dist(n: Node3D) -> float:
	var a := player.global_position
	var b := n.global_position
	return Vector2(a.x - b.x, a.z - b.z).length()
