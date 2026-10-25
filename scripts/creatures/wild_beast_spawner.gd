class_name WildBeastSpawner
extends Node3D

## Bichos que lutam no mapa (GDD-12 §12): 3 tocas de Lobo-do-Ermo com 3 lobos cada, nas bordas do
## vale, e um Tatu-Espinho guardando cada grupo de veios de ferro (até 8). Precisa vir depois do
## GatherableSpawner na cena, que cria os veios no _ready dele.

@export var landscape: Node3D
@export var dens: int = 3
@export var wolves_per_den: int = 3
@export var max_armadillos: int = 8

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 20261025
	_spawn_dens()
	_spawn_armadillos()

func _ground_y(x: float, z: float) -> float:
	if landscape and landscape.has_method("get_height_at"):
		return landscape.get_height_at(x, z)
	return 0.0

func _spawn_beast(cfg: Dictionary, at: Vector3, label: String) -> BeastFighter:
	var b := BeastFighter.new()
	b.name = label
	b.config = cfg
	add_child(b)
	b.global_position = Vector3(at.x, _ground_y(at.x, at.z) + 0.2, at.z)
	b.home = b.global_position
	b.rotation.y = _rng.randf() * TAU
	return b

## Tocas espalhadas em ângulos diferentes, longe da vila, do rio e da Clareira do Ancião
func _spawn_dens() -> void:
	var made := 0
	var tries := 0
	while made < dens and tries < 200:
		tries += 1
		var a := TAU * (float(made) + _rng.randf_range(0.1, 0.9)) / float(dens)
		var r := WorldBounds.HALF * _rng.randf_range(0.5, 0.8)
		var c := Vector3(cos(a) * r, 0, sin(a) * r)
		if not _ok_spot(c.x, c.z, 40.0):
			continue
		_den_marker(c)
		for j in wolves_per_den:
			var cfg := BeastFighter.lobo_do_ermo()
			cfg.seed = 3101 + made * 10 + j
			var off := Vector3(cos(j * 2.1), 0, sin(j * 2.1)) * 2.2
			var w := _spawn_beast(cfg, c + off, "Lobo_%d_%d" % [made, j])
			w.pack_id = "toca_%d" % made
			w.pack_slot = j
		made += 1

## Um tatu por grupo de veios de ferro (grupos a mais de 10 m um do outro)
func _spawn_armadillos() -> void:
	var centers: Array[Vector3] = []
	for v in get_tree().get_nodes_in_group("ore_veins"):
		if not (v is GatherableResource) or (v as GatherableResource).type != GatherableResource.Type.VEIO_FERRO:
			continue
		var p := (v as Node3D).global_position
		if centers.any(func(c): return c.distance_to(p) < 10.0):
			continue
		centers.append(p)
		if centers.size() >= max_armadillos:
			break
	for i in centers.size():
		var cfg := BeastFighter.tatu_espinho()
		cfg.seed = 4201 + i
		var a := _rng.randf() * TAU
		_spawn_beast(cfg, centers[i] + Vector3(cos(a), 0, sin(a)) * 3.5, "Tatu_%d" % i)

func _ok_spot(x: float, z: float, village_margin: float) -> bool:
	if not WorldBounds.inside(x, z, 12.0) or CityHub.in_village(x, z, village_margin):
		return false
	if RiverSystem.get_distance_to_river(x, z) < RiverSystem.get_water_half_width(z) + 10.0:
		return false
	for lair in get_tree().get_nodes_in_group("boss"):
		if Vector2(x - lair.global_position.x, z - lair.global_position.z).length() < 45.0:
			return false
	return true

## Toca: pedras em meia-lua e ossos espalhados, para o jogador reconhecer de longe
func _den_marker(c: Vector3) -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.33, 0.31, 0.3)
	stone.roughness = 0.95
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color(0.9, 0.87, 0.78)
	for i in 6:
		var a := PI * 0.2 + float(i) / 5.0 * PI * 1.1
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.7
		sm.height = 1.0
		sm.radial_segments = 7
		sm.rings = 4
		m.mesh = sm
		m.material_override = stone
		m.scale = Vector3(1.2, 0.8 + 0.1 * (i % 3), 1.0)
		add_child(m)
		var x := c.x + cos(a) * 4.2
		var z := c.z + sin(a) * 4.2
		m.global_position = Vector3(x, _ground_y(x, z) + 0.2, z)
	for i in 4:
		var b := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.035
		cyl.bottom_radius = 0.035
		cyl.height = 0.5
		b.mesh = cyl
		b.material_override = bone
		add_child(b)
		var x := c.x + _rng.randf_range(-2.0, 2.0)
		var z := c.z + _rng.randf_range(-2.0, 2.0)
		b.global_position = Vector3(x, _ground_y(x, z) + 0.05, z)
		b.rotation = Vector3(PI * 0.5, _rng.randf() * TAU, 0)
