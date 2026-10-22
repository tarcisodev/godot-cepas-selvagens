class_name WildCreature
extends Node3D

## Bicho selvagem procedural (GDD-09 §4 e GDD-03 §9): corpo CreatureBody + comportamento por plano.
## Quadrúpede pasta e foge; ave voa em círculos; peixe nada no rio. Bichos de caça (Trotador,
## Planador, Saltarelo) têm Vida e hurtbox: apanham, fogem, ficam Exaustos abaixo de 20% e podem
## ser presos (Laço de Fibra) e sedados (Sedativo de Erva). Morto, vira corpo para esfolar.
## Só fogem — nunca atacam (decisão do Tarciso).

signal removed(creature: WildCreature)
signal captured(creature: WildCreature, player: Node)

enum State { WANDER, FLEE, EXHAUSTED, TRAPPED, SEDATING, CAPTURED, DEAD }

const FLEE_RANGE: float = 9.0
const EXHAUST_FRACTION: float = 0.2
const EXHAUST_RECOVER: float = 30.0
const TRAP_TIME: float = 20.0
const SEDATE_TIME: float = 3.0
const LASSO_RANGE: float = 6.0
const SEDATE_RANGE: float = 2.6
const CORPSE_LIFETIME: float = 300.0
## Vida por espécie de caça (GDD-03 §9.1); quem não está aqui não apanha
const HEALTH: Dictionary = {
	CreatureDNA.Species.TROTADOR: 120.0, CreatureDNA.Species.PLANADOR: 90.0, CreatureDNA.Species.SALTARELO: 25.0,
}

@export var dna: CreatureDNA
## Raio de passeio em volta de onde nasceu
@export var roam_radius: float = 14.0

var body: CreatureBody
var home: Vector3
var state: State = State.WANDER
var stats: StatsComponent
var pools: PoolsComponent
var harvest_queue: Array[Dictionary] = []
## Prioridade online (GDD-03 §9.2): quem prendeu tem 60 s sobre o bicho
var trapped_by: Node = null

var _target: Vector3
var _speed: float = 0.0
var _wait: float = 0.0
var _timer: float = 0.0
var _angle: float = 0.0
var _altitude: float = 14.0
var _last_health: float = 0.0
var _sedator: Node3D
var _sedate_health: float = 0.0
var _rng := RandomNumberGenerator.new()
var _landscape: Node
var _label: Label3D
var _rope: MeshInstance3D

func _ready() -> void:
	add_to_group("wild_creatures")
	body = CreatureBody.new()
	body.dna = dna if dna else CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 1)
	dna = body.dna
	add_child(body)
	_rng.seed = dna.dna_seed + 17
	home = global_position
	_target = home
	_angle = _rng.randf() * TAU
	_altitude = _rng.randf_range(10.0, 20.0)
	var scene := get_tree().current_scene if is_inside_tree() else null
	_landscape = scene.get_node_or_null("Landscape") if scene else null
	if is_huntable():
		_build_combat()
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 16
	_label.outline_size = 5
	_label.no_depth_test = true
	_label.visibility_range_end = 25.0
	_label.position.y = body.back_height + 0.9
	add_child(_label)

func is_huntable() -> bool:
	return HEALTH.has(dna.species)

func is_alive() -> bool:
	return state != State.DEAD and state != State.CAPTURED

func health_fraction() -> float:
	return pools.current_health / maxf(1.0, stats.get_stat(&"max_health")) if pools else 1.0

