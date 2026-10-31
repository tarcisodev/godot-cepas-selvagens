class_name PlanadorNest
extends Node3D
const _LedgerSources = preload("res://scripts/net/ledger_sources.gd")

## Ninho de Planador no alto de um morro (GDD-16 §4, Prova do Ninho). Chegar até ele é a primeira
## parte da prova. [E] com carne Íntegra (abate cuidadoso) deixa a oferenda; um adulto vem voando
## de longe, pousa e só aceita quem ofereceu. Montar leva os 1,5 s de sempre; aí começa o voo
## bravio (BraveFlight). Aguentou: vira montaria própria marcada, Elo 50, e você segue voando nela.
## Caiu: a queda é de verdade e ele vai embora. O ninho é do mundo: outro jogador pode roubar a
## oferenda enquanto o adulto não chegou. Domado, o ninho fica vazio até o próximo filhote crescer.

enum State { READY, OFFERED, WAITING, TRIAL, EMPTY }

## Dias de jogo até o próximo filhote crescer (depois de um domado)
const REGROW_DAYS: int = 3
## O adulto chega deste longe e desta altura, nesta velocidade (m, m, m/s)
const ARRIVE_FROM: float = 45.0
const ARRIVE_HEIGHT: float = 22.0
const FLY_SPEED: float = 12.0
## Pousado, espera o dono da oferenda por este tempo (s) e vai embora
const WAIT_TIME: float = 60.0
## Voo bravio: altura e raio da volta em torno do ninho
const TRIAL_HEIGHT: float = 18.0
const TRIAL_RADIUS: float = 22.0
const TRIAL_SPEED: float = 14.0
## Voo bravio do Eclipse: 25 s, janela de 0,7 s e trancos 20% mais seguidos
const ECLIPSE_FLIGHT: Vector3 = Vector3(25.0, 0.7, 0.8)
## Sem ninguém a esta distância, o do Eclipse sai do ninho e voa em volta (m)
const ECLIPSE_ROAM: float = 30.0
const ECLIPSE_ROAM_RADIUS: float = 26.0

var state: State = State.READY
## Ninho do Arquipélago do Eclipse (GDD-18 §7.2): o Planador do Eclipse já está nele, sem oferenda,
## e monta quem chegar primeiro; o voo bravio é mais duro e sai com Elo 30. Uma vez por evento.
var eclipse: bool = false
## Ninho da Matriarca: o filhote só aparece depois que ela cai (unlock_eclipse)
var locked: bool = false
## Nome do bicho que aparece no ninho
var eclipse_name: String = "Planador do Eclipse"
var adult: Mount
var offered_by: Player
var flight: BraveFlight
var talk_radius: float = 1.0
var nest_seed: int = 0
## Dia de jogo em que um filhote volta a ocupar o ninho (State.EMPTY)
var regrow_day: int = 0
## Testes trocam a fonte do WASD do voo bravio
var input_source: Callable

var _label: Label3D
var _wait: float = 0.0
var _angle: float = 0.0
var _hud: float = 0.0
var _rider_health: float = 0.0

func _ready() -> void:
	add_to_group("talkable")
	add_to_group("planador_nests")
	_build_visual()
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 16
	_label.outline_size = 5
	_label.modulate = Color(1.0, 0.9, 0.6)
	_label.position.y = 1.4
	_label.visibility_range_end = 16.0
	add_child(_label)

func _process(delta: float) -> void:
	if eclipse:
		_process_eclipse(delta)
		return
	if state == State.EMPTY and MountBond.today() >= regrow_day:
		state = State.READY
	if state == State.WAITING:
		_wait -= delta
		if _wait <= 0.0:
			_tell(offered_by, "🪶 O Planador cansou de esperar e foi embora")
			_send_away()
	_label.text = "Ninho de Planador\n" + _status()

# ---------------------------------------------------------------- Eclipse

