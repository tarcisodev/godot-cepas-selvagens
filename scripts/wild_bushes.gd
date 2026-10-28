extends Node3D
class_name WildBushes

## Arbustos de Frutos Silvestres (Amoras e Bagas da Serra)
# Arbustos viçosos pontilhados de frutinhas vermelhas e roxas suculentas,
# convidando a olhar de perto e saborear.

const RiverClass = preload("res://scripts/river_system.gd")

@export var landscape: MeshInstance3D
@export var bush_count: int = 50
@export var spawn_radius: float = WorldBounds.HALF * 0.8

func _ready() -> void:
	if landscape == null:
		landscape = get_parent().get_node_or_null("Landscape")

	_spawn_berry_bushes()

func _get_ground_y(x: float, z: float) -> float:
	if landscape and landscape.has_method("get_height_at"):
		return landscape.get_height_at(x, z)
	return 0.0

func _spawn_berry_bushes() -> void:
	var leaves_mat: StandardMaterial3D = StandardMaterial3D.new()
	leaves_mat.albedo_color = Color(0.20, 0.42, 0.22)
	leaves_mat.roughness = 0.85

	var berry_mat: StandardMaterial3D = StandardMaterial3D.new()
	berry_mat.albedo_color = Color(0.88, 0.18, 0.22) # Frutinhas vermelhas rubi
	berry_mat.roughness = 0.2
	berry_mat.metallic_specular = 0.5

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 555

	for i in range(bush_count):
		var x: float = rng.randf_range(-spawn_radius, spawn_radius)
		var z: float = rng.randf_range(-spawn_radius, spawn_radius)

		var dist_river: float = RiverClass.get_distance_to_river(x, z)
		var water_hw: float = RiverClass.get_water_half_width(z)
		if dist_river < (water_hw + 1.5) or CityHub.in_village(x, z) or RiverClass.is_in_sea(x, z) or RiverClass.is_in_lake(x, z):
			continue

		var ground_y: float = _get_ground_y(x, z)
		if ground_y > 12.0:
			continue

		var bush_root: Node3D = Node3D.new()
		bush_root.name = "BerryBush_%d" % i
		bush_root.position = Vector3(x, ground_y, z)

		var s: float = rng.randf_range(0.8, 1.3)

		# Folhagem do arbusto (3 esferas aglutinadas)
		for b in range(3):
			var a: float = (b / 3.0) * TAU
			var foliage: MeshInstance3D = MeshInstance3D.new()
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = 0.45 * s
			sphere.height = 0.65 * s
			foliage.mesh = sphere
			foliage.material_override = leaves_mat
			foliage.position = Vector3(cos(a) * 0.25 * s, 0.35 * s, sin(a) * 0.25 * s)
			bush_root.add_child(foliage)

		# Frutinhas vermelhas penduradas nas folhas
		for berry_idx in range(6):
			var ba: float = rng.randf_range(0.0, TAU)
			var br: float = rng.randf_range(0.35, 0.55) * s
			var by: float = rng.randf_range(0.25, 0.6) * s

			var berry: MeshInstance3D = MeshInstance3D.new()
			var berry_sphere: SphereMesh = SphereMesh.new()
			berry_sphere.radius = 0.055 * s
			berry_sphere.height = 0.09 * s
			berry.mesh = berry_sphere
			berry.material_override = berry_mat
			berry.position = Vector3(cos(ba) * br, by, sin(ba) * br)
			bush_root.add_child(berry)

		add_child(bush_root)