func _build_combat() -> void:
	stats = StatsComponent.new()
	stats.name = "StatsComponent"
	add_child(stats)
	stats.set_base_stat(&"max_health", HEALTH[dna.species] * (0.6 + 0.4 * dna.size_factor()))
	stats.set_base_stat(&"max_poise", 40.0)
	pools = PoolsComponent.new()
	pools.name = "PoolsComponent"
	pools.stats = stats
	add_child(pools)
	pools.reset_all()
	_last_health = pools.current_health
	pools.health_changed.connect(_on_health_changed)
	pools.health_depleted.connect(_die.bind(false))
	var hurtbox := HurtboxComponent.new()
	hurtbox.name = "BodyHurtbox"
	hurtbox.entity = self
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	var size := dna.body_size()
	shape.radius = maxf(0.2, size * 0.28)
	shape.height = maxf(shape.radius * 2.0, body.back_height + 0.2)
	col.shape = shape
	hurtbox.add_child(col)
	hurtbox.position.y = shape.height * 0.5
	add_child(hurtbox)

func _on_health_changed(current: float, max_val: float) -> void:
	var hurt := current < _last_health
	_last_health = current
	if not hurt or not is_alive():
		return
	if state == State.SEDATING:
		_cancel_sedation("Sedação interrompida pelo dano!")
	if current <= max_val * EXHAUST_FRACTION:
		if state != State.TRAPPED and state != State.SEDATING:
			state = State.EXHAUSTED
		_timer = EXHAUST_RECOVER
	elif state != State.TRAPPED:
		state = State.FLEE
		_timer = 4.0
		_flee_from(get_tree().get_first_node_in_group("player") as Node3D)

# ---------------------------------------------------------------- captura

## [Laço] Prende se estiver Exausto; senão o laço arrebenta. Devolve true se prendeu.
func trap(by: Node) -> bool:
	if state != State.EXHAUSTED:
		return false
	state = State.TRAPPED
	trapped_by = by
	_timer = TRAP_TIME
	_show_rope(true)
	return true

## [Sedativo] Começa 3 s de sedação; o caçador precisa ficar parado e sem levar dano
func start_sedation(player: Node3D) -> bool:
	if state != State.TRAPPED:
		return false
	state = State.SEDATING
	_sedator = player
	_timer = SEDATE_TIME
	var p_pools: PoolsComponent = player.get("pools")
	_sedate_health = p_pools.current_health if p_pools else 0.0
	return true

func _process_sedation(delta: float) -> void:
	var p := _sedator
	if p == null or not is_instance_valid(p):
		_cancel_sedation("")
		return
	var v: Vector3 = p.get("velocity") if "velocity" in p else Vector3.ZERO
	var p_pools: PoolsComponent = p.get("pools")
	if Vector2(v.x, v.z).length() > 0.5 or p.global_position.distance_to(global_position) > SEDATE_RANGE + 1.0:
		_cancel_sedation("Sedação interrompida: fique parado ao lado")
		return
	if p_pools and p_pools.current_health < _sedate_health:
		_cancel_sedation("Sedação interrompida pelo dano!")
		return
	_timer -= delta
	if _timer <= 0.0:
		state = State.CAPTURED
		_show_rope(false)
		captured.emit(self, p)

func _cancel_sedation(msg: String) -> void:
	if not msg.is_empty() and _sedator and _sedator.has_signal("posture_changed"):
		_sedator.posture_changed.emit(msg)
	_sedator = null
	if state == State.SEDATING:
		state = State.TRAPPED
		_timer = maxf(_timer, 5.0)

## Escolha depois da captura: abate cuidadoso (todas as partes Íntegras) ou levar embora
func careful_slaughter() -> void:
	_die(true)

func take_away() -> void:
	_remove()

# ---------------------------------------------------------------- morte e esfola

func _die(careful: bool) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	_show_rope(false)
	harvest_queue = _loot(careful)
	add_to_group("harvestable")
	_timer = CORPSE_LIFETIME
	body.rotation.z = PI * 0.5 if dna.plan() != CreatureDNA.Plan.FISH else 0.0
	if dna.plan() == CreatureDNA.Plan.BIRD:
		global_position.y = _ground(global_position.x, global_position.z)

