extends Node3D
class_name NatureProps

## Ecologia da Vegetação, Mata Ciliar e Cogumelos
# Ajusta a altura de cada árvore, rocha e cogumelo à elevação real do relevo,
# garantindo que fiquem 100% ancorados no chão.

const RiverClass = preload("res://scripts/river_system.gd")

@export var landscape: MeshInstance3D
@export var riparian_tree_count: int = 42
@export var hill_tree_count: int = 24
@export var rock_count: int = 34
@export var mushroom_cluster_count: int = 26

var spawned_tree_positions: Array[Vector3] = []

func _ready() -> void:
	# Se a referência ao landscape não tiver sido associada no inspector, busca no pai
	if landscape == null:
		landscape = get_parent().get_node_or_null("Landscape")

	_spawn_resting_camp()
	_spawn_trees()
	_spawn_mushrooms()
	_spawn_rocks()

func _get_ground_y(x: float, z: float) -> float:
	if landscape:
		return landscape.get_height_at(x, z)
	return 0.0

func _spawn_resting_camp() -> void:
	var camp_x: float = 4.0
	var camp_z: float = -4.0
	var ground_y: float = _get_ground_y(camp_x, camp_z)

	var camp: Node3D = Node3D.new()
	camp.name = "Campfire"
	camp.position = Vector3(camp_x, ground_y + 0.05, camp_z)

	# Fogueira em círculo de pedras
	for i in range(7):
		var angle: float = (i / 7.0) * TAU
		var rock_mesh: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.22
		sphere.height = 0.35
		rock_mesh.mesh = sphere

		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.33, 0.31)
		rock_mesh.material_override = mat
		rock_mesh.position = Vector3(cos(angle) * 0.7, 0.1, sin(angle) * 0.7)
		camp.add_child(rock_mesh)

	# Tronco de banco para contemplar a cachoeira ao fundo
	var log_mesh: MeshInstance3D = MeshInstance3D.new()
	var log_cyl: CylinderMesh = CylinderMesh.new()
	log_cyl.top_radius = 0.25
	log_cyl.bottom_radius = 0.28
	log_cyl.height = 1.8
	log_mesh.mesh = log_cyl
	var log_mat: StandardMaterial3D = StandardMaterial3D.new()
	log_mat.albedo_color = Color(0.36, 0.24, 0.16)
	log_mesh.material_override = log_mat
	log_mesh.rotation.z = deg_to_rad(90.0)
	log_mesh.position = Vector3(0, 0.2, 1.4)
	camp.add_child(log_mesh)

	# Luz da fogueira
	var fire_light: OmniLight3D = OmniLight3D.new()
	fire_light.light_color = Color(1.0, 0.62, 0.3)
	fire_light.light_energy = 1.2
	fire_light.omni_range = 8.0
	fire_light.position = Vector3(0, 0.5, 0)
	camp.add_child(fire_light)

	add_child(camp)

