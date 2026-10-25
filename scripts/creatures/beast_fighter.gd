class_name BeastFighter
extends CharacterBody3D

## Bicho procedural que luta (GDD-12 §9 e §12). Corpo do GDD-09 (CreatureBody + CreatureDNA) e
## golpes descritos em dados: cada golpe tem pose de preparação (o único aviso, sem nada na tela),
## alcance, tempos, dano e empurrão. Partes quebráveis caem como material na hora; o corpo
## é esfolado depois. O Rinolito Ancião (boss) é uma configuração; os bichos do ermo são outras.
## Usa o mesmo pipeline de dano (ADR-0003) e o peso de golpe do CombatFeel.

enum State { IDLE, CHASE, WINDUP, ACTIVE, RECOVER, DAZED, STAGGER, DEAD, RETURN }

## Configuração (ver `rinolito_anciao()`); precisa estar pronta antes de entrar na árvore
var config: Dictionary = {}

var dna: CreatureDNA
var body: CreatureBody
var stats: StatsComponent
var pools: PoolsComponent
var anatomy: AnatomyComponent
var hitbox: HitboxComponent
var name_label: Label3D

var state: State = State.IDLE
var home: Vector3
var enraged: bool = false
var horn_broken: bool = false
var carapace_broken: bool = false
## Distância para esfolar (o corpo é grande): o Player desconta isto da distância
var talk_radius: float = 1.5
var harvest_queue: Array[Dictionary] = []
var corpse_time_left: float = 0.0
var respawn_timer: float = -1.0

var _state_time: float = 0.0
var _attack: Dictionary = {}
var _cooldowns: Dictionary = {}
var _charge_dir: Vector3 = Vector3.FORWARD
var _charge_left: float = 0.0
var _charge_hit: bool = false
var _chain_left: int = 0
var _hitstop: float = 0.0
var _knockback: Vector3 = Vector3.ZERO
var _flash: float = 0.0
var _flash_mat: StandardMaterial3D
var _meshes: Array[GeometryInstance3D] = []
var _hit_shape: CollisionShape3D
var _stagger_src := RefCounted.new()
var _carapace_src := RefCounted.new()
var _last_attacker: Node = null
var _last_hit_type: DamageType.Type = DamageType.Type.SLASH
var _wander_target: Vector3
var _rng := RandomNumberGenerator.new()
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
## Medidas do corpo (m), tiradas da tabela da espécie
var _body_size: Vector3
var _leg: float

const RESISTS: Array[StringName] = [&"resist_slash", &"resist_impact", &"resist_pierce", &"resist_fire", &"resist_ice", &"resist_lightning", &"resist_nature"]

