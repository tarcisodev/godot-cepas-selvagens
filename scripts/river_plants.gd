extends Node3D
class_name RiverPlants

## Algas Aquáticas e Vegetação Fluvial Submersa
# Fitas verdes esmeralda que brotam no leito do rio e na lagoa da cachoeira,
# balançando suavemente com a correnteza d'água.

const RiverClass = preload("res://scripts/river_system.gd")

@export var cluster_count: int = 28
@export var river_span_z: float = 70.0

class AlgaeLeaf:
	var mesh: MeshInstance3D
	var base_rot_z: float
	var sway_speed: float
	var sway_phase: float

var leaves: Array[AlgaeLeaf] = []

func _ready() -> void:
	_spawn_algae()

func _spawn_algae() -> void:
	var algae_mat: StandardMaterial3D = StandardMaterial3D.new()
	algae_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	algae_mat.albedo_color = Color(0.14, 0.55, 0.32, 0.88) # Verde esmeralda vivo
	algae_mat.roughness = 0.4
	algae_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 888

	for i in range(cluster_count):
		var z: float = rng.randf_range(-RiverClass.WATERFALL_Z - 10.0, river_span_z * 0.5)
		# Se estiver exatamente na queda da cachoeira, pula
		if z >= (RiverClass.WATERFALL_Z - 2.0) and z <= (RiverClass.WATERFALL_Z + 3.0):
			continue

		var cx: float = RiverClass.get_river_center_x(z)
		var hw: float = RiverClass.get_water_half_width(z)
		var offset_x: float = rng.randf_range(-hw * 0.65, hw * 0.65)
		var cluster_x: float = cx + offset_x

		var water_y: float = RiverClass.get_water_height(z)
		var bed_y: float = RiverClass.LOWER_BED_Y
		if z < RiverClass.WATERFALL_Z:
			bed_y = RiverClass.UPPER_BED_Y
		elif z <= (RiverClass.WATERFALL_Z + 12.0):
			bed_y = -3.0 # Fundo da lagoa da cachoeira

		var cluster_root: Node3D = Node3D.new()
		cluster_root.name = "AlgaeCluster_%d" % i
		cluster_root.position = Vector3(cluster_x, bed_y + 0.1, z)

		# Brota de 4 a 7 fitas de alga por tufo
		var leaf_count: int = rng.randi_range(4, 7)
		for j in range(leaf_count):
			var leaf_mesh: MeshInstance3D = MeshInstance3D.new()
			var plane: PlaneMesh = PlaneMesh.new()
			var leaf_h: float = rng.randf_range(0.8, 1.4)
			plane.size = Vector2(0.12, leaf_h)
			plane.subdivide_depth = 2
			leaf_mesh.mesh = plane
			leaf_mesh.material_override = algae_mat

			# Posição ligeiramente deslocada do centro do tufo
			var a: float = rng.randf_range(0.0, TAU)
			var r: float = rng.randf_range(0.05, 0.25)
			leaf_mesh.position = Vector3(cos(a) * r, leaf_h * 0.5, sin(a) * r)
			leaf_mesh.rotation = Vector3(deg_to_rad(90.0), rng.randf_range(0.0, TAU), 0.0)

			cluster_root.add_child(leaf_mesh)

			var leaf_data: AlgaeLeaf = AlgaeLeaf.new()
			leaf_data.mesh = leaf_mesh
			leaf_data.base_rot_z = leaf_mesh.rotation.z
			leaf_data.sway_speed = rng.randf_range(1.6, 2.6)
			leaf_data.sway_phase = rng.randf_range(0.0, TAU)
			leaves.append(leaf_data)

		add_child(cluster_root)

func _process(delta: float) -> void:
	for leaf in leaves:
		leaf.sway_phase += delta * leaf.sway_speed
		# Ondulação graciosa na água
		var sway: float = sin(leaf.sway_phase) * 0.22
		leaf.mesh.rotation.x = deg_to_rad(90.0) + sway
