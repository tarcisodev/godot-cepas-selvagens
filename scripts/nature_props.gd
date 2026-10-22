extends Node3D
class_name NatureProps

## Ecologia da Vegetação, Mata Ciliar e Acampamento
## Substituído por modelos estilizados 3D reais (Stylized Nature & KayKit Tools).

const RiverClass = preload("res://scripts/river_system.gd")

@export var landscape: MeshInstance3D
@export var riparian_tree_count: int = 38
@export var hill_tree_count: int = 24
@export var bush_count: int = 36
@export var rock_count: int = 30
@export var mushroom_cluster_count: int = 22

# Cenas dos modelos 3D Stylized Nature
const TREE_SCENES: Array = [
	preload("res://assets/models/nature/CommonTree_1.gltf"),
	preload("res://assets/models/nature/CommonTree_2.gltf"),
	preload("res://assets/models/nature/CommonTree_3.gltf"),
	preload("res://assets/models/nature/CommonTree_4.gltf"),
	preload("res://assets/models/nature/CommonTree_5.gltf"),
]

const DEAD_TREE_SCENES: Array = [
	preload("res://assets/models/nature/DeadTree_1.gltf"),
	preload("res://assets/models/nature/DeadTree_2.gltf"),
	preload("res://assets/models/nature/DeadTree_3.gltf"),
	preload("res://assets/models/nature/DeadTree_4.gltf"),
]

const BUSH_SCENES: Array = [
	preload("res://assets/models/nature/Bush_Common.gltf"),
	preload("res://assets/models/nature/Bush_Common_Flowers.gltf"),
]

const ROCK_SCENES: Array = [
	preload("res://assets/models/nature/Rock_Medium_1.gltf"),
	preload("res://assets/models/nature/Rock_Medium_2.gltf"),
	preload("res://assets/models/nature/Rock_Medium_3.gltf"),
]

const SHROOM_SCENES: Array = [
	preload("res://assets/models/nature/Mushroom_Common.gltf"),
	preload("res://assets/models/nature/Mushroom_Laetiporus.gltf"),
]

# Ferramentas e itens do acampamento (KayKit RPG Tools & Fantasy Props)
const ANVIL_SCENE = preload("res://assets/models/tools/anvil.gltf")
const GRINDSTONE_SCENE = preload("res://assets/models/tools/grindstone.gltf")
const LANTERN_SCENE = preload("res://assets/models/tools/lantern.gltf")
const BLUEPRINT_SCENE = preload("res://assets/models/tools/blueprint_stacked.gltf")
const WORKBENCH_SCENE = preload("res://assets/models/props/fantasy/Workbench.gltf")
const CHEST_SCENE = preload("res://assets/models/props/fantasy/Chest_Wood.gltf")
const CAULDRON_SCENE = preload("res://assets/models/props/fantasy/Cauldron.gltf")
const CRATE_SCENE = preload("res://assets/models/props/fantasy/Crate_Wooden.gltf")
const BARREL_SCENE = preload("res://assets/models/props/fantasy/Barrel.gltf")

var spawned_tree_positions: Array[Vector3] = []

func _ready() -> void:
	if landscape == null:
		landscape = get_parent().get_node_or_null("Landscape")

	_spawn_resting_camp()
	_spawn_trees()
	_spawn_bushes()
	_spawn_mushrooms()
	_spawn_rocks()

func _get_ground_y(x: float, z: float) -> float:
	if landscape and landscape.has_method("get_height_at"):
		return landscape.get_height_at(x, z)
	return 0.0

