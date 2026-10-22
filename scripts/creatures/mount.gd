class_name Mount
extends Node3D

## Montaria (GDD-09 §5): terrestre, voadora ou aquática. [E] perto começa a montar — leva
## MOUNT_TIME parado e levar dano cancela (sem "moleza" que não existiria no online).
## Montado, a montaria anda pela câmera (WASD), Shift corre gastando fôlego, e [E] desmonta.
## Golpe que quebra a Postura do cavaleiro derruba da montaria.

enum Kind { LAND, AIR, WATER }

const MOUNT_TIME: float = 1.5
const STAMINA_MAX: float = 100.0
const STAMINA_DRAIN: float = 18.0
const STAMINA_REGEN: float = 12.0
const AIR_CEILING: float = 40.0
const GRAVITY: float = 18.0

## Velocidades (m/s) por tipo: [passeio, corrida]
const SPEEDS: Dictionary = {Kind.LAND: Vector2(9.0, 15.0), Kind.AIR: Vector2(11.0, 17.0), Kind.WATER: Vector2(7.0, 11.0)}

@export var dna: CreatureDNA
@export var kind: Kind = Kind.LAND
@export var display_name: String = "Montaria"
## Montaria própria (capturada) — velocidade pelo gene porte; as de teste ficam em 1.0
@export var owned: bool = false

var body: CreatureBody
var rider: Player
var stamina: float = STAMINA_MAX
var airborne: bool = false

var _channel_player: Player
var _channel_time: float = 0.0
var _channel_health: float = 0.0
var _vertical: float = 0.0
var _speed: float = 0.0
var _label: Label3D
var _landscape: Node
var _hud_timer: float = 0.0

func _ready() -> void:
	add_to_group("talkable")
	add_to_group("mounts")
	body = CreatureBody.new()
	body.dna = dna if dna else CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 7)
	add_child(body)
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

## Chamado pelo player no [E]: começa a montar (ou ignora se já tem cavaleiro)
func talk_to(player: Node) -> void:
	var p := player as Player
	if p == null or rider != null or _channel_player != null or p.mounted_on != null:
		return
	_channel_player = p
	_channel_time = MOUNT_TIME
	_channel_health = p.pools.current_health if p.pools else 0.0
	p.posture_changed.emit("Montando %s... (fique parado)" % display_name)

func _process(delta: float) -> void:
	if _channel_player:
		_process_channel(delta)
	_label.visible = rider == null
	_label.text = "%s\n%s" % [display_name, "Montando..." if _channel_player else "[E] Montar"]
	if rider == null:
		stamina = minf(STAMINA_MAX, stamina + STAMINA_REGEN * delta)
		body.animate(delta, 0.0, 0.0, false)

func _process_channel(delta: float) -> void:
	var p := _channel_player
	var moved := Vector2(p.velocity.x, p.velocity.z).length() > 0.5
	var hurt := p.pools != null and p.pools.current_health < _channel_health
	if moved or hurt or p.is_downed or p.global_position.distance_to(global_position) > Player.TALK_RANGE + 1.0:
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
	p.velocity = Vector3.ZERO
	if p.pools and not p.pools.poise_broken.is_connected(_on_rider_poise_broken):
		p.pools.poise_broken.connect(_on_rider_poise_broken)
	p.posture_changed.emit("🐾 Montado: %s · [E] desmontar" % display_name)

