class_name Mount
extends Node3D

## Montaria (GDD-09 §5): terrestre, voadora ou aquática. [E] perto começa a montar — leva
## MOUNT_TIME parado e levar dano cancela (sem "moleza" que não existiria no online).
## Montado, a montaria anda pela câmera (WASD), Shift corre gastando fôlego, e [E] desmonta.
## Golpe que quebra a Postura do cavaleiro derruba da montaria.
## A terrestre atravessa rio nadando: na água funda boia com o dorso na linha d'água, devagar,
## sem corrida nem pulo, gastando fôlego; sem fôlego nada mais devagar ainda.
## Montaria própria tem Elo (GDD-16): [E] abre a tela de cuidado, andar montado soma Elo e a
## Companheira com a ordem Seguir acompanha o dono a pé; no Apito de Osso ([H]) ela vem até ele
## pelo mundo, correndo ou voando (sem teleporte). Voando alto, [E] salta da montaria no ar; a
## Companheira plena voadora pega o dono em queda no [H], se chegar antes do chão.
## A montaria própria tem Vida e hurtbox: fora da vila pode ser ferida e morrer de vez (GDD-16 §7).
## Montado na Companheira, segurar [Q] fareja (MountSenses, GDD-16 §6).

## [E] numa montaria própria: o estábulo abre a tela de cuidado
signal care_requested(mount: Mount, player: Player)
## Montaria própria morreu (o estábulo tira do save e deixa a Lembrança)
signal died(mount: Mount)
## Alguém terminou de montar (o ninho começa o voo bravio)
signal rider_mounted(player: Player)

enum Kind { LAND, AIR, WATER }

const MOUNT_TIME: float = 1.5
const STAMINA_MAX: float = 100.0
const STAMINA_DRAIN: float = 18.0
const STAMINA_REGEN: float = 12.0
const AIR_CEILING: float = 40.0
const GRAVITY: float = 18.0
## Nado da montaria terrestre: água mais funda que isto boia; velocidade e gasto de fôlego
const LAND_SWIM_DEPTH: float = 0.9
const LAND_SWIM_SPEED: float = 0.45
const LAND_SWIM_TIRED: float = 0.25
const LAND_SWIM_DRAIN: float = 6.0
## Distância mínima da borda do mapa: a montaria anda por posição e atravessaria as paredes invisíveis
const EDGE_MARGIN: float = 3.0
## Companheira seguindo o dono: para a esta distância e corre quando ele se afasta mais que isto
const FOLLOW_DISTANCE: float = 4.0
const FOLLOW_RUN_DISTANCE: float = 12.0
## Apito: chega a esta distância do dono; desiste se não chegar neste tempo (s)
const CALL_ARRIVE: float = 3.0
const CALL_TIMEOUT: float = 60.0
## A voadora chamada viaja a esta altura sobre o chão e desce nos últimos CALL_DESCEND m
const CALL_FLY_HEIGHT: float = 10.0
const CALL_DESCEND: float = 20.0
## Acima disto do chão, descer da voadora é saltar no ar (o cavaleiro cai de verdade)
const AIR_JUMP_HEIGHT: float = 3.0
## Sem cavaleiro no ar, a voadora plana para baixo até pousar (m/s)
const GLIDE_DOWN_SPEED: float = 3.0
## Pegada no ar (GDD-16 §5): mergulho (m/s), distância em que pega, alcance e fôlego mínimo
const CATCH_SPEED: float = 34.0
const CATCH_REACH: float = 2.5
const CATCH_RANGE: float = 60.0
const CATCH_STAMINA: float = 20.0
## Golpe "forte" (tira Elo com o dono montado): pelo menos esta fração da Vida máxima
const HEAVY_HIT_FRACTION: float = 0.1
## Ferida com o dono montado e sem levar golpe por este tempo, ainda montados: fugiram juntos (Elo)
const ESCAPE_SECONDS: float = 20.0

## Velocidades (m/s) por tipo: [passeio, corrida]
const SPEEDS: Dictionary = {Kind.LAND: Vector2(9.0, 15.0), Kind.AIR: Vector2(11.0, 17.0), Kind.WATER: Vector2(7.0, 11.0)}

@export var dna: CreatureDNA
@export var kind: Kind = Kind.LAND
@export var display_name: String = "Montaria"
## Montaria própria (capturada) — velocidade pelo gene porte; as de teste ficam em 1.0
@export var owned: bool = false
## Elo com o dono (só montaria própria; GDD-16)
var bond: MountBond