func _spawn_resting_camp() -> void:
	# Fica a alguns passos do spawn, longe da besta de treino e antes da margem do rio
	var camp_x: float = 3.5
	var camp_z: float = 4.0
	var ground_y: float = _get_ground_y(camp_x, camp_z)

	var camp: Node3D = Node3D.new()
	camp.name = "Campground"
	camp.position = Vector3(camp_x, ground_y, camp_z)

	# Escalas trazem os kits (KayKit vem grande) para tamanho humano.
	# Canto da forja (à direita de quem chega do spawn)
	var anvil: Node3D = ANVIL_SCENE.instantiate()
	anvil.position = Vector3(1.0, 0.0, 0.6)
	anvil.scale = Vector3.ONE * 0.5
	anvil.rotation.y = deg_to_rad(20.0)
	camp.add_child(anvil)

	var grind: Node3D = GRINDSTONE_SCENE.instantiate()
	grind.position = Vector3(2.1, 0.0, -0.5)
	grind.rotation.y = deg_to_rad(-45.0)
	grind.scale = Vector3.ONE * 0.48
	camp.add_child(grind)

	# Lanterna iluminando o acampamento
	var lantern: Node3D = LANTERN_SCENE.instantiate()
	lantern.position = Vector3(0.1, 0.0, 1.6)
	lantern.scale = Vector3.ONE * 0.4
	camp.add_child(lantern)

	var lantern_light: OmniLight3D = OmniLight3D.new()
	lantern_light.light_color = Color(1.0, 0.72, 0.42)
	lantern_light.light_energy = 1.4
	lantern_light.omni_range = 7.0
	lantern_light.position = Vector3(0.1, 0.45, 1.6)
	camp.add_child(lantern_light)

	# Bancada rústica de botânica / alquimia, com os projetos de forja em cima
	var bench: Node3D = WORKBENCH_SCENE.instantiate()
	bench.position = Vector3(-1.3, 0.0, 0.2)
	bench.rotation.y = deg_to_rad(65.0)
	bench.scale = Vector3.ONE * 0.8
	camp.add_child(bench)

	var bp: Node3D = BLUEPRINT_SCENE.instantiate()
	bp.position = Vector3(-1.3, 0.72, 0.2)
	bp.rotation.y = deg_to_rad(65.0)
	bp.scale = Vector3.ONE * 0.3
	camp.add_child(bp)

	# Caldeirão de extratos e infusões
	var cauldron: Node3D = CAULDRON_SCENE.instantiate()
	cauldron.position = Vector3(-0.4, 0.0, -1.5)
	cauldron.scale = Vector3.ONE * 0.85
	camp.add_child(cauldron)

	# Baú de madeira para sementes e materiais coletados
	var chest: Node3D = CHEST_SCENE.instantiate()
	chest.position = Vector3(-2.5, 0.0, -1.0)
	chest.rotation.y = deg_to_rad(25.0)
	chest.scale = Vector3.ONE * 0.7
	camp.add_child(chest)

	# Caixote e barril de suprimentos
	var crate: Node3D = CRATE_SCENE.instantiate()
	crate.position = Vector3(2.7, 0.0, 1.4)
	crate.rotation.y = deg_to_rad(-15.0)
	crate.scale = Vector3.ONE * 0.75
	camp.add_child(crate)

	var barrel: Node3D = BARREL_SCENE.instantiate()
	barrel.position = Vector3(3.3, 0.0, 0.7)
	camp.add_child(barrel)

	add_child(camp)

func _spawn_trees() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 101

	# 1. Mata Ciliar (árvores frondosas acompanhando o rio)
	for i in range(riparian_tree_count):
		var z: float = rng.randf_range(-70.0, 70.0)
		if z >= (RiverClass.WATERFALL_Z - 2.0) and z <= (RiverClass.WATERFALL_Z + 4.0):
			continue

		var rx: float = RiverClass.get_river_center_x(z)
		var hw: float = RiverClass.get_water_half_width(z)
		var side: float = 1.0 if rng.randf() > 0.5 else -1.0
		var dist: float = rng.randf_range(hw + 1.5, hw + 15.0)
		var x: float = rx + (side * dist)

		if CityHub.in_village(x, z):
			continue

		var ground_y: float = _get_ground_y(x, z)
		var tree_pos: Vector3 = Vector3(x, ground_y, z)
		spawned_tree_positions.append(tree_pos)
		_build_tree(tree_pos, 1.1, TREE_SCENES, rng)

	# 2. Árvores de Colina e Encostas (árvores retorcidas e secas no planalto)
	for i in range(hill_tree_count):
		var x: float = rng.randf_range(-70.0, 70.0)
		var z: float = rng.randf_range(-70.0, 70.0)

		var dist_river: float = RiverClass.get_distance_to_river(x, z)
		if dist_river < 15.0 or CityHub.in_village(x, z):
			continue

		var ground_y: float = _get_ground_y(x, z)
		if ground_y > 15.0:
			continue

		var tree_pos: Vector3 = Vector3(x, ground_y, z)
		spawned_tree_positions.append(tree_pos)
		var chosen_scenes: Array = DEAD_TREE_SCENES if rng.randf() > 0.4 else TREE_SCENES
		_build_tree(tree_pos, 0.95, chosen_scenes, rng)

