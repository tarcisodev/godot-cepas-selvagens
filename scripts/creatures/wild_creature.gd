class_name WildCreature
extends Node3D

## Bicho selvagem procedural (GDD-09 §4): corpo CreatureBody + comportamento simples por plano.
## Quadrúpede pasta, anda e foge de quem corre perto; ave voa em círculos e às vezes desce;
## peixe nada rio acima e abaixo. Sem física: assenta no relevo ou na água a cada frame.

const FLEE_RANGE: float = 9.0

@export var dna: CreatureDNA
## Raio de passeio em volta de onde nasceu
@export var roam_radius: float = 14.0

var body: CreatureBody
var home: Vector3
var _target: Vector3
var _speed: float = 0.0
var _wait: float = 0.0
var _flee_time: float = 0.0
var _angle: float = 0.0
var _altitude: float = 14.0
var _rng := RandomNumberGenerator.new()
var _landscape: Node

func _ready() -> void:
	add_to_group("wild_creatures")
	body = CreatureBody.new()
	body.dna = dna if dna else CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 1)
	add_child(body)
	_rng.seed = body.dna.dna_seed + 17
	home = global_position
	_target = home
	_angle = _rng.randf() * TAU
	_altitude = _rng.randf_range(10.0, 20.0)
	var scene := get_tree().current_scene if is_inside_tree() else null
	_landscape = scene.get_node_or_null("Landscape") if scene else null

func _process(delta: float) -> void:
	match body.dna.plan():
		CreatureDNA.Plan.QUADRUPED:
			_walk(delta)
		CreatureDNA.Plan.BIRD:
			_fly(delta)
		CreatureDNA.Plan.FISH:
			_swim(delta)

func _walk(delta: float) -> void:
	var small := body.dna.species == CreatureDNA.Species.SALTARELO
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and player.global_position.distance_to(global_position) < FLEE_RANGE and _player_is_loud(player):
		_flee_time = 3.0
		var away := (global_position - player.global_position)
		away.y = 0
		_target = global_position + away.normalized() * 10.0
	var desired := 0.0
	if _flee_time > 0.0:
		_flee_time -= delta
		desired = 7.5 if small else 8.0
	elif _wait > 0.0:
		_wait -= delta
	else:
		desired = 2.2 if small else 1.4
		if Vector2(_target.x - global_position.x, _target.z - global_position.z).length() < 0.6:
			_wait = _rng.randf_range(2.0, 7.0)
			_target = _pick_ground_target()
	_speed = move_toward(_speed, desired, delta * 6.0)
	var to := _target - global_position
	to.y = 0.0
	if to.length() > 0.1 and _speed > 0.05:
		var step := to.normalized() * _speed * delta
		var next := global_position + step
		if not _is_water(next):
			global_position = next
		else:
			_target = _pick_ground_target()
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), minf(1.0, delta * 5.0))
	var hop := absf(sin(Time.get_ticks_msec() / 120.0)) * 0.25 if small and _speed > 1.0 else 0.0
	global_position.y = _ground(global_position.x, global_position.z) + hop
	body.animate(delta, _speed)

func _fly(delta: float) -> void:
	_angle += delta * 0.22
	var r := roam_radius * 1.6
	var desired := home + Vector3(cos(_angle) * r, 0, sin(_angle) * r)
	var ground := _ground(desired.x, desired.z)
	desired.y = ground + _altitude + sin(_angle * 2.3) * 3.0
	var old := global_position
	global_position = global_position.lerp(desired, minf(1.0, delta * 1.5))
	var vel := (global_position - old) / maxf(delta, 0.001)
	if Vector2(vel.x, vel.z).length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-vel.x, -vel.z), minf(1.0, delta * 3.0))
	rotation.z = lerp_angle(rotation.z, 0.35, delta * 2.0)
	body.animate(delta, vel.length(), vel.y, true)

func _swim(delta: float) -> void:
	_angle += delta * (0.25 if body.dna.species == CreatureDNA.Species.RAIA else 0.6)
	var z := home.z + sin(_angle) * roam_radius
	var half := RiverSystem.get_water_half_width(z)
	var x := RiverSystem.get_river_center_x(z) + cos(_angle * 1.7) * half * 0.45
	var y := RiverSystem.get_water_height(z) - (0.35 if body.dna.species == CreatureDNA.Species.RAIA else 0.5)
	var old := global_position
	global_position = global_position.lerp(Vector3(x, y, z), minf(1.0, delta * 1.2))
	var vel := (global_position - old) / maxf(delta, 0.001)
	if vel.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-vel.x, -vel.z), minf(1.0, delta * 3.0))
	body.animate(delta, vel.length())

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

func _is_water(p: Vector3) -> bool:
	return RiverSystem.is_in_water(Vector3(p.x, _ground(p.x, p.z), p.z))

func _ground(x: float, z: float) -> float:
	return _landscape.get_height_at(x, z) if _landscape else 0.0