func _spawn_trees() -> void:
	var trunk_mat: StandardMaterial3D = StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.30, 0.20, 0.14)

	var riparian_leaves_mat: StandardMaterial3D = StandardMaterial3D.new()
	riparian_leaves_mat.albedo_color = Color(0.18, 0.44, 0.22) # Verde viçoso da mata ciliar
	riparian_leaves_mat.roughness = 0.85

	var hill_leaves_mat: StandardMaterial3D = StandardMaterial3D.new()
	hill_leaves_mat.albedo_color = Color(0.32, 0.40, 0.24)     # Verde oliva de altitude
	hill_leaves_mat.roughness = 0.9

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 101

	# 1. Mata Ciliar (acompanhando o rio e a lagoa da cachoeira)
	for i in range(riparian_tree_count):
		var z: float = rng.randf_range(-70.0, 70.0)
		# Evitar penhasco vertical da cachoeira
		if z >= (RiverClass.WATERFALL_Z - 2.0) and z <= (RiverClass.WATERFALL_Z + 4.0):
			continue

		var rx: float = RiverClass.get_river_center_x(z)
		var hw: float = RiverClass.get_water_half_width(z)
		var side: float = 1.0 if rng.randf() > 0.5 else -1.0
		var dist: float = rng.randf_range(hw + 1.2, hw + 14.0)
		var x: float = rx + (side * dist)

		if Vector2(x, z).length() < 7.0:
			continue

		var ground_y: float = _get_ground_y(x, z)
		var tree_pos: Vector3 = Vector3(x, ground_y, z)
		spawned_tree_positions.append(tree_pos)
		_build_tree(tree_pos, 1.15, trunk_mat, riparian_leaves_mat, rng)

	# 2. Árvores de Colina e Encostas
	for i in range(hill_tree_count):
		var x: float = rng.randf_range(-70.0, 70.0)
		var z: float = rng.randf_range(-70.0, 70.0)

		# Evitar leito d'água, acampamento e topo rochoso pelado
		var dist_river: float = RiverClass.get_distance_to_river(x, z)
		if dist_river < 15.0 or Vector2(x, z).length() < 9.0:
			continue

		var ground_y: float = _get_ground_y(x, z)
		if ground_y > 15.0: # Topo rochoso do pico é rocha nua
			continue

		var tree_pos: Vector3 = Vector3(x, ground_y, z)
		spawned_tree_positions.append(tree_pos)
		_build_tree(tree_pos, 0.95, trunk_mat, hill_leaves_mat, rng)

func _build_tree(pos: Vector3, scale_mult: float, trunk_mat: Material, leaves_mat: Material, rng: RandomNumberGenerator) -> void:
	var tree: Node3D = Node3D.new()
	tree.position = pos
	var s: float = rng.randf_range(0.85, 1.25) * scale_mult

	# Tronco enraizado no chão
	var trunk: MeshInstance3D = MeshInstance3D.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 0.22 * s
	cylinder.bottom_radius = 0.38 * s
	cylinder.height = 2.4 * s
	trunk.mesh = cylinder
	trunk.material_override = trunk_mat
	trunk.position.y = (cylinder.height * 0.5)
	tree.add_child(trunk)

	# Copas em camadas
	var heights: Array[float] = [2.2 * s, 3.2 * s, 4.1 * s]
	var radii: Array[float] = [1.6 * s, 1.2 * s, 0.8 * s]
	for level in range(3):
		var foliage: MeshInstance3D = MeshInstance3D.new()
		var cone: CylinderMesh = CylinderMesh.new()
		cone.top_radius = 0.05
		cone.bottom_radius = radii[level]
		cone.height = 1.4 * s
		foliage.mesh = cone
		foliage.material_override = leaves_mat
		foliage.position.y = heights[level]
		tree.add_child(foliage)

	# Colisão no tronco
	var static_body: StaticBody3D = StaticBody3D.new()
	var col: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.35 * s
	cap.height = cylinder.height
	col.shape = cap
	col.position.y = cylinder.height * 0.5
	static_body.add_child(col)
	tree.add_child(static_body)

	add_child(tree)