## Boss do GDD-12 §9: Rinolito velho e enorme, três golpes com pose, fúria abaixo de 50%
static func rinolito_anciao() -> Dictionary:
	return {
		"name": "Rinolito Ancião", "boss": true,
		"species": CreatureDNA.Species.RINOLITO, "seed": 7001,
		"alleles": {"porte": ["T", "T"], "chifre": ["c", "c"], "padrao": ["P", "p"]},
		"max_health": 900.0, "max_poise": 220.0,
		"resistances": {&"resist_slash": 0.25, &"resist_pierce": 0.1, &"resist_impact": -0.05},
		"move_speed": 3.4, "turn_speed": 1.6, "aggro_range": 16.0, "arena_radius": 22.0,
		"knock_taken": 0.12, "enrage_at": 0.5, "enrage_windup": 0.75, "chain_charges": 2,
		"stagger_time": 3.0, "stagger_bonus": 0.3,
		"respawn": 600.0, "corpse": 300.0,
		"attacks": [
			{"id": &"chifrada", "name": "Chifrada", "kind": &"melee", "min": 0.0, "max": 4.6, "front": 0.45,
				"windup": 0.55, "active": 0.22, "recover": 0.8, "damage": 28.0, "type": DamageType.Type.IMPACT,
				"poise": 30.0, "reach": 3.6, "pose": &"head_low", "cooldown": 1.2, "knock": 1.6, "weight": 3.0},
			{"id": &"pisao", "name": "Pisão", "kind": &"area", "min": 0.0, "max": 4.2,
				"windup": 0.8, "active": 0.2, "recover": 1.0, "damage": 22.0, "type": DamageType.Type.IMPACT,
				"poise": 45.0, "radius": 4.5, "pose": &"rear", "cooldown": 5.0, "knock": 2.2, "weight": 2.0},
			{"id": &"investida", "name": "Investida", "kind": &"charge", "min": 6.0, "max": 20.0,
				"windup": 0.9, "recover": 0.9, "damage": 40.0, "type": DamageType.Type.IMPACT, "poise": 60.0,
				"speed": 13.0, "distance": 14.0, "pose": &"paw", "cooldown": 7.0, "knock": 2.5, "daze": 1.6, "weight": 4.0},
		],
		# Partes que quebram na luta: material cai na hora para quem bateu
		"parts": {
			&"horn": {"hp": 180.0, "drop": [&"chifre_rinolito", 1, 4, [&"cicatrizado"]], "label": "💥 Chifre do Ancião quebrado!"},
			&"carapace": {"hp": 260.0, "drop": [&"placa_carapaca", 3, 3, []], "label": "💥 Carapaça rachada! Agora o corte entra"},
		},
		"harvest": [
			{"label": "Chifre do Ancião", "needs_intact": &"horn", "materials": [[&"chifre_rinolito", 1, 3, [&"cicatrizado"]]]},
			{"label": "Placas de Carapaça", "materials": [[&"placa_carapaca", 6, 3, []]], "if_broken": &"carapace", "broken_materials": [[&"placa_carapaca", 3, 3, []]]},
			{"label": "Ossos do Ancião", "materials": [[&"ossos", 4, 2, []]]},
			{"label": "Carne de Rinolito", "materials": [[&"carne_crua", 3, 1, []]]},
		],
	}

## Lobo-do-Ermo (GDD-12 §12.1): caça em bando à noite, cerca pelos flancos; de dia dorme na toca
static func lobo_do_ermo() -> Dictionary:
	return {
		"name": "Lobo-do-Ermo", "species": CreatureDNA.Species.LOBO, "seed": 3101,
		"alleles": {"porte": ["T", "t"], "chifre": ["c", "c"], "padrao": ["p", "p"]},
		"max_health": 110.0, "max_poise": 35.0, "resistances": {},
		"move_speed": 6.2, "turn_speed": 7.0, "aggro_range": 16.0, "arena_radius": 32.0,
		"knock_taken": 1.0, "nocturnal": true, "flank": true, "respawn": 180.0, "corpse": 120.0,
		"attacks": [
			{"id": &"mordida", "name": "Mordida", "kind": &"melee", "min": 0.0, "max": 2.2, "front": 0.3,
				"windup": 0.4, "active": 0.15, "recover": 0.5, "damage": 10.0, "type": DamageType.Type.SLASH,
				"poise": 10.0, "reach": 1.7, "pose": &"head_low", "cooldown": 0.9, "knock": 0.8, "weight": 3.0},
			{"id": &"bote", "name": "Bote", "kind": &"charge", "min": 3.5, "max": 9.0,
				"windup": 0.6, "recover": 0.6, "damage": 16.0, "type": DamageType.Type.SLASH, "poise": 20.0,
				"speed": 12.0, "distance": 7.0, "pose": &"paw", "cooldown": 5.0, "knock": 1.2, "daze": 0.8, "weight": 2.0},
		],
		"parts": {},
		"harvest": [
			{"label": "Couro de Lobo", "materials": [[&"couro_lobo", 2, 2, []]]},
			{"label": "Presa de Lobo", "materials": [[&"presa_lobo", 1, 2, []]]},
			{"label": "Carne de Lobo", "materials": [[&"carne_crua", 1, 1, []]]},
		],
	}

