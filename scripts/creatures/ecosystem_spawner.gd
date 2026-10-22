class_name EcosystemSpawner
extends Node3D

## Povoa o vale com fauna e flora procedurais (GDD-09 §4): rebanhos de Trotador, Saltarelos,
## Planadores no céu, Raias e cardumes de Lambari no rio, e árvores, arbustos, Cepas Selvagens e
## cogumelos-lume. Nada nasce na vila, na água nem na arena. Também monta o Estábulo com as
## montarias de teste (Trotador e Planador) e põe a Raia montável no rio perto da vila.

const ARENA_CENTER: Vector2 = Vector2(-27.0, 3.0)
## Montarias próprias por personagem (decisão do Tarciso, GDD-03 §9.4)
const MAX_OWNED: int = 3
## Bicho morto, capturado ou solto volta a nascer no mesmo lugar depois disso (s)
const RESPAWN_DELAY: float = 90.0
## População mínima (repõe se cair abaixo) e máxima (para de reproduzir) por espécie
const POP_MIN: Dictionary = {CreatureDNA.Species.TROTADOR: 4, CreatureDNA.Species.SALTARELO: 4, CreatureDNA.Species.PLANADOR: 2}
const POP_MAX: Dictionary = {CreatureDNA.Species.TROTADOR: 24, CreatureDNA.Species.SALTARELO: 18, CreatureDNA.Species.PLANADOR: 6}
const MOUNTABLE: Dictionary = {CreatureDNA.Species.TROTADOR: Mount.Kind.LAND, CreatureDNA.Species.PLANADOR: Mount.Kind.AIR}
const STABLE_POS: Vector2 = Vector2(-15.0, -5.0)

@export var landscape: Node3D
@export var world_seed: int = 2026

@export_group("Quantidades")
@export var trotador_herds: int = 6
@export var saltarelos: int = 12
@export var planadores: int = 4
@export var raias: int = 3
@export var lambari_schools: int = 4
@export var trees: int = 60
@export var bushes: int = 55
@export var cepas: int = 50
@export var mushrooms: int = 30

var _rng := RandomNumberGenerator.new()
## DNAs das montarias capturadas (save) e os nós delas no estábulo
var owned: Array[CreatureDNA] = []
var _owned_nodes: Array[Mount] = []
var _stable_base: Vector3
var _dialog: CaptureDialog
var _pending_capture: WildCreature
var _pending_player: Node

func _ready() -> void:
	add_to_group("ecosystem")
	if landscape == null:
		landscape = get_parent().get_node_or_null("Landscape")
	_rng.seed = world_seed
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_dialog = CaptureDialog.new()
	layer.add_child(_dialog)
	_dialog.chosen.connect(_on_capture_choice)
	# Continuando um jogo com a natureza salva: ela volta pelo save, não precisa semear agora
	var save := get_node_or_null("/root/SaveGame")
	if not (save and save.load_on_enter and save.read_save().has("nature")):
		_spawn_plants()
		_spawn_fauna()
	_build_stable()

# ---------------------------------------------------------------- flora

func _spawn_plants() -> void:
	var plan := [[PlantDNA.Kind.ARVORE, trees, 16.0], [PlantDNA.Kind.ARBUSTO, bushes, 15.0], [PlantDNA.Kind.CEPA, cepas, 15.0], [PlantDNA.Kind.COGUMELO, mushrooms, 15.0]]
	for p in plan:
		for i in p[1]:
			var spot := _land_spot(p[2], WorldBounds.HALF * 0.92)
			if spot == Vector3.INF:
				continue
			var plant := PlantBody.new()
			plant.dna = PlantDNA.randomized(p[0], _rng.randi())
			# O vale já está vivo: idades e estágios variados (GDD-10 §4)
			var roll := _rng.randf()
			plant.stage = PlantBody.Stage.JOVEM if roll < 0.15 else (PlantBody.Stage.FLORIDA if roll < 0.35 else (PlantBody.Stage.FRUTO if roll < 0.5 else PlantBody.Stage.ADULTA))
			plant.age = _rng.randf() * plant.lifespan() * 0.6
			plant.progress = _rng.randf() * 0.8
			plant.position = spot
			plant.rotation.y = _rng.randf() * TAU
			add_child(plant)