var body: CreatureBody
var rider: Player
var stamina: float = STAMINA_MAX
var airborne: bool = false
## Montaria terrestre nadando (rio fundo)
var swimming: bool = false
## Alcance do [E] conta a partir da borda do corpo (Player.talk_distance); a Raia é larga e baixa
var talk_radius: float = 0.0

var _channel_player: Player
var _channel_time: float = 0.0
var _channel_health: float = 0.0
var _vertical: float = 0.0
var _speed: float = 0.0
var _label: Label3D
var _landscape: Node
var _hud_timer: float = 0.0
var _base_name: String = ""
var _following: bool = false
## Dono que apitou (a montaria está a caminho dele)
var _called_by: Player
var _call_time: float = 0.0
## Dono em queda que ela está tentando pegar, e a Vida dele quando o mergulho começou
var _catching: Player
var _catch_health: float = 0.0
## Voo guiado por outro sistema (Prova do Ninho, GDD-16 §4): chamado com o delta no lugar do
## controle do cavaleiro e do comportamento sem cavaleiro
var autopilot: Callable
## Só este jogador pode montar (o adulto do ninho aceita só quem deixou a oferenda)
var reserved_for: Player
## Nasceu no ar: não assenta no chão no primeiro quadro
var skip_settle: bool = false
## Faro e Olho de caça ([Q] montado; só montaria própria)
var senses: MountSenses
## Vida (só montaria própria)
var stats: StatsComponent
var pools: PoolsComponent
var dead: bool = false
var _last_health: float = 0.0
var _escape_timer: float = 0.0

func _ready() -> void:
	add_to_group("talkable")
	add_to_group("mounts")
	body = CreatureBody.new()
	body.dna = dna if dna else CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 7)
	add_child(body)
	talk_radius = body.dna.body_size() * 0.5 + (0.6 if kind == Kind.WATER else 0.0)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 16
	_label.outline_size = 5
	_label.modulate = Color(1.0, 0.9, 0.6)
	_label.position.y = body.back_height + 1.0
	_label.visibility_range_end = 14.0
	add_child(_label)
	var scene := get_tree().current_scene if is_inside_tree() else null
	_landscape = scene.get_node_or_null("Landscape") if scene else null
	_settle.call_deferred()

## Liga o Elo e mostra o nome que o dono deu (sem nome, "Seu Trotador")
func set_bond(b: MountBond) -> void:
	if _base_name.is_empty():
		_base_name = display_name
	bond = b
	display_name = b.display_name(_base_name) if b else _base_name
	if b and stats == null:
		_build_combat()
		senses = MountSenses.new()
		senses.name = "MountSenses"
		add_child(senses)

## Vida pela espécie e porte (a mesma tabela dos bichos selvagens) e hurtbox no corpo
func _build_combat() -> void:
	stats = StatsComponent.new()
	stats.name = "StatsComponent"
	add_child(stats)
	stats.set_base_stat(&"max_health", float(WildCreature.HEALTH.get(body.dna.species, 100.0)) * (0.6 + 0.4 * body.dna.size_factor()))
	stats.set_base_stat(&"max_poise", 40.0)
	pools = PoolsComponent.new()
	pools.name = "PoolsComponent"
	pools.stats = stats
	add_child(pools)
	pools.reset_all()
	_last_health = pools.current_health
	pools.health_changed.connect(_on_health_changed)
	pools.health_depleted.connect(_die)
	var hurtbox := HurtboxComponent.new()
	hurtbox.name = "BodyHurtbox"
	hurtbox.entity = self
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = maxf(0.3, body.dna.body_size() * 0.28)
	shape.height = maxf(shape.radius * 2.0, body.back_height + 0.2)
	col.shape = shape
	hurtbox.add_child(col)
	hurtbox.position.y = shape.height * 0.5
	add_child(hurtbox)

## Na vila (zona segura) não toma dano; o próprio dono também não a fere
func filter_incoming_hit(hit: HitEvent) -> void:
	var tree := get_tree()
	var zm: Node = tree.get_first_node_in_group("zone_manager") if tree else null
	var safe: bool = zm != null and zm.has_method("can_combat_at") and not zm.can_combat_at(global_position)
	var by_owner: bool = hit.attacker != null and tree != null and hit.attacker == tree.get_first_node_in_group("player")
	if dead or safe or by_owner:
		hit.raw_damage = 0.0
		hit.poise_damage = 0.0