## Tatu-Espinho (GDD-12 §12.2): guarda os veios de ferro; ataca quem entra no canto dele
static func tatu_espinho() -> Dictionary:
	return {
		"name": "Tatu-Espinho", "species": CreatureDNA.Species.TATU, "seed": 4201,
		"alleles": {"porte": ["T", "T"], "chifre": ["c", "c"], "padrao": ["P", "p"]},
		"max_health": 170.0, "max_poise": 70.0,
		"resistances": {&"resist_slash": 0.35, &"resist_pierce": 0.2, &"resist_impact": -0.15},
		"move_speed": 3.8, "turn_speed": 4.0, "aggro_range": 7.0, "arena_radius": 14.0,
		"knock_taken": 0.4, "respawn": 180.0, "corpse": 120.0,
		"attacks": [
			{"id": &"garrada", "name": "Garrada", "kind": &"melee", "min": 0.0, "max": 2.4, "front": 0.4,
				"windup": 0.5, "active": 0.2, "recover": 0.6, "damage": 14.0, "type": DamageType.Type.PIERCE,
				"poise": 14.0, "reach": 1.8, "pose": &"head_low", "cooldown": 1.2, "knock": 0.9, "weight": 3.0},
			{"id": &"rolamento", "name": "Rolamento", "kind": &"charge", "min": 3.0, "max": 12.0,
				"windup": 0.8, "recover": 0.8, "damage": 24.0, "type": DamageType.Type.IMPACT, "poise": 35.0,
				"speed": 11.0, "distance": 10.0, "pose": &"head_low", "cooldown": 6.0, "knock": 1.6, "daze": 1.2, "weight": 2.0},
		],
		"parts": {
			&"carapace": {"hp": 60.0, "drop": [&"placa_carapaca", 1, 2, []], "label": "💥 Carapaça do tatu rachada! Agora o corte entra"},
		},
		"harvest": [
			{"label": "Placas de Carapaça", "materials": [[&"placa_carapaca", 2, 2, []]]},
			{"label": "Garra de Tatu", "materials": [[&"garra_tatu", 1, 2, []]]},
			{"label": "Carne de Tatu", "materials": [[&"carne_crua", 1, 1, []]]},
		],
	}

## Lugar no bando (0, 1, 2...): cada lobo cerca por um lado
var pack_slot: int = 0
## Bando (toca): quando um apanha, os outros da mesma toca acordam
var pack_id: String = ""

func _ready() -> void:
	add_to_group("monsters")
	if config.get("boss", false):
		add_to_group("boss")
	collision_layer = 4
	collision_mask = 1
	home = global_position
	_wander_target = home
	_rng.seed = int(config.get("seed", 1))
	_build_dna_and_body()
	_build_components()
	_build_hurtboxes()
	_build_hitbox()
	_build_label()

func _build_dna_and_body() -> void:
	dna = CreatureDNA.randomized(config.get("species", CreatureDNA.Species.RINOLITO), int(config.get("seed", 1)))
	if config.has("alleles"):
		dna.alleles = config.alleles.duplicate(true)
	body = CreatureBody.new()
	body.name = "Body"
	body.dna = dna
	add_child(body)
	var info := dna.info()
	var f := dna.size_factor()
	_body_size = info["body"] * f
	_leg = float(info["leg"]) * f
	talk_radius = _body_size.z * 0.5
	var shape := BoxShape3D.new()
	shape.size = Vector3(_body_size.x * 0.9, _leg + _body_size.y * 0.8, _body_size.z * 0.9)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = shape.size.y * 0.5
	add_child(col)
	for m in body.find_children("*", "GeometryInstance3D", true, false):
		_meshes.append(m as GeometryInstance3D)
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.albedo_color = Color(1, 1, 1, 0.45)

func _build_components() -> void:
	stats = StatsComponent.new()
	stats.name = "StatsComponent"
	add_child(stats)
	stats.set_base_stat(&"max_health", float(config.get("max_health", 200.0)))
	stats.set_base_stat(&"max_poise", float(config.get("max_poise", 60.0)))
	var res: Dictionary = config.get("resistances", {})
	for key in res:
		stats.set_base_stat(StringName(key), float(res[key]))
	pools = PoolsComponent.new()
	pools.name = "PoolsComponent"
	pools.stats = stats
	add_child(pools)
	pools.reset_all()
	pools.health_depleted.connect(_on_health_depleted)
	pools.poise_broken.connect(_on_poise_broken)
	pools.health_changed.connect(_on_health_changed)
	anatomy = AnatomyComponent.new()
	anatomy.name = "AnatomyComponent"
	anatomy.initial_parts = {}
	add_child(anatomy)
	_register_parts()
	anatomy.part_broken.connect(_on_part_broken)