# ---------------------------------------------------------------- fauna

func _spawn_fauna() -> void:
	for h in trotador_herds:
		var center := _land_spot(25.0, WorldBounds.HALF * 0.85)
		if center == Vector3.INF:
			continue
		for i in _rng.randi_range(3, 4):
			_add_wild(CreatureDNA.Species.TROTADOR, center + Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-3, 3)), 14.0)
	for i in saltarelos:
		var spot := _land_spot(16.0, WorldBounds.HALF * 0.85)
		if spot != Vector3.INF:
			_add_wild(CreatureDNA.Species.SALTARELO, spot, 8.0)
	for i in planadores:
		var spot := _land_spot(20.0, WorldBounds.HALF * 0.7)
		if spot != Vector3.INF:
			_add_wild(CreatureDNA.Species.PLANADOR, spot + Vector3(0, 15, 0), 16.0)
	for i in raias:
		_add_wild(CreatureDNA.Species.RAIA, _river_spot(_rng.randf_range(15.0, WorldBounds.HALF * 0.8)), 18.0)
	for s in lambari_schools:
		var z := _rng.randf_range(-12.0, WorldBounds.HALF * 0.8)
		for i in 4:
			_add_wild(CreatureDNA.Species.LAMBARI, _river_spot(z + i * 0.6), 10.0)

func _add_wild(species: CreatureDNA.Species, pos: Vector3, roam: float, p_dna: CreatureDNA = null) -> WildCreature:
	var c := WildCreature.new()
	c.dna = p_dna if p_dna else CreatureDNA.randomized(species, _rng.randi())
	c.roam_radius = roam
	c.position = pos
	c.captured.connect(_on_captured)
	c.removed.connect(_on_removed.bind(species, pos, roam))
	add_child(c)
	return c

# ---------------------------------------------------------------- captura (GDD-03 §9.3)

func _on_captured(c: WildCreature, player: Node) -> void:
	_pending_capture = c
	_pending_player = player
	var can := MOUNTABLE.has(c.dna.species) and owned.size() < MAX_OWNED
	var reason := "só Trotador e Planador viram montaria" if not MOUNTABLE.has(c.dna.species) else "estábulo cheio: %d/%d" % [owned.size(), MAX_OWNED]
	_dialog.ask(c.dna, can, reason)

func _on_capture_choice(choice: StringName) -> void:
	var c := _pending_capture
	_pending_capture = null
	if c == null or not is_instance_valid(c):
		return
	match choice:
		&"abate":
			c.careful_slaughter()
			_say("🔪 Abate cuidadoso: segure [E] no corpo para esfolar as partes Íntegras")
		&"estabulo":
			if add_owned_mount(c.dna):
				_say("🐎 %s levado ao estábulo! (%d/%d)" % [c.dna.species_name(), owned.size(), MAX_OWNED])
			c.take_away()
		_:
			_say("🌿 Você soltou o %s" % c.dna.species_name())
			c.take_away()