func _on_health_changed(current: float, max_val: float) -> void:
	var lost := _last_health - current
	_last_health = current
	if lost <= 0.0 or dead or rider == null or bond == null:
		return
	_escape_timer = ESCAPE_SECONDS
	if lost >= max_val * HEAVY_HIT_FRACTION:
		bond.hurt()

## Morte de verdade: derruba o cavaleiro (no alto, ele cai) e avisa o estábulo
func _die() -> void:
	if dead:
		return
	dead = true
	_called_by = null
	_catching = null
	var p := rider
	if p:
		dismount()
		p.posture_changed.emit("💔 %s morreu" % display_name)
	died.emit(self)

## Chamado pelo player no [E]: montaria própria abre a tela de cuidado; as outras começam a montar
func talk_to(player: Node) -> void:
	var p := player as Player
	if p == null or rider != null or _channel_player != null or p.mounted_on != null:
		return
	if bond:
		care_requested.emit(self, p)
		return
	begin_mount(p)

## Começa a montar: MOUNT_TIME parado, dano cancela
func begin_mount(p: Player) -> void:
	if p == null or rider != null or _channel_player != null or p.mounted_on != null:
		return
	if reserved_for != null and p != reserved_for:
		p.posture_changed.emit("%s não deixa você chegar perto" % display_name)
		return
	_channel_player = p
	_channel_time = MOUNT_TIME
	_channel_health = p.pools.current_health if p.pools else 0.0
	p.posture_changed.emit("Montando %s... (fique parado)" % display_name)

func _process(delta: float) -> void:
	if _channel_player:
		_process_channel(delta)
	_label.visible = rider == null
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var near := player != null and Player.talk_distance(player.global_position, self) < Player.TALK_RANGE
	var action := "Montando..." if _channel_player else (("[E] Cuidar" if bond else "[E] Montar") if near else "chegue mais perto")
	if bond:
		_label.text = "%s\n%s · Elo %d\n%s" % [display_name, bond.band_name(), floori(bond.elo), action]
	else:
		_label.text = "%s\n%s" % [display_name, action]
	if rider == null and not _following:
		stamina = minf(STAMINA_MAX, stamina + STAMINA_REGEN * delta)
		body.animate(delta, 0.0, 0.0, airborne)

func _process_channel(delta: float) -> void:
	var p := _channel_player
	# Nadando, a correnteza arrasta o corpo: conta só o jogador apertando direção
	var moved := p.wants_move if p.is_swimming else Vector2(p.velocity.x, p.velocity.z).length() > 0.5
	var hurt := p.pools != null and p.pools.current_health < _channel_health
	if moved or hurt or p.is_downed or Player.talk_distance(p.global_position, self) > Player.TALK_RANGE + 1.0:
		p.posture_changed.emit("Montaria interrompida" + (" pelo dano!" if hurt else ""))
		_channel_player = null
		return
	_channel_time -= delta
	if _channel_time <= 0.0:
		_channel_player = null
		mount(p)

func mount(p: Player) -> void:
	rider = p
	p.mounted_on = self
	p.is_swimming = false
	p.end_fall() # pego no ar: a queda acaba aqui, sem dano
	_speed = 0.0 # sem sobra do último passeio (na borda ela jogaria a Raia para fora d'água)
	_vertical = 0.0
	p.velocity = Vector3.ZERO
	if p.pools and not p.pools.poise_broken.is_connected(_on_rider_poise_broken):
		p.pools.poise_broken.connect(_on_rider_poise_broken)
	p.posture_changed.emit("🐾 Montado: %s · [E] desmontar" % display_name)
	rider_mounted.emit(p)