func _register_parts() -> void:
	var parts: Dictionary = config.get("parts", {})
	for pid in parts:
		anatomy.register_part(pid, float(parts[pid].hp), false)

## Corpo, chifre (na frente da cabeça) e carapaça (em cima do dorso), cada um uma hurtbox
func _build_hurtboxes() -> void:
	var center_y := _leg + _body_size.y * 0.5
	_add_hurtbox(&"body", BoxShape3D.new(), Vector3(_body_size.x, _body_size.y + _leg * 0.6, _body_size.z), Vector3(0, center_y - _leg * 0.2, 0))
	var parts: Dictionary = config.get("parts", {})
	if parts.has(&"horn"):
		var head_size := _body_size.x * 0.42
		_add_hurtbox(&"horn", SphereShape3D.new(), Vector3.ONE * head_size * 1.6, Vector3(0, center_y + _body_size.y * 0.25, -(_body_size.z * 0.5 + head_size * 1.6)))
	if parts.has(&"carapace"):
		_add_hurtbox(&"carapace", BoxShape3D.new(), Vector3(_body_size.x * 0.8, _body_size.y * 0.35, _body_size.z * 0.7), Vector3(0, center_y + _body_size.y * 0.45, 0))

func _add_hurtbox(part: StringName, shape: Shape3D, size: Vector3, pos: Vector3) -> void:
	if shape is BoxShape3D:
		(shape as BoxShape3D).size = size
	elif shape is SphereShape3D:
		(shape as SphereShape3D).radius = size.x * 0.5
	var hb := HurtboxComponent.new()
	hb.name = "Hurtbox_%s" % part
	hb.entity = self
	hb.part_id = part
	var cs := CollisionShape3D.new()
	cs.shape = shape
	hb.add_child(cs)
	hb.position = pos
	add_child(hb)

func _build_hitbox() -> void:
	hitbox = HitboxComponent.new()
	hitbox.name = "AttackHitbox"
	hitbox.attacker = self
	hitbox.ignore_group = &"monsters"
	_hit_shape = CollisionShape3D.new()
	_hit_shape.shape = BoxShape3D.new()
	hitbox.add_child(_hit_shape)
	add_child(hitbox)
	hitbox.hit_landed.connect(func(_hb, res): if res.get(&"success", false): _charge_hit = true)

func _build_label() -> void:
	name_label = Label3D.new()
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.font_size = 20
	name_label.outline_size = 5
	name_label.outline_modulate = Color(0, 0, 0, 0.85)
	name_label.modulate = Color(1.0, 0.75, 0.5) if config.get("boss", false) else Color(1, 1, 1)
	name_label.visibility_range_end = 26.0 if config.get("boss", false) else 14.0
	name_label.position.y = _leg + _body_size.y + 1.2
	name_label.text = str(config.get("name", "Fera"))
	add_child(name_label)

# ---------------------------------------------------------------- IA

## Noite pelo relógio único (ADR-0006): 18h30 às 6h
static func is_night() -> bool:
	var sun := DayNightCycle.instance
	return sun != null and (sun.current_time_hours >= 18.5 or sun.current_time_hours < 6.0)

func _target() -> Player:
	var p := get_tree().get_first_node_in_group("player") as Player if is_inside_tree() else null
	if p == null or p.is_downed:
		return null
	return p

func _arena_radius() -> float:
	return float(config.get("arena_radius", 18.0))

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

func _forward() -> Vector3:
	return -global_basis.z

func _physics_process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_set_overlay(null)
	if _hitstop > 0.0:
		_hitstop -= delta
		return
	_state_time += delta
	for id in _cooldowns.keys():
		_cooldowns[id] -= delta
		if _cooldowns[id] <= 0.0:
			_cooldowns.erase(id)

	var player := _target()
	var to_player: Vector3 = _flat(player.global_position - global_position) if player else Vector3.ZERO
	var dist: float = to_player.length() if player else INF
	var player_in_arena: bool = player != null and _flat(player.global_position - home).length() < _arena_radius()
	var move_dir := Vector3.ZERO
	var speed := 0.0
	var turn_to := Vector3.ZERO
	var turn_rate: float = float(config.get("turn_speed", 2.0))

	match state:
		State.IDLE:
			body.pose = &""
			if config.get("nocturnal", false) and not is_night():
				# Dormindo na toca: cabeça baixa, parado
				body.pose = &"head_low"
				body.pose_amount = 0.8
			elif player_in_arena and dist < float(config.get("aggro_range", 12.0)):
				_set_state(State.CHASE)
			else:
				var to_w := _flat(_wander_target - global_position)
				if to_w.length() < 1.0:
					if _state_time > 4.0:
						var a := _rng.randf() * TAU
						_wander_target = home + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(2.0, _arena_radius() * 0.4)
						_state_time = 0.0
				elif not (config.get("nocturnal", false) and not is_night()):
					move_dir = to_w.normalized()
					speed = float(config.get("move_speed", 3.0)) * 0.35
		State.CHASE:
			if not player_in_arena:
				_set_state(State.RETURN)
			else:
				var pick := _pick_attack(dist, to_player)
				if not pick.is_empty():
					_start_attack(pick)
				else:
					var goal := to_player
					if config.get("flank", false) and dist > 3.0 and player:
						# Cada lobo do bando chega por um lado (0°, +120°, −120° em volta do jogador)
						var side := (_flat(global_position - player.global_position)).normalized().rotated(Vector3.UP, deg_to_rad(120.0 * pack_slot))
						goal = _flat(player.global_position + side * 2.5 - global_position)
					var stop := 2.5 if not config.get("flank", false) else 1.4
					move_dir = goal.normalized() if dist > stop else Vector3.ZERO
					speed = float(config.get("move_speed", 3.0))
					turn_to = goal if dist > stop else to_player
		State.WINDUP:
			var windup: float = float(_attack.windup) * (float(config.get("enrage_windup", 1.0)) if enraged else 1.0)
			if _chain_left > 0 and _attack.get("chained", false):
				windup *= 0.5
			if player:
				turn_to = to_player
				turn_rate *= 0.7 if _attack.kind == &"melee" else 1.0
			body.pose_amount = clampf(_state_time / maxf(windup * 0.6, 0.01), 0.0, 1.0)
			if _state_time >= windup:
				_release_attack(player)
		State.ACTIVE:
			if _attack.kind == &"charge":
				var step: float = float(_attack.speed) * delta
				move_dir = _charge_dir
				speed = float(_attack.speed)
				_charge_left -= step
				if _charge_left <= 0.0 or (is_on_wall() and _state_time > 0.15):
					hitbox.deactivate()
					if _chain_left > 0 and player:
						_chain_left -= 1
						_attack["chained"] = true
						_set_state(State.WINDUP)
					elif _charge_hit:
						_set_state(State.RECOVER)
					else:
						_set_state(State.DAZED)
			elif _state_time >= float(_attack.get("active", 0.2)):
				_set_state(State.RECOVER)
		State.RECOVER:
			body.pose_amount = maxf(0.0, body.pose_amount - delta * 2.0)
			if _state_time >= float(_attack.get("recover", 0.8)):
				_set_state(State.CHASE)
		State.DAZED:
			# Errou a investida: fica tonto, cabeça baixa balançando (a janela do jogador)
			body.pose = &"head_low"
			body.pose_amount = 0.6 + sin(_state_time * 9.0) * 0.3
			if _state_time >= float(_attack.get("daze", 1.6)):
				_set_state(State.CHASE)
		State.STAGGER:
			body.pose = &"head_low"
			body.pose_amount = 1.0
			if _state_time >= float(config.get("stagger_time", 3.0)) and not pools.is_poise_broken:
				stats.remove_modifiers_from_source(_stagger_src)
				_set_state(State.CHASE)
		State.RETURN:
			var to_home := _flat(home - global_position)
			if player_in_arena and dist < float(config.get("aggro_range", 12.0)):
				_set_state(State.CHASE)
			elif to_home.length() < 1.5:
				# Volta para a clareira e se cura inteiro (sem puxar o boss para longe)
				pools.reset_all()
				_set_state(State.IDLE)
			else:
				move_dir = to_home.normalized()
				speed = float(config.get("move_speed", 3.0)) * 1.2
		State.DEAD:
			_process_dead(delta)

	if turn_to == Vector3.ZERO and move_dir != Vector3.ZERO and state != State.ACTIVE:
		turn_to = move_dir
	if turn_to.length_squared() > 0.001:
		var want := atan2(-turn_to.x, -turn_to.z)
		rotation.y = rotate_toward(rotation.y, want, turn_rate * delta)
	if state == State.CHASE or state == State.RETURN or state == State.IDLE:
		# Bicho grande não anda de lado: só avança para onde está virado
		move_dir = _forward() * maxf(0.0, _forward().dot(move_dir)) if move_dir != Vector3.ZERO else Vector3.ZERO
	velocity.x = move_dir.x * speed + _knockback.x
	velocity.z = move_dir.z * speed + _knockback.z
	_knockback = _knockback.move_toward(Vector3.ZERO, 10.0 * delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	if body and state != State.DEAD:
		body.animate(delta, Vector2(velocity.x, velocity.z).length())

## Escolhe o golpe pela distância e pelo lado em que o jogador está (sorteio pelo peso)
func _pick_attack(dist: float, to_player: Vector3) -> Dictionary:
	var front: float = _forward().dot(to_player.normalized()) if dist > 0.01 else 1.0
	var options: Array = []
	var total := 0.0
	for a in config.get("attacks", []):
		if _cooldowns.has(a.id) or dist < float(a.min) or dist > float(a.max):
			continue
		if a.has("front") and front < float(a.front):
			continue
		if a.kind == &"charge" and front < 0.7:
			continue
		options.append(a)
		total += float(a.get("weight", 1.0))
	if options.is_empty():
		return {}
	var roll := _rng.randf() * total
	for a in options:
		roll -= float(a.get("weight", 1.0))
		if roll <= 0.0:
			return a
	return options[-1]

func _start_attack(a: Dictionary) -> void:
	_attack = a.duplicate()
	_charge_hit = false
	_chain_left = int(config.get("chain_charges", 1)) - 1 if enraged and a.kind == &"charge" else 0
	body.pose = a.get("pose", &"")
	body.pose_amount = 0.0
	_set_state(State.WINDUP)

func _release_attack(player: Player) -> void:
	_cooldowns[_attack.id] = float(_attack.get("cooldown", 2.0))
	var dmg: float = float(_attack.damage)
	if horn_broken and _attack.kind != &"area":
		dmg *= 0.6 # sem o chifre, chifrada e investida perdem força
	hitbox.knockback_mult = float(_attack.get("knock", 1.0))
	match _attack.kind:
		&"melee":
			var box := BoxShape3D.new()
			box.size = Vector3(_body_size.x * 1.7, 2.4, float(_attack.reach))
			_hit_shape.shape = box
			hitbox.position = Vector3(0, 1.0, -(_body_size.z * 0.5 + float(_attack.reach) * 0.5))
			hitbox.activate_with_params(float(_attack.active), dmg, _attack.type, float(_attack.poise), 1.0)
		&"area":
			var ball := SphereShape3D.new()
			ball.radius = float(_attack.radius)
			_hit_shape.shape = ball
			hitbox.position = Vector3(0, 0.6, -_body_size.z * 0.2)
			hitbox.activate_with_params(float(_attack.active), dmg, _attack.type, float(_attack.poise), 1.0)
			_spawn_dust(float(_attack.radius))
		&"charge":
			var cbox := BoxShape3D.new()
			cbox.size = Vector3(_body_size.x * 1.3, 2.4, 1.8)
			_hit_shape.shape = cbox
			hitbox.position = Vector3(0, 1.0, -(_body_size.z * 0.5 + 0.7))
			_charge_dir = _forward()
			_charge_left = float(_attack.distance)
			hitbox.activate_with_params(float(_attack.distance) / float(_attack.speed) + 0.1, dmg, _attack.type, float(_attack.poise), 1.0)
	body.pose_amount = 0.0 if _attack.kind == &"charge" else body.pose_amount
	_set_state(State.ACTIVE)

func _set_state(s: State) -> void:
	state = s
	_state_time = 0.0
	if s in [State.CHASE, State.IDLE, State.RETURN]:
		body.pose = &""
		body.pose_amount = 0.0

## Poeira no chão do Pisão (o aro mostra o tamanho do golpe depois que ele sai, não antes)
func _spawn_dust(radius: float) -> void:
	if get_parent() == null:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 40
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_radius = radius * 0.5
	p.emission_ring_inner_radius = radius * 0.2
	p.emission_ring_height = 0.1
	p.emission_ring_axis = Vector3.UP
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -6.0, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.47, 0.36, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	p.mesh = mesh
	get_parent().add_child(p)
	p.global_position = hitbox.global_position
	p.emitting = true
	p.finished.connect(p.queue_free)

# ---------------------------------------------------------------- dano recebido

## Antes da mitigação: lembra quem bateu e com o quê (o chifre só quebra direito com impacto)
func filter_incoming_hit(hit: HitEvent) -> void:
	if state == State.DEAD:
		hit.raw_damage = 0.0
		hit.poise_damage = 0.0
		return
	_last_attacker = hit.attacker
	_last_hit_type = hit.damage_type

## Dano na parte: impacto quebra chifre e carapaça 1,5×; corte e perfuração só arranham (0,5×)
func damage_part(part_id: StringName, amount: float) -> bool:
	var mult := 1.5 if _last_hit_type == DamageType.Type.IMPACT else 0.5
	return anatomy.damage_part(part_id, amount * mult)

func on_hit_feedback(_hit: HitEvent, result: Dictionary) -> void:
	if state == State.DEAD or result.get(&"effective_damage", 0.0) <= 0.0:
		return
	_set_overlay(_flash_mat)
	_flash = 0.07
	if state in [State.IDLE, State.RETURN]:
		_set_state(State.CHASE)
	if pack_id != "" and is_inside_tree():
		for m in get_tree().get_nodes_in_group("monsters"):
			if m != self and m is BeastFighter and (m as BeastFighter).pack_id == pack_id:
				m.taunt(self)

func apply_hitstop(duration: float) -> void:
	if state != State.DEAD and duration > _hitstop:
		_hitstop = duration

## Bicho pesado quase não sai do lugar
func apply_knockback(impulse: Vector3) -> void:
	if state != State.DEAD:
		_knockback += impulse * float(config.get("knock_taken", 0.5))

func taunt(_who: Node3D) -> void:
	if state in [State.IDLE, State.RETURN]:
		_set_state(State.CHASE)

func _on_health_changed(current: float, max_val: float) -> void:
	if not enraged and state != State.DEAD and config.has("enrage_at") and current <= max_val * float(config.enrage_at):
		enraged = true
		name_label.text = "%s (furioso)" % config.get("name", "")
		if config.get("boss", false):
			_say("😤 %s está furioso!" % config.get("name", ""))

func _on_poise_broken() -> void:
	if state == State.DEAD:
		return
	hitbox.deactivate()
	stats.remove_modifiers_from_source(_stagger_src)
	# Atordoado: a defesa cai (leva +30% de dano) enquanto a Postura volta
	for r in RESISTS:
		stats.add_modifier(ModifierData.new(r, ModifierData.Op.FLAT, -float(config.get("stagger_bonus", 0.3)), _stagger_src))
	_set_state(State.STAGGER)
	if config.get("boss", false):
		_say("💫 %s atordoado!" % config.get("name", ""))

func _on_part_broken(part_id: StringName) -> void:
	var part: Dictionary = config.get("parts", {}).get(part_id, {})
	if part.is_empty():
		return
	match part_id:
		&"horn":
			horn_broken = true
			if body.horn_node:
				body.horn_node.visible = false
		&"carapace":
			carapace_broken = true
			if body.plates_node:
				body.plates_node.visible = false
			stats.add_modifier(ModifierData.new(&"resist_slash", ModifierData.Op.FLAT, -float(config.get("resistances", {}).get(&"resist_slash", 0.0)), _carapace_src))
	var drop: Array = part.get("drop", [])
	if not drop.is_empty():
		_give(_last_attacker, drop)
	_say(str(part.get("label", "💥 Parte quebrada!")))

func _give(who: Node, m: Array) -> void:
	var inv: InventoryComponent = who.get_node_or_null("InventoryComponent") as InventoryComponent if who else null
	if inv == null and is_inside_tree():
		var p := get_tree().get_first_node_in_group("player")
		inv = p.get_node_or_null("InventoryComponent") as InventoryComponent if p else null
	if inv:
		inv.add_material(m[0], int(m[1]), int(m[2]), m[3])

func _say(msg: String) -> void:
	var p := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if p and p.has_signal("posture_changed"):
		p.posture_changed.emit(msg)

func _set_overlay(mat: Material) -> void:
	for m in _meshes:
		if is_instance_valid(m):
			m.material_overlay = mat

# ---------------------------------------------------------------- morte, esfola e volta

func _on_health_depleted() -> void:
	hitbox.deactivate()
	stats.remove_modifiers_from_source(_stagger_src)
	_set_state(State.DEAD)
	_set_overlay(null)
	for hb in find_children("Hurtbox_*", "HurtboxComponent", false, false):
		hb.set_deferred(&"monitorable", false)
	# Tomba de lado
	var tw := create_tween()
	tw.tween_property(body, "rotation:z", PI * 0.45, 0.9).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	name_label.text = "%s (abatido) · [E] esfolar" % config.get("name", "")
	harvest_queue.clear()
	for h in config.get("harvest", []):
		if h.has("needs_intact") and not anatomy.is_part_intact(h.needs_intact):
			continue
		var mats: Array = h.materials
		if h.has("if_broken") and not anatomy.is_part_intact(h.if_broken):
			mats = h.broken_materials
		harvest_queue.append({"label": h.label, "materials": mats})
	corpse_time_left = float(config.get("corpse", 300.0))
	add_to_group("harvestable")
	_say(("🏆 %s derrotado! Esfole o corpo [E]" if config.get("boss", false) else "%s abatido · segure [E] para esfolar") % config.get("name", ""))

func _process_dead(delta: float) -> void:
	if corpse_time_left > 0.0:
		corpse_time_left -= delta
		if corpse_time_left <= 0.0:
			_corpse_gone()
	elif respawn_timer > 0.0:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			respawn()

func _corpse_gone() -> void:
	corpse_time_left = 0.0
	harvest_queue.clear()
	remove_from_group("harvestable")
	body.visible = false
	name_label.visible = false
	respawn_timer = float(config.get("respawn", 600.0))

func is_harvestable() -> bool:
	return state == State.DEAD and not harvest_queue.is_empty() and corpse_time_left > 0.0

func next_harvest_label() -> String:
	return harvest_queue[0].label if is_harvestable() else ""

func get_harvest_verb() -> String:
	return "Esfolando"

func harvest_next(harvester: Node = null) -> String:
	if not is_harvestable():
		return ""
	var entry: Dictionary = harvest_queue.pop_front()
	for m in entry.materials:
		_give(harvester, m)
	if harvester and "mastery" in harvester and harvester.mastery:
		harvester.mastery.add_xp(&"esfola", 40.0)
	if harvest_queue.is_empty():
		_corpse_gone()
	return entry.label

## Volta inteiro para a clareira: Vida, Postura, partes, chifre e placas
func respawn() -> void:
	respawn_timer = -1.0
	global_position = home
	velocity = Vector3.ZERO
	stats.remove_modifiers_from_source(_stagger_src)
	stats.remove_modifiers_from_source(_carapace_src)
	_register_parts()
	pools.reset_all()
	horn_broken = false
	carapace_broken = false
	enraged = false
	body.rotation = Vector3.ZERO
	body.visible = true
	if body.horn_node:
		body.horn_node.visible = true
	if body.plates_node:
		body.plates_node.visible = true
	for hb in find_children("Hurtbox_*", "HurtboxComponent", false, false):
		hb.set_deferred(&"monitorable", true)
	name_label.visible = true
	name_label.text = str(config.get("name", ""))
	_set_state(State.IDLE)

## Barra do boss no HUD (GDD-12 §9)
func boss_bar_info() -> Dictionary:
	var p := _target()
	var engaged: bool = p != null and not state in [State.IDLE, State.DEAD, State.RETURN] \
		and _flat(p.global_position - global_position).length() < 35.0
	return {"name": name_label.text if name_label else str(config.get("name", "")),
		"health": pools.current_health, "max_health": stats.get_stat(&"max_health"),
		"poise": pools.current_poise, "max_poise": stats.get_stat(&"max_poise"), "engaged": engaged}