## Bicho que sumiu só é reposto se a espécie ficou rara (o resto vem da reprodução)
func _on_removed(_c: WildCreature, species: CreatureDNA.Species, pos: Vector3, roam: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	if is_inside_tree() and population(species) < POP_MIN.get(species, 2):
		_add_wild(species, pos, roam)

func population(species: CreatureDNA.Species) -> int:
	var n := 0
	for c in get_tree().get_nodes_in_group("wild_creatures"):
		if c is WildCreature and c.dna.species == species and c.is_alive():
			n += 1
	return n

## Filhote de dois adultos (GDD-10 §5): DNA cruzado com mutação de 3%, nasce pequeno
func spawn_offspring(a: WildCreature, b: WildCreature) -> bool:
	if population(a.dna.species) >= POP_MAX.get(a.dna.species, 10):
		return false
	var c := _add_wild(a.dna.species, (a.global_position + b.global_position) * 0.5, a.roam_radius)
	c.dna = CreatureDNA.cross(a.dna, b.dna, _rng.randi())
	c.body.dna = c.dna
	c.body.build()
	c.age_days = 0.0
	c.hunger = 0.3
	c.thirst = 0.3
	c.breed_cooldown = WildCreature.BREED_COOLDOWN
	return true

# ---------------------------------------------------------------- save da natureza (GDD-10)

## Plantas e bichos vivos como estão agora (posição, DNA, idade, fome, sede)
func nature_state() -> Dictionary:
	var plants := []
	for n in get_tree().get_nodes_in_group("plants"):
		var p := n as PlantBody
		if p == null or p.is_queued_for_deletion():
			continue
		var pos := p.global_position
		plants.append({
			"dna": p.dna.to_dict(), "stage": p.stage, "age": snappedf(p.age, 0.01), "progress": snappedf(p.progress, 0.01),
			"stress": snappedf(p.stress, 0.01), "pos": [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)],
			"rot": snappedf(p.rotation.y, 0.01),
		})
	var wild := []
	for n in get_tree().get_nodes_in_group("wild_creatures"):
		var c := n as WildCreature
		if c == null or c.is_queued_for_deletion() or not c.is_alive() or c.state == WildCreature.State.CAPTURED:
			continue
		var pos := c.global_position
		wild.append({
			"dna": c.dna.to_dict(), "pos": [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)],
			"home": [snappedf(c.home.x, 0.01), snappedf(c.home.y, 0.01), snappedf(c.home.z, 0.01)], "roam": c.roam_radius,
			"age": snappedf(c.age_days, 0.01), "life": snappedf(c.lifespan_days, 0.01), "hunger": snappedf(c.hunger, 0.01),
			"thirst": snappedf(c.thirst, 0.01), "breed": snappedf(c.breed_cooldown, 0.01),
		})
	return {"plants": plants, "wild": wild}

## Troca a natureza do mundo pela do save
func restore_nature(d: Dictionary) -> void:
	for n in get_tree().get_nodes_in_group("plants"):
		n.remove_from_group("plants")
		n.queue_free()
	for n in get_tree().get_nodes_in_group("wild_creatures"):
		var c := n as WildCreature
		if c and c.state != WildCreature.State.CAPTURED:
			c.remove_from_group("wild_creatures")
			c.queue_free()
	for e in d.get("plants", []):
		var plant := PlantBody.new()
		plant.dna = PlantDNA.from_dict(e.get("dna", {}))
		plant.stage = int(e.get("stage", PlantBody.Stage.ADULTA)) as PlantBody.Stage
		plant.age = float(e.get("age", 0.0))
		plant.progress = float(e.get("progress", 0.0))
		plant.stress = float(e.get("stress", 0.0))
		plant.position = _vec(e.get("pos", [0, 0, 0]))
		plant.rotation.y = float(e.get("rot", 0.0))
		add_child(plant)
	for e in d.get("wild", []):
		var dna := CreatureDNA.from_dict(e.get("dna", {}))
		var c := _add_wild(dna.species, _vec(e.get("pos", [0, 0, 0])), float(e.get("roam", 14.0)), dna)
		c.home = _vec(e.get("home", e.get("pos", [0, 0, 0])))
		c.age_days = float(e.get("age", 4.0))
		c.lifespan_days = float(e.get("life", 15.0))
		c.hunger = float(e.get("hunger", 0.2))
		c.thirst = float(e.get("thirst", 0.2))
		c.breed_cooldown = float(e.get("breed", 0.0))