## Desce da montaria; o cavaleiro fica ao lado, no chão (ou na margem, se for a Raia)
func dismount() -> void:
	if rider == null:
		return
	var p := rider
	rider = null
	p.mounted_on = null
	_escape_timer = 0.0
	if p.pools and p.pools.poise_broken.is_connected(_on_rider_poise_broken):
		p.pools.poise_broken.disconnect(_on_rider_poise_broken)
	if kind == Kind.AIR and airborne and global_position.y - _ground(global_position.x, global_position.z) > AIR_JUMP_HEIGHT:
		# Salto no ar: o cavaleiro sai do dorso com o embalo do voo e cai de verdade; ela fica no ar
		var forward := -global_transform.basis.z
		p.global_position = body.saddle.global_position - Vector3(0, 1.2, 0)
		p.velocity = Vector3(forward.x, 0, forward.z) * _speed * 0.6
		p.is_skydiving = true
		_speed = 0.0
		p.posture_changed.emit("🪂 Queda livre · [H] chama %s" % display_name)
		return
	_speed = 0.0
	var side := global_transform.basis.x.normalized()
	var spot := _clamp_to_bounds(global_position + side * 1.6)
	if kind == Kind.WATER:
		# Sem margem por perto (mar aberto) o cavaleiro cai n'água ali mesmo, na superfície
		spot = _nearest_shore(global_position)
	else:
		spot.y = _ground(spot.x, spot.z) + 0.1
	p.global_position = spot
	p.velocity = Vector3.ZERO
	if kind == Kind.AIR and airborne:
		_land()
	p.posture_changed.emit("Em Pé")

func _on_rider_poise_broken() -> void:
	if rider:
		var p := rider
		dismount()
		p.posture_changed.emit("💥 Derrubado da montaria!")

func _physics_process(delta: float) -> void:
	if autopilot.is_valid():
		autopilot.call(delta)
		body.animate(delta, _speed, _vertical, airborne)
		if rider:
			_seat_rider()
		return
	if rider == null:
		if _catching:
			_following = _dive(delta)
		elif _called_by:
			_following = _come(delta)
		elif airborne:
			_following = false
			_glide_down(delta)
		else:
			_following = bond != null and bond.companion and bond.order == MountBond.Order.FOLLOW and kind != Kind.WATER and _follow(delta)
		return
	if rider.is_downed:
		dismount()
		return
	if bond:
		var elo_before := floori(bond.elo)
		bond.add_ride_time(delta, MountBond.today())
		if floori(bond.elo) > elo_before:
			EventBusAutoload.report(rider, &"elo", {"mount": display_name, "elo": floori(bond.elo)})
		if _escape_timer > 0.0:
			_escape_timer -= delta
			if _escape_timer <= 0.0:
				var gain := bond.fight(MountBond.today())
				if gain > 0.0:
					rider.posture_changed.emit("🐾 Você e %s escaparam juntos · Elo +%d" % [display_name, roundi(gain)])
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var menus_open := not get_tree().get_nodes_in_group("open_menus").is_empty()
	if menus_open:
		input = Vector2.ZERO
	var cam_yaw: float = rider.camera_rig.global_rotation.y if rider.camera_rig else rotation.y
	var dir := (Basis(Vector3.UP, cam_yaw) * Vector3(input.x, 0, input.y))
	dir.y = 0.0
	var moving := dir.length() > 0.1
	var wants_run := Input.is_action_pressed("sprint") and moving and stamina > 1.0 and not menus_open and not swimming
	if wants_run:
		stamina = maxf(0.0, stamina - STAMINA_DRAIN * delta)
	elif swimming and moving:
		stamina = maxf(0.0, stamina - LAND_SWIM_DRAIN * delta)
	else:
		stamina = minf(STAMINA_MAX, stamina + STAMINA_REGEN * delta)
	var speeds: Vector2 = SPEEDS[kind] * (body.dna.mount_speed_factor() if owned else 1.0)
	var target_speed := (speeds.y if wants_run else speeds.x) if moving else 0.0
	if swimming:
		target_speed *= LAND_SWIM_SPEED if stamina > 1.0 else LAND_SWIM_TIRED
	_speed = move_toward(_speed, target_speed, delta * 14.0)
	var step := (dir.normalized() if moving else -global_transform.basis.z) * _speed * delta
	# Na borda do mapa desliza ao longo dela em vez de sair
	step = _clamp_to_bounds(global_position + step) - global_position
	if moving:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 6.0))
	match kind:
		Kind.LAND:
			_move_land(step, delta, not menus_open and Input.is_action_just_pressed("jump"))
		Kind.AIR:
			_move_air(step, delta, menus_open)
		Kind.WATER:
			_move_water(step, moving)
	if rider == null:
		return
	body.animate(delta, _speed, _vertical, airborne)
	_seat_rider()
	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.3
		rider.posture_changed.emit("%s %s · Fôlego %d%% · [E] desmontar" % ["🌊" if swimming else "🐾", display_name + (" nadando" if swimming else ""), roundi(stamina)])

## Cavaleiro sentado no dorso, virado para a frente da montaria
func _seat_rider() -> void:
	rider.global_position = body.saddle.global_position - Vector3(0, 0.3 if kind == Kind.WATER else 0.55, 0)
	if rider.visual_mesh:
		rider.visual_mesh.global_rotation.y = global_rotation.y

func _move_land(step: Vector3, delta: float, jump: bool) -> void:
	var next := global_position + step
	var ground := _ground(next.x, next.z)
	# Não sobe paredão (degrau maior que 1,2 m); nadando, o degrau conta da linha d'água
	var base_y: float = RiverSystem.get_water_height(global_position.z) if swimming else global_position.y
	if ground - base_y > 1.2:
		next = global_position
		ground = _ground(next.x, next.z)
	var surface := RiverSystem.get_water_height(next.z)
	if RiverSystem.is_in_water(Vector3(next.x, ground, next.z)) and surface - ground > LAND_SWIM_DEPTH:
		# Água funda: boia com o dorso rente à água (o cavaleiro fica com as pernas molhadas)
		swimming = true
		_vertical = 0.0
		global_position = Vector3(next.x, surface - body.back_height * 0.8, next.z)
		return
	swimming = false
	if jump and global_position.y <= ground + 0.05:
		_vertical = 7.0
	_vertical -= GRAVITY * delta
	var y := global_position.y + _vertical * delta
	if y <= ground:
		y = ground
		_vertical = 0.0
	global_position = Vector3(next.x, y, next.z)

func _move_air(step: Vector3, delta: float, menus_open: bool) -> void:
	var climb := 0.0
	if not menus_open:
		if Input.is_action_pressed("jump"):
			climb = 6.0
		elif Input.is_action_pressed("crouch"):
			climb = -7.0
	# Corrente de vento (GDD-18 §4): dentro dela o teto some e a voadora sobe sozinha
	# Rajada da rara (GDD-18 §4): empurra de lado e tira da coluna quem não corrige no WASD
	# Tranco da mítica: segurar o lado oposto (o próprio passo) anula. Corrente lateral das ilhotas:
	# leva adiante e segura a altura, sem subir
	step += SkyIslandHazards.current_push(global_position, step) * delta
	var lift := SkyIslandField.current_at(global_position + step)
	if lift and climb == 0.0 and not lift.is_link():
		climb = SkyIslandField.CURRENT_LIFT
	_vertical = move_toward(_vertical, climb, delta * 12.0)
	var next := global_position + step + Vector3(0, _vertical * delta, 0)
	var ground := _ground(next.x, next.z)
	var ceiling := ground + AIR_CEILING
	if lift:
		ceiling = maxf(ceiling, lift.top_y() + SkyIslandField.CURRENT_OVERSHOOT)
	else:
		# Embaixo de uma ilha, a base de rocha não se atravessa
		next.y = minf(next.y, SkyIslandField.underside_at(next.x, next.z, global_position.y))
	# Acima do teto (saiu da Corrente) não cai de uma vez: perde altura planando
	next.y = minf(next.y, maxf(ceiling, global_position.y - GLIDE_DOWN_SPEED * delta))
	next.y = maxf(next.y, ground)
	airborne = next.y > ground + 0.3
	if not airborne and step.length() < 0.001 and climb <= 0.0:
		next.y = ground
	global_position = next

func _move_water(step: Vector3, moving: bool) -> void:
	var next := global_position + step
	var surface := RiverSystem.get_water_height(next.z) - 0.05
	var ground := _ground(next.x, next.z)
	if not RiverSystem.is_in_water(Vector3(next.x, ground, next.z)):
		# Só desce na margem quem empurra para a terra; embalo sem tecla apenas para na borda
		if moving:
			dismount()
		return
	global_position = Vector3(next.x, surface, next.z)

## Companheira com a ordem Seguir: anda (ou corre, gastando fôlego) até perto do dono a pé.
## Para quando chega, quando o dono monta outra montaria ou quando ele passa do alcance do apito.
## false = parada (o _process faz a animação de descanso)
func _follow(delta: float) -> bool:
	var owner_node := get_tree().get_first_node_in_group("player") as Player
	if owner_node == null or owner_node.mounted_on != null or _channel_player != null:
		_speed = 0.0
		return false
	var to := owner_node.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist <= FOLLOW_DISTANCE or dist > bond.whistle_range():
		_speed = 0.0
		return false
	_travel(to / dist, dist > FOLLOW_RUN_DISTANCE, delta, 0.0)
	return true