## Partes por espécie (GDD-03 §9.1). Íntegro = +1★ e trait `integro` (ADR-0005); mutante passa a cor
func _loot(careful: bool) -> Array[Dictionary]:
	var q := 3 if careful else 2
	var traits: Array = [&"integro"] if careful else []
	if dna.is_mutant():
		traits.append(&"iridescente")
	var items: Array = []
	match dna.species:
		CreatureDNA.Species.TROTADOR:
			if dna.has_horns():
				items.append([&"chifre_galhado", 1])
			items.append([&"couro_trotador", 2])
			items.append([&"carne_crua", 2])
		CreatureDNA.Species.PLANADOR:
			items.append([&"pena_penacho", 3])
			items.append([&"carne_crua", 1])
		_:
			items.append([&"pele_saltarelo", 1])
			items.append([&"carne_crua", 1])
	var out: Array[Dictionary] = []
	for it in items:
		var data := MaterialData.of(it[0])
		out.append({"label": "%d× %s%s" % [it[1], data.display_name, " (Íntegro)" if careful else ""], "id": it[0], "amount": it[1], "quality": q, "traits": traits})
	return out

func is_harvestable() -> bool:
	return state == State.DEAD and not harvest_queue.is_empty()

func next_harvest_label() -> String:
	return harvest_queue[0].label if is_harvestable() else ""

func get_harvest_verb() -> String:
	return "Esfolando"

func harvest_next(harvester: Node = null) -> String:
	if not is_harvestable():
		return ""
	var e: Dictionary = harvest_queue.pop_front()
	var inv: InventoryComponent = harvester.get("inventory") if harvester else null
	if inv:
		inv.add_material(e.id, e.amount, e.quality, e.traits)
	var mastery: MasteryComponent = harvester.get("mastery") if harvester else null
	if mastery:
		mastery.add_xp(&"esfola", 15.0)
	if harvest_queue.is_empty():
		_remove.call_deferred()
	return e.label

func _remove() -> void:
	remove_from_group("harvestable")
	removed.emit(self)
	queue_free()

# ---------------------------------------------------------------- comportamento

func _process(delta: float) -> void:
	_update_label()
	match state:
		State.DEAD:
			_timer -= delta
			if _timer <= 0.0:
				_remove()
			return
		State.CAPTURED:
			body.animate(delta, 0.0)
			return
		State.SEDATING:
			_process_sedation(delta)
			body.animate(delta, 0.0)
			return
		State.TRAPPED:
			_timer -= delta
			if _timer <= 0.0:
				# Laço afrouxou: ainda cansado, mas livre
				state = State.EXHAUSTED
				_timer = EXHAUST_RECOVER
				_show_rope(false)
				trapped_by = null
			_ground_snap(0.0)
			body.animate(delta, 0.0)
			return
		State.EXHAUSTED:
			_timer -= delta
			if _timer <= 0.0:
				# Recuperou o fôlego: Vida volta a 50% e foge
				pools.heal(stats.get_stat(&"max_health") * 0.5 - pools.current_health)
				state = State.FLEE
				_timer = 4.0
				_flee_from(get_tree().get_first_node_in_group("player") as Node3D)
				return
			_exhausted_walk(delta)
			return
	match dna.plan():
		CreatureDNA.Plan.QUADRUPED:
			_walk(delta)
		CreatureDNA.Plan.BIRD:
			_fly(delta)
		CreatureDNA.Plan.FISH:
			_swim(delta)

func _walk(delta: float) -> void:
	var small := dna.species == CreatureDNA.Species.SALTARELO
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if state != State.FLEE and player and player.global_position.distance_to(global_position) < FLEE_RANGE and _player_is_loud(player):
		state = State.FLEE
		_timer = 3.0
		_flee_from(player)
	var desired := 0.0
	if state == State.FLEE:
		_timer -= delta
		desired = 7.5 if small else 8.0
		if _timer <= 0.0:
			state = State.WANDER
	elif _wait > 0.0:
		_wait -= delta
	else:
		desired = 2.2 if small else 1.4
		if Vector2(_target.x - global_position.x, _target.z - global_position.z).length() < 0.6:
			_wait = _rng.randf_range(2.0, 7.0)
			_target = _pick_ground_target()
	_move_toward_target(delta, desired)
	var hop := absf(sin(Time.get_ticks_msec() / 120.0)) * 0.25 if small and _speed > 1.0 else 0.0
	_ground_snap(hop)
	body.animate(delta, _speed)

func _exhausted_walk(delta: float) -> void:
	# Exausto: arrasta-se devagar (a ave pousa), não foge mais
	if Vector2(_target.x - global_position.x, _target.z - global_position.z).length() < 0.6:
		_target = _pick_ground_target()
	_move_toward_target(delta, 0.6)
	_ground_snap(0.0)
	rotation.z = lerp_angle(rotation.z, 0.0, delta * 3.0)
	body.animate(delta, _speed, 0.0, false)

func _move_toward_target(delta: float, desired: float) -> void:
	_speed = move_toward(_speed, desired, delta * 6.0)
	var to := _target - global_position
	to.y = 0.0
	if to.length() > 0.1 and _speed > 0.05:
		var next := global_position + to.normalized() * _speed * delta
		if not _is_water(next):
			global_position = next
		else:
			_target = _pick_ground_target()
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), minf(1.0, delta * 5.0))

func _fly(delta: float) -> void:
	var speed_mult := 2.2 if state == State.FLEE else 1.0
	if state == State.FLEE:
		_timer -= delta
		if _timer <= 0.0:
			state = State.WANDER
	_angle += delta * 0.22 * speed_mult
	var r := roam_radius * 1.6
	var desired := home + Vector3(cos(_angle) * r, 0, sin(_angle) * r)
	var ground := _ground(desired.x, desired.z)
	desired.y = ground + _altitude + sin(_angle * 2.3) * 3.0 + (8.0 if state == State.FLEE else 0.0)
	var old := global_position
	global_position = global_position.lerp(desired, minf(1.0, delta * 1.5))
	var vel := (global_position - old) / maxf(delta, 0.001)
	if Vector2(vel.x, vel.z).length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-vel.x, -vel.z), minf(1.0, delta * 3.0))
	rotation.z = lerp_angle(rotation.z, 0.35, delta * 2.0)
	body.animate(delta, vel.length(), vel.y, true)

func _swim(delta: float) -> void:
	_angle += delta * (0.25 if dna.species == CreatureDNA.Species.RAIA else 0.6)
	var z := home.z + sin(_angle) * roam_radius
	var half := RiverSystem.get_water_half_width(z)
	var x := RiverSystem.get_river_center_x(z) + cos(_angle * 1.7) * half * 0.45
	var y := RiverSystem.get_water_height(z) - (0.35 if dna.species == CreatureDNA.Species.RAIA else 0.5)
	var old := global_position
	global_position = global_position.lerp(Vector3(x, y, z), minf(1.0, delta * 1.2))
	var vel := (global_position - old) / maxf(delta, 0.001)
	if vel.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-vel.x, -vel.z), minf(1.0, delta * 3.0))
	body.animate(delta, vel.length())

func _flee_from(threat: Node3D) -> void:
	if threat == null:
		return
	var away := global_position - threat.global_position
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(1, 0, 0)
	_target = global_position + away.normalized() * 12.0
	if _is_water(_target):
		_target = _pick_ground_target()

func _pick_ground_target() -> Vector3:
	for i in 8:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(2.0, roam_radius)
		var p := home + Vector3(cos(a) * d, 0, sin(a) * d)
		if not _is_water(p) and not CityHub.in_village(p.x, p.z):
			return p
	return home

func _player_is_loud(player: Node3D) -> bool:
	var v: Vector3 = player.get("velocity") if "velocity" in player else Vector3.ZERO
	return Vector2(v.x, v.z).length() > 4.5 or player.get("mounted_on") != null

func _ground_snap(extra: float) -> void:
	global_position.y = _ground(global_position.x, global_position.z) + extra

func _is_water(p: Vector3) -> bool:
	return RiverSystem.is_in_water(Vector3(p.x, _ground(p.x, p.z), p.z))

func _ground(x: float, z: float) -> float:
	return _landscape.get_height_at(x, z) if _landscape else 0.0

# ---------------------------------------------------------------- visual de estado

func _update_label() -> void:
	match state:
		State.EXHAUSTED:
			_label.text = "💤 %s exausto · %d%%" % [dna.species_name(), roundi(health_fraction() * 100.0)]
			_label.modulate = Color(1.0, 0.85, 0.4)
		State.TRAPPED:
			_label.text = "➰ Preso · %d s · use o Sedativo" % ceili(_timer)
			_label.modulate = Color(0.6, 1.0, 0.7)
		State.SEDATING:
			_label.text = "💉 Sedando... %.1f s" % maxf(_timer, 0.0)
			_label.modulate = Color(0.6, 0.9, 1.0)
		State.DEAD:
			_label.text = "Segure [E] para esfolar" if is_harvestable() else ""
			_label.modulate = Color(0.9, 0.9, 0.9)
		_:
			_label.text = ""

func _show_rope(on: bool) -> void:
	if on and _rope == null:
		_rope = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = dna.body_size() * 0.32
		torus.outer_radius = dna.body_size() * 0.38
		_rope.mesh = torus
		_rope.position.y = 0.25
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.82, 0.75, 0.45)
		_rope.material_override = m
		add_child(_rope)
	if _rope:
		_rope.visible = on

# ---------------------------------------------------------------- ferramentas do jogador

## Usa Laço ou Sedativo no bicho mais próximo (roda rápida, GDD-03 §9.2). Devolve true se gastou o item.
static func use_tool(player: Node3D, material_id: StringName) -> bool:
	var data := MaterialData.of(material_id)
	var inv: InventoryComponent = player.get("inventory")
	if inv == null or inv.get_material_count(material_id) <= 0:
		return false
	match data.tool_action:
		&"laco":
			var target := _nearest(player, LASSO_RANGE, func(c): return c.is_huntable() and c.is_alive() and c.state != State.TRAPPED and c.state != State.SEDATING)
			if target == null:
				_say(player, "➰ Nenhum bicho de caça a até %d m" % LASSO_RANGE)
				return false
			inv.consume_materials({material_id: 1})
			if target.trap(player):
				_say(player, "➰ %s preso por %d s! Agora o Sedativo" % [target.dna.species_name(), TRAP_TIME])
			else:
				_say(player, "➰ O laço arrebentou: o %s não está exausto (abaixo de 20%% da Vida)" % target.dna.species_name())
			return true
		&"sedativo":
			var target := _nearest(player, SEDATE_RANGE, func(c): return c.state == State.TRAPPED)
			if target == null:
				_say(player, "💉 Chegue perto de um bicho preso pelo laço")
				return false
			inv.consume_materials({material_id: 1})
			target.start_sedation(player)
			_say(player, "💉 Sedando o %s... fique parado %d s" % [target.dna.species_name(), SEDATE_TIME])
			return true
	return false

static func _nearest(player: Node3D, max_dist: float, filter: Callable) -> WildCreature:
	var best: WildCreature = null
	var best_d := max_dist
	for n in player.get_tree().get_nodes_in_group("wild_creatures"):
		var c := n as WildCreature
		if c == null or not filter.call(c):
			continue
		var d := c.global_position.distance_to(player.global_position)
		if d <= best_d:
			best = c
			best_d = d
	return best

static func _say(player: Node, msg: String) -> void:
	if player.has_signal("posture_changed"):
		player.posture_changed.emit(msg)