func _build_tree(pos: Vector3, scale_mult: float, scenes: Array, rng: RandomNumberGenerator) -> void:
	if scenes.is_empty():
		return
	var scene: PackedScene = scenes[rng.randi() % scenes.size()]
	var tree_node: Node3D = scene.instantiate()
	tree_node.position = pos
	var s: float = rng.randf_range(0.85, 1.35) * scale_mult
	tree_node.scale = Vector3(s, s, s)
	tree_node.rotation.y = rng.randf_range(0.0, TAU)

	# Colisão no tronco
	var static_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4 * s
	cap.height = 3.2 * s
	col.shape = cap
	col.position.y = cap.height * 0.5
	static_body.add_child(col)
	tree_node.add_child(static_body)

	add_child(tree_node)

func _spawn_bushes() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 303
	for i in range(bush_count):
		var x: float = rng.randf_range(-65.0, 65.0)
		var z: float = rng.randf_range(-65.0, 65.0)
		if CityHub.in_village(x, z) or RiverClass.get_distance_to_river(x, z) < 4.0:
			continue
		var ground_y: float = _get_ground_y(x, z)
		if ground_y > 14.0:
			continue
		var scene: PackedScene = BUSH_SCENES[rng.randi() % BUSH_SCENES.size()]
		var bush: Node3D = scene.instantiate()
		var s: float = rng.randf_range(0.85, 1.4)
		bush.position = Vector3(x, ground_y, z)
		bush.scale = Vector3(s, s, s)
		bush.rotation.y = rng.randf_range(0.0, TAU)
		add_child(bush)

func _spawn_mushrooms() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 202

	for tree_pos in spawned_tree_positions:
		if rng.randf() < 0.65:
			var scene: PackedScene = SHROOM_SCENES[rng.randi() % SHROOM_SCENES.size()]
			var shroom: Node3D = scene.instantiate()
			var angle: float = rng.randf_range(0.0, TAU)
			var dist: float = rng.randf_range(0.5, 1.3)
			var mx: float = tree_pos.x + cos(angle) * dist
			var mz: float = tree_pos.z + sin(angle) * dist
			var my: float = _get_ground_y(mx, mz)
			shroom.position = Vector3(mx, my, mz)
			var s: float = rng.randf_range(0.7, 1.3)
			shroom.scale = Vector3(s, s, s)
			shroom.rotation.y = rng.randf_range(0.0, TAU)
			add_child(shroom)

func _spawn_rocks() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99

	for i in range(rock_count):
		var x: float = rng.randf_range(-70.0, 70.0)
		var z: float = rng.randf_range(-70.0, 70.0)

		var dist_river: float = RiverClass.get_distance_to_river(x, z)
		if dist_river < 3.5 or CityHub.in_village(x, z):
			continue

		var ground_y: float = _get_ground_y(x, z)
		var scene: PackedScene = ROCK_SCENES[rng.randi() % ROCK_SCENES.size()]
		var rock_node: Node3D = scene.instantiate()
		var s: float = rng.randf_range(0.75, 1.6)
		rock_node.position = Vector3(x, ground_y, z)
		rock_node.scale = Vector3(s, s, s)
		rock_node.rotation.y = rng.randf_range(0.0, TAU)

		# Colisão da rocha
		var static_body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.8 * s
		col.shape = sphere
		col.position.y = 0.4 * s
		static_body.add_child(col)
		rock_node.add_child(static_body)

		add_child(rock_node)