func _process_eclipse(delta: float) -> void:
	if state == State.READY and not locked:
		_spawn_eclipse()
	if state == State.WAITING and adult and is_instance_valid(adult) and adult.rider == null:
		# Ninguém perto: sai voando em volta da ilha; alguém chegou: volta e pousa no ninho
		var near := _nearest_player() < ECLIPSE_ROAM
		if not near:
			_angle += delta * FLY_SPEED * 0.5 / ECLIPSE_ROAM_RADIUS
			adult.airborne = true
			var c := global_position + Vector3(cos(_angle), 0, sin(_angle)) * ECLIPSE_ROAM_RADIUS + Vector3(0, 10.0, 0)
			_fly_toward(c, FLY_SPEED * 0.6, delta)
		else:
			var spot := global_position + Vector3(1.6, 0, 0)
			if adult.global_position.distance_to(spot) > 0.3:
				adult.airborne = true
				_fly_toward(spot, FLY_SPEED, delta)
			else:
				adult.global_position = spot
				adult.airborne = false
				adult._speed = 0.0
	if state == State.WAITING:
		_label.text = "%s\n[E] montar (voo bravio)" % eclipse_name
	elif state == State.EMPTY:
		_label.text = "Ninho do Eclipse\nVazio"
	elif locked:
		_label.text = "Ninho da Matriarca\nGuardado por ela"
	else:
		_label.text = ""

func _nearest_player() -> float:
	var best := INF
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node3D:
			best = minf(best, (p as Node3D).global_position.distance_to(global_position))
	return best

## A Matriarca caiu: o filhote dela aparece no ninho
func unlock_eclipse() -> void:
	locked = false

func _spawn_eclipse() -> void:
	nest_seed += 1
	adult = Mount.new()
	adult.name = "PlanadorDoEclipse"
	adult.dna = CreatureDNA.eclipse(hash([global_position, nest_seed, "eclipse"]))
	adult.kind = Mount.Kind.AIR
	adult.display_name = eclipse_name
	adult.skip_settle = true
	get_parent().add_child(adult)
	adult.global_position = global_position + Vector3(1.6, 0, 0)
	adult.autopilot = func(_d: float) -> void: pass
	adult.rider_mounted.connect(_on_adult_mounted)
	state = State.WAITING

func _status() -> String:
	match state:
		State.READY: return "[E] Deixar oferenda (carne Íntegra)"
		State.OFFERED: return "Oferenda no ninho · um Planador vem vindo"
		State.WAITING: return "O Planador espera quem ofereceu"
		State.TRIAL: return "Voo bravio!"
	return "Vazio · o próximo filhote cresce em %d dia(s)" % maxi(1, regrow_day - MountBond.today())

func talk_to(node: Node) -> void:
	var p := node as Player
	if p == null:
		return
	match state:
		State.READY:
			offer(p)
		State.OFFERED:
			if p != offered_by:
				steal(p)
		State.WAITING:
			if eclipse or p == offered_by:
				adult.begin_mount(p)
			else:
				_tell(p, "O Planador não deixa você chegar perto")
		State.EMPTY:
			if eclipse:
				_tell(p, "🪶 Ninho do Eclipse vazio: o Planador já foi levado neste evento")
			else:
				_tell(p, "🪶 Ninho vazio · o próximo filhote cresce em %d dia(s)" % maxi(1, regrow_day - MountBond.today()))

## Deixa a carne Íntegra; devolve o motivo: &"ok", &"sem_carne", &"estabulo_cheio" ou &"ocupado"
func offer(p: Player) -> StringName:
	if state != State.READY:
		return &"ocupado"
	var eco := get_tree().get_first_node_in_group("ecosystem") as EcosystemSpawner
	if eco and eco.owned.size() >= EcosystemSpawner.MAX_OWNED:
		_tell(p, "🪶 Seu estábulo está cheio (%d/%d): não há onde ficar um Planador" % [eco.owned.size(), EcosystemSpawner.MAX_OWNED])
		return &"estabulo_cheio"
	var meat := _integro_meat(p)
	if meat.is_empty():
		_tell(p, "🪶 O Planador só aceita carne Íntegra (do abate cuidadoso)")
		return &"sem_carne"
	p.inventory.consume_stack(meat, 1)
	offered_by = p
	state = State.OFFERED
	_spawn_adult()
	_tell(p, "🪶 Oferenda no ninho. Um Planador vem vindo; fique por perto")
	return &"ok"

## Outro jogador pega a oferenda antes de o adulto chegar: ele dá meia-volta
func steal(thief: Player) -> void:
	if state != State.OFFERED or thief == offered_by:
		return
	_LedgerSources.gain(&"nest_steal", name, func(): thief.inventory.add_material(&"carne_crua", 1, 3, [&"integro"]))
	_tell(thief, "🥩 Você roubou a oferenda do ninho")
	_tell(offered_by, "🪶 Alguém roubou a sua oferenda; o Planador deu meia-volta")
	_send_away()

func _integro_meat(p: Player) -> Dictionary:
	if p.inventory == null:
		return {}
	for s in p.inventory.get_stacks(&"carne_crua"):
		if s.traits.has(&"integro"):
			return s
	return {}

# ---------------------------------------------------------------- o adulto

func _spawn_adult() -> void:
	nest_seed += 1
	var dna := CreatureDNA.randomized(CreatureDNA.Species.PLANADOR, hash([global_position, nest_seed]))
	adult = Mount.new()
	adult.name = "PlanadorDoNinho"
	adult.dna = dna
	adult.kind = Mount.Kind.AIR
	adult.display_name = "Planador bravio"
	adult.skip_settle = true
	adult.reserved_for = offered_by
	get_parent().add_child(adult)
	var a := randf() * TAU
	adult.global_position = global_position + Vector3(cos(a), 0, sin(a)) * ARRIVE_FROM + Vector3(0, ARRIVE_HEIGHT, 0)
	adult.airborne = true
	adult.autopilot = _arrive
	adult.rider_mounted.connect(_on_adult_mounted)

## Voa até o ninho, desce e pousa ao lado da oferenda
func _arrive(delta: float) -> void:
	var spot := global_position + Vector3(1.6, 0, 0)
	var to := spot - adult.global_position
	if to.length() <= 0.3:
		adult.global_position = spot
		adult.airborne = false
		adult._speed = 0.0
		adult.autopilot = Callable()
		state = State.WAITING
		_wait = WAIT_TIME
		_tell(offered_by, "🪶 O Planador comeu a oferenda e espera. [E] no ninho (ou nele) para montar")
		return
	_fly_toward(spot, FLY_SPEED, delta)

func _on_adult_mounted(p: Player) -> void:
	if eclipse and state == State.WAITING:
		offered_by = p
	if p != offered_by or state != State.WAITING:
		return
	state = State.TRIAL
	flight = BraveFlight.new(hash([global_position, nest_seed, "voo"]))
	if eclipse:
		flight.make_hard(ECLIPSE_FLIGHT.x, ECLIPSE_FLIGHT.y, ECLIPSE_FLIGHT.z)
	_rider_health = p.pools.current_health if p.pools else 0.0
	_angle = 0.0
	adult.airborne = true
	adult.autopilot = _trial

## Voo bravio: dá voltas altas em torno do ninho, subindo e mergulhando, e chacoalha a cada tranco
func _trial(delta: float) -> void:
	var p := adult.rider
	if p == null:
		# Saltou ([E]) ou foi derrubado por golpe: a prova acabou
		_fail(null)
		return
	var input: Vector2 = input_source.call() if input_source.is_valid() else Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if p.pools and p.pools.current_health < _rider_health:
		flight.hurt()
	_rider_health = p.pools.current_health if p.pools else 0.0
	var result := flight.step(delta, input)
	_angle += delta * TRIAL_SPEED / TRIAL_RADIUS
	var ground := _ground(global_position.x, global_position.z)
	var wave := sin(flight.time * 1.3) * 4.0
	var target := global_position + Vector3(cos(_angle), 0, sin(_angle)) * TRIAL_RADIUS
	target.y = ground + TRIAL_HEIGHT + wave
	_fly_toward(target, TRIAL_SPEED * 1.4, delta)
	# Chacoalha para o lado do tranco
	adult.rotation.z = lerpf(adult.rotation.z, -flight.jolt.x * 0.6, minf(1.0, delta * 8.0))
	adult.rotation.x = lerpf(adult.rotation.x, flight.jolt.y * 0.4, minf(1.0, delta * 8.0))
	_hud -= delta
	if _hud <= 0.0:
		_hud = 0.1
		p.posture_changed.emit(flight.hud_text())
	match result:
		&"domado":
			_tame(p)
		&"caiu":
			_fail(p)

## Domado: troca o adulto por uma montaria própria marcada (Elo 50) no mesmo lugar, com você montado
func _tame(p: Player) -> void:
	var eco := get_tree().get_first_node_in_group("ecosystem") as EcosystemSpawner
	var dna := adult.dna
	var where := adult.global_transform
	adult.autopilot = Callable()
	adult.rider = null
	p.mounted_on = null
	adult.queue_free()
	adult = null
	state = State.EMPTY
	regrow_day = MountBond.today() + REGROW_DAYS
	var origin := &"eclipse" if eclipse else &"ninho"
	if eco == null or not eco.add_owned_mount(dna, MountBond.create(dna, origin, MountBond.today())):
		_tell(p, "🪶 Sem lugar no estábulo: o Planador foi embora")
		return
	var m: Mount = eco._owned_nodes[eco._owned_nodes.size() - 1]
	m.skip_settle = true
	m.global_transform = where
	m.rotation.x = 0.0
	m.rotation.z = 0.0
	m.airborne = true
	m.mount(p)
	if eclipse:
		p.posture_changed.emit("🌑 Você domou o %s! Ele é seu (Elo 30, só aceita você)" % eclipse_name)
	else:
		p.posture_changed.emit("🪶 Você domou o Planador! Ele é seu (Elo 50, só aceita você)")

## Caiu (ou saltou): a queda é de verdade; ele vai embora e o ninho volta a aceitar oferenda
func _fail(p: Player) -> void:
	if p and adult.rider == p:
		adult.dismount() # no alto: queda livre
		p.posture_changed.emit("💥 O Planador te derrubou!")
	_send_away()

## Some no céu: sobe e se afasta por alguns segundos e vai embora
func _send_away() -> void:
	# O do Eclipse não volta: uma chance por evento
	state = State.EMPTY if eclipse else State.READY
	offered_by = null
	flight = null
	if adult == null or not is_instance_valid(adult):
		adult = null
		return
	adult.reserved_for = null
	adult.airborne = true
	var leaving := adult
	var clock := {"left": 6.0} # cada adulto que vai embora tem o seu tempo
	leaving.autopilot = func(delta: float) -> void:
		clock.left -= delta
		var away := leaving.global_position - global_position
		away.y = 0.0
		away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
		leaving.global_position += (away * FLY_SPEED + Vector3(0, 6.0, 0)) * delta
		if clock.left <= 0.0:
			leaving.queue_free()
	adult = null

func _fly_toward(target: Vector3, speed: float, delta: float) -> void:
	var to := target - adult.global_position
	var step := to.normalized() * minf(speed * delta, to.length())
	adult.global_position += step
	adult._speed = speed
	var flat := Vector2(to.x, to.z)
	if flat.length() > 0.05:
		adult.rotation.y = lerp_angle(adult.rotation.y, atan2(-to.x, -to.z), minf(1.0, delta * 5.0))

## Chão do vale, ou o da ilha voadora onde o ninho está (GDD-18)
func _ground(x: float, z: float) -> float:
	var land := get_tree().current_scene.get_node_or_null("Landscape") if get_tree().current_scene else null
	var terrain: float = land.get_height_at(x, z) if land else global_position.y
	return SkyIslandField.ground_at(x, z, global_position.y, terrain)

func _tell(p: Node, msg: String) -> void:
	if p and is_instance_valid(p) and p.has_signal("posture_changed"):
		p.posture_changed.emit(msg)

## Ninho: anel de galhos com penas e uma pedra de apoio
func _build_visual() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.3, 0.18)
	wood.roughness = 1.0
	for i in 10:
		var twig := MeshInstance3D.new()
		var stick := CylinderMesh.new()
		stick.top_radius = 0.05
		stick.bottom_radius = 0.06
		stick.height = 1.1
		twig.mesh = stick
		twig.material_override = wood
		var a := TAU * i / 10.0
		twig.position = Vector3(cos(a) * 0.55, 0.15, sin(a) * 0.55)
		twig.rotation = Vector3(PI * 0.5, -a, 0.25)
		add_child(twig)
	var feather := StandardMaterial3D.new()
	feather.albedo_color = Color(0.26, 0.42, 0.62)
	for i in 3:
		var f := MeshInstance3D.new()
		var plume := BoxMesh.new()
		plume.size = Vector3(0.06, 0.02, 0.35)
		f.mesh = plume
		f.material_override = feather
		f.position = Vector3(randf_range(-0.3, 0.3), 0.22, randf_range(-0.3, 0.3))
		f.rotation.y = randf() * TAU
		add_child(f)