## Desce da montaria; o cavaleiro fica ao lado, no chão (ou na margem, se for a Raia)
func dismount() -> void:
	if rider == null:
		return
	var p := rider
	rider = null
	p.mounted_on = null
	if p.pools and p.pools.poise_broken.is_connected(_on_rider_poise_broken):
		p.pools.poise_broken.disconnect(_on_rider_poise_broken)
	var side := global_transform.basis.x.normalized()
	var spot := global_position + side * 1.6
	if kind == Kind.WATER:
		spot = _nearest_shore(global_position)
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
	if rider == null:
		return
	if rider.is_downed:
		dismount()
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var menus_open := not get_tree().get_nodes_in_group("open_menus").is_empty()
	if menus_open:
		input = Vector2.ZERO
	var cam_yaw: float = rider.camera_rig.global_rotation.y if rider.camera_rig else rotation.y
	var dir := (Basis(Vector3.UP, cam_yaw) * Vector3(input.x, 0, input.y))
	dir.y = 0.0
	var moving := dir.length() > 0.1
	var wants_run := Input.is_action_pressed("sprint") and moving and stamina > 1.0 and not menus_open
	if wants_run:
		stamina = maxf(0.0, stamina - STAMINA_DRAIN * delta)
	else:
		stamina = minf(STAMINA_MAX, stamina + STAMINA_REGEN * delta)
	var speeds: Vector2 = SPEEDS[kind] * (body.dna.mount_speed_factor() if owned else 1.0)
	var target_speed := (speeds.y if wants_run else speeds.x) if moving else 0.0
	_speed = move_toward(_speed, target_speed, delta * 14.0)
	var step := (dir.normalized() if moving else -global_transform.basis.z) * _speed * delta
	if moving:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 6.0))
	match kind:
		Kind.LAND:
			_move_land(step, delta, menus_open)
		Kind.AIR:
			_move_air(step, delta, menus_open)
		Kind.WATER:
			_move_water(step)
	if rider == null:
		return
	body.animate(delta, _speed, _vertical, airborne)
	# Cavaleiro sentado no dorso, virado para a frente da montaria
	rider.global_position = body.saddle.global_position - Vector3(0, 0.3 if kind == Kind.WATER else 0.55, 0)
	if rider.visual_mesh:
		rider.visual_mesh.global_rotation.y = global_rotation.y
	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.3
		rider.posture_changed.emit("🐾 %s · Fôlego %d%% · [E] desmontar" % [display_name, roundi(stamina)])

func _move_land(step: Vector3, delta: float, menus_open: bool) -> void:
	var next := global_position + step
	var ground := _ground(next.x, next.z)
	# Não entra em água funda nem sobe paredão (degrau maior que 1,2 m)
	if RiverSystem.is_in_water(Vector3(next.x, ground, next.z)) or ground - global_position.y > 1.2:
		next = global_position
		ground = _ground(next.x, next.z)
	if Input.is_action_just_pressed("jump") and not menus_open and global_position.y <= ground + 0.05:
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
	_vertical = move_toward(_vertical, climb, delta * 12.0)
	var next := global_position + step + Vector3(0, _vertical * delta, 0)
	var ground := _ground(next.x, next.z)
	next.y = clampf(next.y, ground, ground + AIR_CEILING)
	airborne = next.y > ground + 0.3
	if not airborne and step.length() < 0.001 and climb <= 0.0:
		next.y = ground
	global_position = next

func _move_water(step: Vector3) -> void:
	var next := global_position + step
	var surface := RiverSystem.get_water_height(next.z) - 0.05
	var ground := _ground(next.x, next.z)
	if not RiverSystem.is_in_water(Vector3(next.x, ground, next.z)):
		# Empurrou para fora do rio: desce na margem
		if step.length() > 0.001:
			dismount()
		return
	global_position = Vector3(next.x, surface, next.z)

func _land() -> void:
	airborne = false
	_vertical = 0.0
	global_position.y = _ground(global_position.x, global_position.z)

func _settle() -> void:
	if kind == Kind.WATER:
		global_position.y = RiverSystem.get_water_height(global_position.z) - 0.05
	else:
		global_position.y = _ground(global_position.x, global_position.z)

func _nearest_shore(from: Vector3) -> Vector3:
	var cx := RiverSystem.get_river_center_x(from.z)
	var half := RiverSystem.get_water_half_width(from.z)
	var side := 1.0 if from.x >= cx else -1.0
	return Vector3(cx + side * (half + 1.5), from.y, from.z)

func _ground(x: float, z: float) -> float:
	return _landscape.get_height_at(x, z) if _landscape else 0.0
