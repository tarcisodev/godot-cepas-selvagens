class_name EcosystemSpawner
extends Node3D

## Povoa o vale com fauna e flora procedurais (GDD-09 §4): rebanhos de Trotador, Saltarelos,
## Planadores no céu, Raias e cardumes de Lambari no rio, e árvores, arbustos, Cepas Selvagens e
## cogumelos-lume. Nada nasce na vila, na água nem na arena. Também monta o Estábulo com as
## montarias de teste (Trotador e Planador) e põe a Raia montável no rio perto da vila.

const ARENA_CENTER: Vector2 = Vector2(-27.0, 3.0)
const STABLE_POS: Vector2 = Vector2(-15.0, -5.0)

@export var landscape: Node3D
@export var world_seed: int = 2026

@export_group("Quantidades")
@export var trotador_herds: int = 4
@export var saltarelos: int = 8
@export var planadores: int = 3
@export var raias: int = 2
@export var lambari_schools: int = 3
@export var trees: int = 35
@export var bushes: int = 35
@export var cepas: int = 30
@export var mushrooms: int = 20

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	if landscape == null:
		landscape = get_parent().get_node_or_null("Landscape")
	_rng.seed = world_seed
	_spawn_plants()
	_spawn_fauna()
	_build_stable()

# ---------------------------------------------------------------- flora

func _spawn_plants() -> void:
	var plan := [[PlantDNA.Kind.ARVORE, trees, 16.0], [PlantDNA.Kind.ARBUSTO, bushes, 15.0], [PlantDNA.Kind.CEPA, cepas, 15.0], [PlantDNA.Kind.COGUMELO, mushrooms, 15.0]]
	for p in plan:
		for i in p[1]:
			var spot := _land_spot(p[2], 80.0)
			if spot == Vector3.INF:
				continue
			var plant := PlantBody.new()
			plant.dna = PlantDNA.randomized(p[0], _rng.randi())
			plant.position = spot
			plant.rotation.y = _rng.randf() * TAU
			add_child(plant)

# ---------------------------------------------------------------- fauna

func _spawn_fauna() -> void:
	for h in trotador_herds:
		var center := _land_spot(25.0, 70.0)
		if center == Vector3.INF:
			continue
		for i in _rng.randi_range(3, 4):
			_add_wild(CreatureDNA.Species.TROTADOR, center + Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-3, 3)), 14.0)
	for i in saltarelos:
		var spot := _land_spot(16.0, 70.0)
		if spot != Vector3.INF:
			_add_wild(CreatureDNA.Species.SALTARELO, spot, 8.0)
	for i in planadores:
		var spot := _land_spot(20.0, 50.0)
		if spot != Vector3.INF:
			_add_wild(CreatureDNA.Species.PLANADOR, spot + Vector3(0, 15, 0), 16.0)
	for i in raias:
		_add_wild(CreatureDNA.Species.RAIA, _river_spot(_rng.randf_range(15.0, 55.0)), 14.0)
	for s in lambari_schools:
		var z := _rng.randf_range(-12.0, 60.0)
		for i in 4:
			_add_wild(CreatureDNA.Species.LAMBARI, _river_spot(z + i * 0.6), 10.0)

func _add_wild(species: CreatureDNA.Species, pos: Vector3, roam: float) -> void:
	var c := WildCreature.new()
	c.dna = CreatureDNA.randomized(species, _rng.randi())
	c.roam_radius = roam
	c.position = pos
	add_child(c)

# ---------------------------------------------------------------- estábulo e montarias

func _build_stable() -> void:
	var stable := Node3D.new()
	stable.name = "Estabulo"
	var base := Vector3(STABLE_POS.x, _ground(STABLE_POS.x, STABLE_POS.y), STABLE_POS.y)
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
		if absf(x) > 85.0 or absf(z) > 85.0:
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
