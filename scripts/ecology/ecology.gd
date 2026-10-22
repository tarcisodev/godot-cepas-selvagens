class_name Ecology
extends Node3D

## Ciclo natural (GDD-10 §3–§5): grade de solo com Umidade e Nutrientes (células de CELL m),
## passo de vida das plantas (crescer, florir, frutificar, semear, morrer) e o nutriente que volta
## ao solo quando planta ou bicho morre. Roda devagar (a cada TICK s); o clima vem do WeatherSystem.

const CELL: float = 6.0
const TICK: float = 2.0
## Plantas por célula (árvores contam 3) e teto do vale inteiro
const CELL_CAPACITY: int = 3
const MAX_PLANTS: int = 420
## Mutação da semente: 3% base, até 12% em solo saturado de nutriente (GDD-10 §4)
const MUTATION_BASE: float = 0.03
const MUTATION_RICH: float = 0.12

@export var weather: WeatherSystem
@export var landscape: Node3D

var cells: int = 0
var moisture: PackedFloat32Array
var nutrients: PackedFloat32Array
var occupancy: PackedInt32Array
var _timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _sun: Node

func _ready() -> void:
	add_to_group("ecology")
	if weather == null:
		weather = get_parent().get_node_or_null("WeatherSystem") as WeatherSystem
	if landscape == null:
		landscape = get_parent().get_node_or_null("Landscape")
	_sun = get_parent().get_node_or_null("Sun")
	_rng.seed = 4242
	_init_grid()

func _init_grid() -> void:
	cells = int(ceil(WorldBounds.HALF * 2.0 / CELL))
	moisture.resize(cells * cells)
	nutrients.resize(cells * cells)
	occupancy.resize(cells * cells)
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 0.02
	for iz in cells:
		for ix in cells:
			var x := -WorldBounds.HALF + (ix + 0.5) * CELL
			var z := -WorldBounds.HALF + (iz + 0.5) * CELL
			var i := iz * cells + ix
			moisture[i] = clampf(0.45 + _river_bonus(x, z) + noise.get_noise_2d(x, z) * 0.15, 0.0, 1.0)
			nutrients[i] = clampf(0.45 + noise.get_noise_2d(x + 500.0, z) * 0.25, 0.05, 1.0)

## Índice da célula de solo em (x, z); -1 fora do mapa
func cell_index(x: float, z: float) -> int:
	var ix := int(floor((x + WorldBounds.HALF) / CELL))
	var iz := int(floor((z + WorldBounds.HALF) / CELL))
	if ix < 0 or iz < 0 or ix >= cells or iz >= cells:
		return -1
	return iz * cells + ix

func cell_at(pos: Vector3) -> Dictionary:
	var i := cell_index(pos.x, pos.z)
	if i < 0:
		return {"moisture": 0.0, "nutrients": 0.0}
	return {"moisture": moisture[i], "nutrients": nutrients[i]}

## Devolve nutriente ao solo (planta ou bicho que morreu e apodreceu ali)
func deposit(pos: Vector3, amount: float) -> void:
	var i := cell_index(pos.x, pos.z)
	if i >= 0:
		nutrients[i] = clampf(nutrients[i] + amount, 0.0, 1.0)

func is_day() -> bool:
	var h: float = _sun.get("current_time_hours") if _sun else 12.0
	return h >= 6.0 and h <= 18.0

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = TICK
		step(TICK / _day_length())

func _day_length() -> float:
	return _sun.get("day_length_seconds") if _sun and "day_length_seconds" in _sun else 300.0

## Um passo do ecossistema (`days` = dias de jogo desde o último). Público para os testes.
func step(days: float) -> void:
	var heat: float = weather.heat if weather else 0.5
	var rain: float = weather.rain if weather else 0.0
	for i in moisture.size():
		var m := moisture[i] + rain * days * 6.0 - heat * days * 0.45
		moisture[i] = clampf(m, 0.0, 1.0)
		nutrients[i] = clampf(nutrients[i] + days * 0.02, 0.0, 1.0) # intemperismo lento
	_river_moisture()
	_step_plants(days)

## Perto do rio (e na várzea alagada) o solo nunca seca
func _river_moisture() -> void:
	var flood_w := 2.2 if RiverSystem.flood > 0.5 else 1.6
	for iz in cells:
		var z := -WorldBounds.HALF + (iz + 0.5) * CELL
		var cx := RiverSystem.get_river_center_x(z)
		var hw := RiverSystem.get_water_half_width(z)
		for ix in cells:
			var x := -WorldBounds.HALF + (ix + 0.5) * CELL
			if absf(x - cx) < hw * flood_w + CELL:
				var i := iz * cells + ix
				moisture[i] = maxf(moisture[i], 0.75)

func _river_bonus(x: float, z: float) -> float:
	var d := RiverSystem.get_distance_to_river(x, z) - RiverSystem.get_water_half_width(z)
	return clampf(1.0 - d / 25.0, 0.0, 1.0) * 0.35

# ---------------------------------------------------------------- plantas

func _step_plants(days: float) -> void:
	var light := is_day()
	# Lua cheia: o luar deixa as plantas crescerem também de noite, devagar (GDD-10 §2.1)
	if not light and _sun and _sun.has_method("moon_illumination") and _sun.moon_illumination() > 0.6:
		light = true
		days *= 0.3
	occupancy.fill(0)
	var plants := get_tree().get_nodes_in_group("plants")
	for n in plants:
		var p := n as PlantBody
		if p:
			var i := cell_index(p.global_position.x, p.global_position.z)
			if i >= 0:
				occupancy[i] += 3 if p.dna.kind == PlantDNA.Kind.ARVORE else 1
	for n in plants:
		var p := n as PlantBody
		if p == null or not is_instance_valid(p) or p.is_queued_for_deletion():
			continue
		var i := cell_index(p.global_position.x, p.global_position.z)
		if i < 0:
			continue
		var r := p.life_tick(days, {"moisture": moisture[i], "nutrients": nutrients[i]}, light)
		moisture[i] = maxf(0.0, moisture[i] - r.water)
		nutrients[i] = maxf(0.0, nutrients[i] - r.food)
		match r.event:
			"seeds":
				_reproduce(p, plants.size())
			"died":
				deposit(p.global_position, 0.3 if p.dna.kind == PlantDNA.Kind.ARVORE else 0.1)
				p.remove_from_group("plants")
				p.queue_free()

func _reproduce(p: PlantBody, total: int) -> void:
	# Árvore e arbusto: o fruto cai e vira frutinha coletável no chão
	if p.dna.kind == PlantDNA.Kind.ARVORE or p.dna.kind == PlantDNA.Kind.ARBUSTO:
		for k in _rng.randi_range(1, 2):
			_drop_fruit(p.global_position + Vector3(_rng.randf_range(-2.0, 2.0), 0, _rng.randf_range(-2.0, 2.0)))
	if total >= MAX_PLANTS:
		return
	var radius := 7.0 if p.dna.kind == PlantDNA.Kind.ARVORE else 3.5
	var seeds := 1 if p.dna.kind == PlantDNA.Kind.ARVORE else 2
	for k in seeds:
		var a := _rng.randf() * TAU
		var spot := p.global_position + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(1.5, radius)
		sow(p.dna, spot)

## Planta uma semente em `spot` se der: terra firme, fora da vila, célula com lugar.
## A chance de mutação sobe com o nutriente do lugar onde ela cai.
func sow(parent: PlantDNA, spot: Vector3) -> PlantBody:
	var i := cell_index(spot.x, spot.z)
	if i < 0 or not WorldBounds.inside(spot.x, spot.z, 4.0) or CityHub.in_village(spot.x, spot.z, 1.0):
		return null
	var weight := 3 if parent.kind == PlantDNA.Kind.ARVORE else 1
	if occupancy[i] + weight > CELL_CAPACITY + (1 if parent.kind != PlantDNA.Kind.ARVORE else 0):
		return null
	spot.y = _ground(spot.x, spot.z)
	if RiverSystem.is_in_water(spot):
		return null
	occupancy[i] += weight
	var rich := clampf((nutrients[i] - 0.6) / 0.4, 0.0, 1.0)
	var chance := lerpf(MUTATION_BASE, MUTATION_RICH, rich)
	var child := PlantBody.new()
	child.dna = PlantDNA.seed_of(parent, _rng.randi(), chance)
	child.stage = PlantBody.Stage.SEMENTE
	child.position = spot
	child.rotation.y = _rng.randf() * TAU
	add_child(child)
	return child

func _drop_fruit(pos: Vector3) -> void:
	var fruit := GatherableResource.new()
	fruit.type = GatherableResource.Type.FRUTINHA
	fruit.respawn_enabled = false
	fruit.position = Vector3(pos.x, _ground(pos.x, pos.z), pos.z)
	fruit.add_to_group("fallen_fruit")
	add_child(fruit)
	# Fruto que ninguém pega apodrece em um dia e vira nutriente (pode ter sido comido antes)
	var ref: WeakRef = weakref(fruit)
	get_tree().create_timer(_day_length()).timeout.connect(func():
		var f: Node3D = ref.get_ref()
		if f and not f.is_queued_for_deletion():
			deposit(f.global_position, 0.05)
			f.queue_free())

func _ground(x: float, z: float) -> float:
	return landscape.get_height_at(x, z) if landscape and landscape.has_method("get_height_at") else 0.0