static func _vec(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

func _say(msg: String) -> void:
	if _pending_player and is_instance_valid(_pending_player) and _pending_player.has_signal("posture_changed"):
		_pending_player.posture_changed.emit(msg)

## Põe um bicho capturado no estábulo como montaria própria; false se cheio ou não montável
func add_owned_mount(d: CreatureDNA) -> bool:
	if owned.size() >= MAX_OWNED or not MOUNTABLE.has(d.species):
		return false
	owned.append(d)
	_spawn_owned(d, owned.size() - 1)
	return true

func _spawn_owned(d: CreatureDNA, slot: int) -> void:
	var m := _add_mount(d, MOUNTABLE[d.species], "Seu " + d.species_name().get_slice("-", 0), _stable_base + Vector3(-3.0 + slot * 3.0, 0, 4.0))
	m.owned = true
	_owned_nodes.append(m)

func owned_state() -> Array:
	return owned.map(func(d): return d.to_dict())

func restore_owned(list: Array) -> void:
	for m in _owned_nodes:
		if is_instance_valid(m):
			if m.rider:
				m.dismount()
			m.queue_free()
	_owned_nodes.clear()
	owned.clear()
	for e in list:
		if e is Dictionary and owned.size() < MAX_OWNED:
			add_owned_mount(CreatureDNA.from_dict(e))

# ---------------------------------------------------------------- estábulo e montarias

func _build_stable() -> void:
	var stable := Node3D.new()
	stable.name = "Estabulo"
	var base := Vector3(STABLE_POS.x, _ground(STABLE_POS.x, STABLE_POS.y), STABLE_POS.y)
	_stable_base = base
	stable.position = base
	add_child(stable)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.4, 0.27, 0.15)
	# Telheiro: 4 postes e cobertura de tábuas
	for x in [-3.0, 3.0]:
		for z in [-2.0, 2.0]:
			_box(stable, Vector3(0.18, 2.8, 0.18), Vector3(x, 1.4, z), wood)
	_box(stable, Vector3(6.8, 0.15, 4.8), Vector3(0, 2.85, 0), wood).rotation.x = 0.12
	_box(stable, Vector3(6.4, 0.12, 0.12), Vector3(0, 1.0, -2.0), wood)
	var sign_label := Label3D.new()
	sign_label.text = "🐎 Estábulo"
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.font_size = 22
	sign_label.outline_size = 6
	sign_label.modulate = Color(1.0, 0.9, 0.6)
	sign_label.position = Vector3(0, 3.6, 0)
	sign_label.visibility_range_end = 28.0
	stable.add_child(sign_label)

	var trot := CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 101)
	trot.alleles["porte"] = ["T", "T"]
	trot.alleles["chifre"] = ["C", "c"]
	_add_mount(trot, Mount.Kind.LAND, "Trotador", base + Vector3(-1.5, 0, 0.3))
	var bird := CreatureDNA.randomized(CreatureDNA.Species.PLANADOR, 202)
	bird.alleles["porte"] = ["T", "T"]
	bird.alleles["chifre"] = ["C", "C"]
	_add_mount(bird, Mount.Kind.AIR, "Planador", base + Vector3(1.7, 0, 0.3))
	# Raia montável no rio, na altura da vila
	var raia := CreatureDNA.randomized(CreatureDNA.Species.RAIA, 303)
	raia.alleles["porte"] = ["T", "T"]
	_add_mount(raia, Mount.Kind.WATER, "Raia-do-Rio", _river_spot(10.0))

func _add_mount(d: CreatureDNA, kind: Mount.Kind, mount_name: String, pos: Vector3) -> Mount:
	var m := Mount.new()
	m.name = "Montaria_" + mount_name
	m.dna = d
	m.kind = kind
	m.display_name = mount_name
	m.position = pos
	m.rotation.y = PI * 0.5
	add_child(m)
	return m

# ---------------------------------------------------------------- lugares

## Ponto em terra firme a uma distância [min, max] da origem; Vector3.INF se não achar
func _land_spot(min_dist: float, max_dist: float) -> Vector3:
	for attempt in 12:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(min_dist, max_dist)
		var x := cos(a) * d
		var z := sin(a) * d
		if CityHub.in_village(x, z, 2.0) or Vector2(x, z).distance_to(ARENA_CENTER) < 11.0 or Vector2(x, z).distance_to(STABLE_POS) < 5.0:
			continue
		if RiverSystem.get_distance_to_river(x, z) < RiverSystem.get_water_half_width(z) + 2.0:
			continue
		if not WorldBounds.inside(x, z, 6.0):
			continue
		return Vector3(x, _ground(x, z), z)
	return Vector3.INF

func _river_spot(z: float) -> Vector3:
	return Vector3(RiverSystem.get_river_center_x(z), RiverSystem.get_water_height(z) - 0.3, z)

func _ground(x: float, z: float) -> float:
	return landscape.get_height_at(x, z) if landscape and landscape.has_method("get_height_at") else 0.0

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi
