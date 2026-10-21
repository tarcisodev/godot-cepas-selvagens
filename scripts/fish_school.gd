extends Node3D
class_name FishSchool

## Cardumes de Peixes de Água Doce
# Nadam graciosamente na lagoa da cachoeira e pelo rio inferior,
# navegando entre as algas e evitando a queda d'água.

const RiverClass = preload("res://scripts/river_system.gd")

@export var fish_count: int = 18
@export var min_z: float = -24.0 # Começa logo na lagoa abaixo da cachoeira
@export var max_z: float = 65.0

class FishData:
	var node: Node3D
	var tail: MeshInstance3D
	var offset_x: float
	var z: float
	var speed: float
	var swim_phase: float
	var depth_offset: float
	var current_yaw: float

var fishes: Array[FishData] = []

func _ready() -> void:
	_create_fishes()

func _create_fishes() -> void:
	var fish_mat: StandardMaterial3D = StandardMaterial3D.new()
	fish_mat.albedo_color = Color(0.80, 0.90, 0.88)
	fish_mat.metallic = 0.45
	fish_mat.roughness = 0.25

	var fin_mat: StandardMaterial3D = StandardMaterial3D.new()
	fin_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	fin_mat.albedo_color = Color(0.88, 0.95, 0.95, 0.65)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 777

	for i in range(fish_count):
		var data: FishData = FishData.new()
		data.z = rng.randf_range(min_z, max_z)
		data.speed = rng.randf_range(1.0, 2.2)
		data.swim_phase = rng.randf_range(0.0, TAU)
		data.depth_offset = rng.randf_range(0.4, 1.2)
		data.current_yaw = 0.0

		var hw: float = RiverClass.get_water_half_width(data.z)
		data.offset_x = rng.randf_range(-hw * 0.55, hw * 0.55)

		var fish_node: Node3D = Node3D.new()
		fish_node.name = "Fish_%d" % i

		# Corpo estilizado
		var body_mesh: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.08
		sphere.height = 0.38
		body_mesh.mesh = sphere
		body_mesh.material_override = fish_mat
		body_mesh.rotation.x = deg_to_rad(90.0)
		fish_node.add_child(body_mesh)

		# Cauda
		var tail_mesh: MeshInstance3D = MeshInstance3D.new()
		var prism: PrismMesh = PrismMesh.new()
		prism.size = Vector3(0.02, 0.15, 0.13)
		tail_mesh.mesh = prism
		tail_mesh.material_override = fin_mat
		tail_mesh.position = Vector3(0, 0, 0.22)
		fish_node.add_child(tail_mesh)

		data.node = fish_node
		data.tail = tail_mesh

		add_child(fish_node)
		fishes.append(data)

func _process(delta: float) -> void:
	for data in fishes:
		# Avança suavemente rio abaixo
		data.z += data.speed * delta
		if data.z > max_z:
			data.z = min_z

		data.swim_phase += delta * (data.speed * 4.0)

		# Respeita a largura e profundidade d'água em cada ponto do rio
		var water_y: float = RiverClass.get_water_height(data.z)
		var hw: float = RiverClass.get_water_half_width(data.z)
		var center_x: float = RiverClass.get_river_center_x(data.z)

		var target_x: float = center_x + clamp(data.offset_x, -hw * 0.6, hw * 0.6)
		var target_y: float = water_y - data.depth_offset

		data.node.position = Vector3(target_x, target_y, data.z)

		# Rotação suave ao longo do curso do rio
		var next_center_x: float = RiverClass.get_river_center_x(data.z + 1.0)
		var target_yaw: float = atan2(next_center_x - center_x, 1.0)
		data.current_yaw = lerp_angle(data.current_yaw, target_yaw, 5.0 * delta)

		var waggle: float = sin(data.swim_phase) * 0.22
		data.node.rotation.y = data.current_yaw + waggle * 0.35
		data.tail.rotation.y = waggle * 0.75