## Apito de Osso: vai até o dono que apitou (GDD-16 §5). Quem decide se ela ouviu é o estábulo.
func call_to(p: Player) -> void:
	_called_by = p
	_call_time = CALL_TIMEOUT

func is_coming() -> bool:
	return _called_by != null

## Pegada no ar: mergulha atrás do dono em queda. Quem confere Elo, alcance e fôlego é o estábulo.
func catch_falling(p: Player) -> void:
	_called_by = null
	_catching = p
	_catch_health = p.pools.current_health if p.pools else 0.0
	stamina = maxf(0.0, stamina - CATCH_STAMINA)

func is_catching() -> bool:
	return _catching != null

## Mergulho até o dono (mirando um pouco à frente da queda). Alcançou: ele monta na hora.
## Falha se ele pousar, cair na água ou levar dano antes; aí a queda segue com o dano inteiro.
func _dive(delta: float) -> bool:
	var p := _catching
	if not is_instance_valid(p) or p.mounted_on != null:
		_catching = null
		return false
	var hurt := p.pools != null and p.pools.current_health < _catch_health
	# Logo depois do salto o is_on_floor() ainda é o de antes de montar: pousou = fim da queda
	var landed := p.is_on_floor() and not p.is_skydiving and p.fall_speed == 0.0
	if hurt or landed or p.is_swimming:
		_catching = null
		p.posture_changed.emit("%s não chegou a tempo" % display_name if not hurt else "💥 Levou dano: a pegada falhou")
		return false
	var aim := p.global_position + p.velocity * 0.15
	var to := aim - global_position
	if to.length() <= CATCH_REACH:
		_catching = null
		mount(p)
		p.posture_changed.emit("🪶 %s te pegou no ar!" % display_name)
		return false
	var step := to.normalized() * minf(CATCH_SPEED * delta, to.length())
	var next := _clamp_to_bounds(global_position + step)
	next.y = maxf(next.y, _ground(next.x, next.z))
	global_position = next
	airborne = next.y > _ground(next.x, next.z) + 0.3
	_speed = CATCH_SPEED
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), minf(1.0, delta * 8.0))
	body.animate(delta, _speed, -CATCH_SPEED, airborne)
	return true

## Sem cavaleiro no ar: desce planando devagar e pousa
func _glide_down(delta: float) -> void:
	var ground := _ground(global_position.x, global_position.z)
	var over_water := RiverSystem.is_in_water(Vector3(global_position.x, ground, global_position.z))
	var floor_y := maxf(ground, RiverSystem.get_water_height(global_position.z) + 1.5) if over_water else ground
	global_position.y = maxf(floor_y, global_position.y - GLIDE_DOWN_SPEED * delta)
	if global_position.y <= floor_y + 0.01 and not over_water:
		_land()

## A caminho do dono: corre enquanto tem fôlego; a voadora voa alto e desce perto dele.
## Para ao lado dele, ou desiste se ele montou outra coisa ou se não chegou a tempo.
func _come(delta: float) -> bool:
	var p := _called_by
	if not is_instance_valid(p) or p.mounted_on != null or _channel_player != null:
		_called_by = null
		_speed = 0.0
		return false
	var to := p.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist <= CALL_ARRIVE:
		_called_by = null
		_speed = 0.0
		if kind == Kind.AIR:
			_land()
		rotation.y = atan2(-to.x, -to.z) if dist > 0.01 else rotation.y
		p.posture_changed.emit("🐾 %s chegou" % display_name)
		return false
	_call_time -= delta
	if _call_time <= 0.0:
		_called_by = null
		_speed = 0.0
		if kind == Kind.AIR:
			_land()
		p.posture_changed.emit("%s não achou caminho até você" % display_name)
		return false
	_travel(to / dist, true, delta, CALL_FLY_HEIGHT if dist > CALL_DESCEND else 0.0)
	return true

