class_name SkyIslandHazards
extends Node3D

## Perigos das ilhas voadoras (GDD-18 §4 e §8): rajadas na rara, Corrente que liga e desliga na
## lendária e raios da tempestade da Ilha-Ruína. Quando cada coisa acontece sai do relógio único e
## da forma da ilha (função pura, igual em todo cliente); quem é atingido, o servidor decide.
## Filho do SkyIslandField.

const _ForgedItem = preload("res://scripts/data/forged_item.gd")
const WIND_SOUND: AudioStream = preload("res://assets/audio/Small_Sound_Kit/Small Sound Kit/Ambience/Amb_Wind.wav")
const CRACKLE_SOUND: AudioStream = preload("res://assets/audio/Small_Sound_Kit/Small Sound Kit/Magic/Mgc_Electric_Throw_01.wav")
const BOLT_SOUND: AudioStream = preload("res://assets/audio/Small_Sound_Kit/Small Sound Kit/Magic/Mgc_Electric_Impact_01.wav")

## Rajada (rara): uma a cada 30–60 s reais (vaga de 45 s com folga de 15 s para cada lado),
## avisada 1 s antes pelo som e pelas folhas; sopra por meio segundo
const GUST_SLOT: float = 45.0
const GUST_JITTER: float = 15.0
const GUST_WARN: float = 1.0
const GUST_BLOW: float = 0.5
## Empurrão de quem está em pé no topo: com o atrito do andar do jogador, joga ~4 m
const GUST_PUSH: float = 5.0
## Na Corrente da rara, a rajada empurra a montaria de lado (m/s): sai da coluna se não corrigir
const CURRENT_GUST_SPEED: float = 9.0
## Agachado não voa; pedra ou árvore a até 3 m do lado de onde vem o vento também segura
const SHELTER_REACH: float = 3.0
## Corrente da lendária: liga 40 s, desliga 20 s
const LEGEND_CURRENT_ON: float = 40.0
const LEGEND_CURRENT_CYCLE: float = 60.0
## Raio (lendária): um a cada 20–30 s; marca no chão 1,5 s antes; acerta quem está a 2,5 m
const STRIKE_SLOT: float = 25.0
const STRIKE_JITTER: float = 5.0
const STRIKE_MARK: float = 1.5
const STRIKE_RADIUS: float = 2.5
const STRIKE_DAMAGE: float = 45.0
## Postura quebrada de quem é atingido
const STRIKE_POISE: float = 1000.0
## Céu aberto: nada acima até esta altura
const OPEN_SKY: float = 30.0

## Rajadas já sopradas em cada jogador: "jogador|ilha|k" → true
var _gusted: Dictionary = {}
## Avisos de rajada já tocados: "ilha|k" → true
var _gust_told: Dictionary = {}
## Raios: "ilha|k" → {"pos": Vector3, "mark": Node3D, "done": bool}
var strikes: Dictionary = {}
## Quem está na Zona Selvagem do céu (id do jogador → ilha), para o aviso de entrar e sair
var _wild: Dictionary = {}

# ---------------------------------------------------------------- tempo (puro)

## Segundos reais corridos do relógio único (o mesmo dia que o céu usa)
static func now() -> float:
	var field := SkyIslandField.instance
	var d := field.day() if is_instance_valid(field) else SkyIslandSchedule.game_day()
	return d * DayNightCycle.seconds_per_day()

static func _rand(isl: Dictionary, what: String, k: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.shape_seed), what, k])
	return rng

## Rajada da rara que está avisando ou soprando em `t`: {k, at, dir, blowing} ou {}
static func gust(isl: Dictionary, t: float) -> Dictionary:
	if int(isl.rarity) != SkyIslandSchedule.Rarity.RARA or not bool(isl.solid):
		return {}
	var k0 := floori(t / GUST_SLOT)
	for k in [k0, k0 + 1]:
		var rng := _rand(isl, "rajada", k)
		var at := (float(k) + 0.5) * GUST_SLOT + rng.randf_range(-GUST_JITTER, GUST_JITTER) * 0.5
		if t >= at - GUST_WARN and t < at + GUST_BLOW:
			var a := rng.randf() * TAU
			return {"k": k, "at": at, "dir": Vector3(cos(a), 0.0, sin(a)), "blowing": t >= at}
	return {}

## A Corrente desta ilha está soprando em `t`? (só a lendária desliga)
static func current_on(isl: Dictionary, t: float) -> bool:
	if int(isl.rarity) != SkyIslandSchedule.Rarity.LENDARIA:
		return true
	var offset := float(absi(int(isl.shape_seed)) % int(LEGEND_CURRENT_CYCLE))
	return fposmod(t + offset, LEGEND_CURRENT_CYCLE) < LEGEND_CURRENT_ON

## Raio k da lendária: quando a marca aparece (s). Cai STRIKE_MARK depois.
static func strike_mark_at(isl: Dictionary, k: int) -> float:
	var rng := _rand(isl, "raio", k)
	return (float(k) + 0.5) * STRIKE_SLOT + rng.randf_range(-STRIKE_JITTER, STRIKE_JITTER)

## Empurrão de lado da rajada em quem está na Corrente (velocidade, m/s), para a montaria
static func current_push(p: Vector3) -> Vector3:
	var isl := SkyIslandField.current_at(p)
	if isl == null:
		return Vector3.ZERO
	var g := gust(isl.data, now())
	return g.dir * CURRENT_GUST_SPEED if not g.is_empty() and g.blowing else Vector3.ZERO

# ---------------------------------------------------------------- quem é atingido

## Veste peça da família ferro (cabeça, peito, botas)? Ferro-Celeste não atrai raio (GDD-18 §9).
static func attracts_lightning(p: Node) -> bool:
	var inv = p.get("inventory")
	if inv == null or not inv.has_method("equipped_in"):
		return false
	for slot in _ForgedItem.ARMOR_SLOTS:
		var it = inv.equipped_in(slot)
		if it and it.family == &"ferro" and not it.materials.has(&"ferro_celeste"):
			return true
	return false

## Nada acima da cabeça até OPEN_SKY (pedra, árvore, teto)?
func is_open_sky(p: Node3D) -> bool:
	var from := p.global_position + Vector3(0, 2.0, 0)
	return not _blocked(from, from + Vector3(0, OPEN_SKY, 0), p)

## Abrigado da rajada: agachado ou com algo sólido do lado de onde ela vem
func is_sheltered(p: Node3D, dir: Vector3) -> bool:
	if bool(p.get("is_crouching")):
		return true
	var from := p.global_position + Vector3(0, 1.0, 0)
	return _blocked(from, from - dir * SHELTER_REACH, p)

func _blocked(from: Vector3, to: Vector3, who: Node3D) -> bool:
	if not is_inside_tree():
		return false
	var q := PhysicsRayQueryParameters3D.create(from, to)
	if who is CollisionObject3D:
		q.exclude = [(who as CollisionObject3D).get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()

# ---------------------------------------------------------------- a cada quadro

func _physics_process(_delta: float) -> void:
	var field := get_parent() as SkyIslandField
	if field == null:
		return
	var t := field.day() * DayNightCycle.seconds_per_day()
	var players := get_tree().get_nodes_in_group("player")
	for isl: SkyIsland in field.islands.values():
		if not isl.is_solid():
			continue
		match isl.rarity():
			SkyIslandSchedule.Rarity.RARA:
				_update_gust(isl, t, players)
			SkyIslandSchedule.Rarity.LENDARIA:
				_update_storm(isl, t, players)
	_update_wild(field, players)
	_forget_old(t)

func _update_gust(isl: SkyIsland, t: float, players: Array) -> void:
	var g := gust(isl.data, t)
	if g.is_empty():
		return
	var key := "%s|%d" % [isl.data.id, g.k]
	if not _gust_told.has(key):
		_gust_told[key] = t
		isl.telegraph_gust(g.dir)
	if not g.blowing:
		return
	for p in players:
		if not (p is Node3D) or not SkyIslandField.on_island(isl, (p as Node3D).global_position):
			continue
		if p.get("mounted_on") != null or not p.has_method("apply_knockback"):
			continue
		var pk := "%d|%s" % [p.get_instance_id(), key]
		if _gusted.has(pk):
			continue
		_gusted[pk] = t
		if is_sheltered(p, g.dir):
			continue
		p.apply_knockback(g.dir * GUST_PUSH)
		if p.has_signal("posture_changed"):
			p.posture_changed.emit("💨 Rajada! Agache para não ser jogado da borda.")

## Tempestade da Ilha-Ruína: a marca aparece em quem veste ferro em céu aberto e o raio cai
## STRIKE_MARK depois; quem ficou na marca leva dano de raio e tem a Postura quebrada
func _update_storm(isl: SkyIsland, t: float, players: Array) -> void:
	var k0 := floori(t / STRIKE_SLOT)
	for k in [k0 - 1, k0, k0 + 1]:
		var key := "%s|%d" % [isl.data.id, k]
		var mark_at := strike_mark_at(isl.data, k)
		if t < mark_at or t > mark_at + STRIKE_MARK + 1.0:
			continue
		if not strikes.has(key):
			var target := _pick_target(isl, players)
			strikes[key] = {"t": t, "done": false, "pos": Vector3.INF, "mark": null}
			if target:
				var pos := target.global_position
				pos.y = isl.top_at(pos.x, pos.z)
				strikes[key].pos = pos
				strikes[key].mark = _spawn_mark(pos)
				if target.has_signal("posture_changed"):
					target.posture_changed.emit("⚡ O ferro atrai o raio! Saia da marca.")
		var s: Dictionary = strikes[key]
		if s.done or t < mark_at + STRIKE_MARK:
			continue
		s.done = true
		if s.pos == Vector3.INF:
			continue
		_strike(s.pos, players)
		if is_instance_valid(s.mark):
			s.mark.queue_free()

## Quem o raio procura: o mais exposto que veste ferro em cima da ilha (o primeiro da lista)
func _pick_target(isl: SkyIsland, players: Array) -> Node3D:
	for p in players:
		if not (p is Node3D) or bool(p.get("is_downed")):
			continue
		if SkyIslandField.on_island(isl, (p as Node3D).global_position) and attracts_lightning(p) and is_open_sky(p):
			return p
	return null

func _strike(pos: Vector3, players: Array) -> void:
	_spawn_bolt(pos)
	for p in players:
		if not (p is Node3D):
			continue
		var d := Vector2((p as Node3D).global_position.x - pos.x, (p as Node3D).global_position.z - pos.z).length()
		if d > STRIKE_RADIUS or absf((p as Node3D).global_position.y - pos.y) > 4.0:
			continue
		var hit := HitEvent.new(null, p, STRIKE_DAMAGE, DamageType.Type.LIGHTNING, STRIKE_POISE)
		hit.hit_position = pos
		var result := CombatResolver.resolve_hit(hit)
		if p.has_method("on_hit_feedback"):
			p.on_hit_feedback(hit, result)
		if p.has_signal("posture_changed"):
			p.posture_changed.emit("⚡ Atingido pelo raio! Postura quebrada.")

# ---------------------------------------------------------------- Zona Selvagem (aviso)

## Avisa ao pisar numa ilha rara ou acima ("Zona Selvagem · PvP e full loot") e ao sair dela
func _update_wild(field: SkyIslandField, players: Array) -> void:
	for p in players:
		if not (p is Node3D):
			continue
		var id: int = p.get_instance_id()
		var isl := SkyIslandField.wild_island_at((p as Node3D).global_position)
		var was: StringName = _wild.get(id, &"")
		var now_id: StringName = isl.data.id if isl else &""
		if now_id == was:
			continue
		if now_id.is_empty():
			_wild.erase(id)
		else:
			_wild[id] = now_id
		if not p.has_signal("posture_changed"):
			continue
		if isl:
			p.posture_changed.emit("☠️ Zona Selvagem · PvP e full loot")
		elif not was.is_empty():
			p.posture_changed.emit("Saiu da Zona Selvagem")

func _forget_old(t: float) -> void:
	for d in [_gusted, _gust_told]:
		for k in d.keys():
			if t - float(d[k]) > GUST_SLOT * 2.0 or t < float(d[k]):
				d.erase(k)
	for k in strikes.keys():
		var s: Dictionary = strikes[k]
		if t - float(s.t) > STRIKE_SLOT * 2.0 or t < float(s.t):
			if is_instance_valid(s.mark):
				s.mark.queue_free()
			strikes.erase(k)

# ---------------------------------------------------------------- efeitos

## Marca no chão onde o raio vai cair: anel azul que estala
func _spawn_mark(pos: Vector3) -> Node3D:
	var mark := Node3D.new()
	mark.name = "MarcaDoRaio"
	var ring := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = STRIKE_RADIUS
	disc.bottom_radius = STRIKE_RADIUS
	disc.height = 0.05
	ring.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.55, 0.75, 1.0, 0.45)
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.add_child(ring)
	add_child(mark)
	mark.global_position = pos + Vector3(0, 0.08, 0)
	_play(CRACKLE_SOUND, pos, 30.0)
	return mark

## Raio: coluna de luz que some rápido, clarão e estrondo
func _spawn_bolt(pos: Vector3) -> void:
	var bolt := Node3D.new()
	bolt.name = "Raio"
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 0.25
	cyl.height = 40.0
	m.mesh = cyl
	m.position.y = 20.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.85, 0.92, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.85, 1.0)
	mat.emission_energy_multiplier = 4.0
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.add_child(m)
	var light := OmniLight3D.new()
	light.light_color = Color(0.75, 0.85, 1.0)
	light.light_energy = 8.0
	light.omni_range = 40.0
	light.position.y = 3.0
	bolt.add_child(light)
	add_child(bolt)
	bolt.global_position = pos
	_play(BOLT_SOUND, pos, 80.0)
	if is_inside_tree():
		get_tree().create_timer(0.25).timeout.connect(bolt.queue_free)

func _play(stream: AudioStream, pos: Vector3, unit: float) -> void:
	var a := AudioStreamPlayer3D.new()
	a.stream = stream
	a.unit_size = unit
	a.max_distance = 300.0
	add_child(a)
	a.global_position = pos
	a.finished.connect(a.queue_free)
	if is_inside_tree():
		a.play()

## Som e folhas da rajada, tocados pela ilha (SkyIsland.telegraph_gust)
static func wind_sound() -> AudioStream:
	return WIND_SOUND