func _spawn_mushrooms() -> void:
	var stem_mat: StandardMaterial3D = StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.88, 0.84, 0.76)
	stem_mat.roughness = 0.7

	var ochre_mat: StandardMaterial3D = StandardMaterial3D.new()
	ochre_mat.albedo_color = Color(0.62, 0.44, 0.24)

	var crimson_mat: StandardMaterial3D = StandardMaterial3D.new()
	crimson_mat.albedo_color = Color(0.75, 0.22, 0.18)

	var bio_mat: StandardMaterial3D = StandardMaterial3D.new()
	bio_mat.albedo_color = Color(0.25, 0.75, 0.70)
	bio_mat.emission_enabled = true
	bio_mat.emission = Color(0.20, 0.80, 0.72)
	bio_mat.emission_energy_multiplier = 0.8

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 202

	# 1. Cogumelos na base das árvores (altura exata do chão)
	for tree_pos in spawned_tree_positions:
		if rng.randf() < 0.65:
			var cluster_size: int = rng.randi_range(2, 5)
			var chosen_mat: Material = crimson_mat if rng.randf() > 0.6 else ochre_mat
			if rng.randf() < 0.28:
				chosen_mat = bio_mat

			for m in range(cluster_size):
				var angle: float = rng.randf_range(0.0, TAU)
				var dist: float = rng.randf_range(0.45, 1.2)
				var mx: float = tree_pos.x + cos(angle) * dist
				var mz: float = tree_pos.z + sin(angle) * dist
				var my: float = _get_ground_y(mx, mz)
				_build_single_mushroom(Vector3(mx, my, mz), stem_mat, chosen_mat, rng)

	# 2. Cogumelos nas margens da lagoa e do rio
	for i in range(mushroom_cluster_count):
		var z: float = rng.randf_range(-65.0, 65.0)
		if z >= (RiverClass.WATERFALL_Z - 2.0) and z <= (RiverClass.WATERFALL_Z + 2.0):
			continue

		var rx: float = RiverClass.get_river_center_x(z)
		var hw: float = RiverClass.get_water_half_width(z)
		var side: float = 1.0 if rng.randf() > 0.5 else -1.0
		var mx: float = rx + side * rng.randf_range(hw + 0.6, hw + 2.8)

		var chosen_mat: Material = bio_mat if rng.randf() > 0.5 else ochre_mat
		var cluster_size: int = rng.randi_range(3, 6)

		for m in range(cluster_size):
			var cmx: float = mx + rng.randf_range(-0.4, 0.4)
			var cmz: float = z + rng.randf_range(-0.4, 0.4)
			var cmy: float = _get_ground_y(cmx, cmz)
			_build_single_mushroom(Vector3(cmx, cmy, cmz), stem_mat, chosen_mat, rng)

func _build_single_mushroom(pos: Vector3, stem_mat: Material, cap_mat: Material, rng: RandomNumberGenerator) -> void:
	var shroom: Node3D = Node3D.new()
	shroom.position = pos
	var s: float = rng.randf_range(0.65, 1.25)

	# Haste
	var stem: MeshInstance3D = MeshInstance3D.new()
	var stem_mesh: CylinderMesh = CylinderMesh.new()
	stem_mesh.top_radius = 0.035 * s
	stem_mesh.bottom_radius = 0.05 * s
	stem_mesh.height = 0.25 * s
	stem.mesh = stem_mesh
	stem.material_override = stem_mat
	stem.position.y = (stem_mesh.height * 0.5)
	stem.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(0.0, TAU), rng.randf_range(-0.15, 0.15))
	shroom.add_child(stem)

	# Chapéu
	var cap: MeshInstance3D = MeshInstance3D.new()
	var cap_mesh: SphereMesh = SphereMesh.new()
	cap_mesh.radius = 0.13 * s
	cap_mesh.height = 0.16 * s
	cap.mesh = cap_mesh
	cap.material_override = cap_mat
	cap.position.y = (0.24 * s)
	shroom.add_child(cap)

	add_child(shroom)

func _spawn_rocks() -> void:
	var rock_mat: StandardMaterial3D = StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.42, 0.40, 0.38)
	rock_mat.roughness = 0.95

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99

	for i in range(rock_count):
		var x: float = rng.randf_range(-70.0, 70.0)
		var z: float = rng.randf_range(-70.0, 70.0)

		# Evita dentro d'água funda ou no acampamento
		var dist_river: float = RiverClass.get_distance_to_river(x, z)
		if dist_river < 3.5 or Vector2(x, z).length() < 6.0:
			continue

		var ground_y: float = _get_ground_y(x, z)
		var s: float = rng.randf_range(0.6, 2.2)

		var rock: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = s * 0.5
		sphere.height = s * 0.8
		rock.mesh = sphere
		rock.material_override = rock_mat
		rock.position = Vector3(x, ground_y + s * 0.22, z)
		rock.rotation = Vector3(rng.randf(), rng.randf(), rng.randf())

		var static_body: StaticBody3D = StaticBody3D.new()
		var col: CollisionShape3D = CollisionShape3D.new()
		var sphere_shape: SphereShape3D = SphereShape3D.new()
		sphere_shape.radius = s * 0.45
		col.shape = sphere_shape
		static_body.add_child(col)
		rock.add_child(static_body)

		add_child(rock)