## Anda (ou corre, gastando fôlego) sem cavaleiro na direção dada. A terrestre contorna paredão;
## a voadora sobe até fly_height acima do chão (0 = rente ao chão, planando baixo sobre o rio).
func _travel(dir: Vector3, run: bool, delta: float, fly_height: float) -> void:
	run = run and stamina > 1.0
	if run:
		stamina = maxf(0.0, stamina - STAMINA_DRAIN * delta)
	else:
		stamina = minf(STAMINA_MAX, stamina + STAMINA_REGEN * delta)
	var speeds: Vector2 = SPEEDS[kind] * body.dna.mount_speed_factor()
	_speed = move_toward(_speed, speeds.y if run else speeds.x, delta * 14.0)
	if kind != Kind.AIR:
		dir = _detour(dir)
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 6.0))
	var step := _clamp_to_bounds(global_position + dir * _speed * delta) - global_position
	if kind == Kind.AIR:
		var next := global_position + step
		var ground := _ground(next.x, next.z)
		var over_water := RiverSystem.is_in_water(Vector3(next.x, ground, next.z))
		var floor_y := maxf(ground, RiverSystem.get_water_height(next.z) + 1.5) if over_water else ground
		var target_y := minf(floor_y + fly_height, ground + AIR_CEILING)
		if fly_height <= 0.0 and not over_water and global_position.y <= ground + 0.05:
			next.y = ground
		else:
			next.y = maxf(floor_y, lerpf(global_position.y, target_y, minf(1.0, delta * 3.0)))
		airborne = next.y > ground + 0.3
		global_position = next
	else:
		_move_land(step, delta, false)
	body.animate(delta, _speed, _vertical, airborne)

## Direção livre mais perto da pedida: tenta reto e depois desvia 45° e 90° para cada lado,
## evitando degrau maior que o que a montaria sobe (a mesma regra do _move_land)
func _detour(dir: Vector3) -> Vector3:
	var base_y: float = RiverSystem.get_water_height(global_position.z) if swimming else global_position.y
	for a in [0.0, 0.8, -0.8, 1.6, -1.6]:
		var d := dir.rotated(Vector3.UP, a)
		var probe := global_position + d * 1.5
		if _ground(probe.x, probe.z) - base_y <= 1.2:
			return d
	return dir

func _land() -> void:
	airborne = false
	_vertical = 0.0
	global_position.y = _ground(global_position.x, global_position.z)

func _settle() -> void:
	if skip_settle:
		return
	if kind == Kind.WATER:
		global_position.y = RiverSystem.get_water_height(global_position.z) - 0.05
	else:
		global_position.y = _ground(global_position.x, global_position.z)

## Terra firme mais perto da Raia (procura em volta, de 1 em 1 m), para descer ao lado dela
func _nearest_shore(from: Vector3) -> Vector3:
	for r in range(1, 9):
		var best := Vector3.INF
		var best_rise := INF
		for i in 16:
			var a := TAU * i / 16.0
			var p := from + Vector3(cos(a), 0, sin(a)) * float(r)
			if not WorldBounds.inside(p.x, p.z, EDGE_MARGIN):
				continue
			var g := _ground(p.x, p.z)
			var surface := RiverSystem.get_water_height(p.z)
			# Seco (acima da água): escolhe o ponto menos alto, para não descer em cima do barranco
			if g > surface - 0.05 and g - surface < best_rise:
				best = Vector3(p.x, g, p.z)
				best_rise = g - surface
		if best != Vector3.INF:
			return best + Vector3(0, 0.1, 0)
	var spot := _clamp_to_bounds(from)
	if RiverSystem.is_in_sea(spot.x, spot.z):
		spot.y = RiverSystem.get_water_height(spot.z)
		return spot
	var cx := RiverSystem.get_river_center_x(from.z)
	var side := 1.0 if from.x >= cx else -1.0
	spot = _clamp_to_bounds(Vector3(cx + side * (RiverSystem.get_water_half_width(from.z) + 1.5), 0, from.z))
	spot.y = _ground(spot.x, spot.z) + 0.1
	return spot

func _clamp_to_bounds(pos: Vector3) -> Vector3:
	var h := WorldBounds.get_half() - EDGE_MARGIN
	return Vector3(clampf(pos.x, -h, h), pos.y, clampf(pos.z, -h, h))

## Chão em (x, z): o terreno, ou o topo de uma ilha voadora logo abaixo da montaria (GDD-18)
func _ground(x: float, z: float) -> float:
	var terrain: float = _landscape.get_height_at(x, z) if _landscape else 0.0
	return SkyIslandField.ground_at(x, z, global_position.y, terrain)
