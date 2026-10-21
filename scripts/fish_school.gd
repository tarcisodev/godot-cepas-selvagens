extends Node3D
class_name FishSchool

## Cardumes de Peixes de Água Doce
# Nadam graciosamente na lagoa da cachoeira e pelo rio inferior,
# navegando entre as algas e evitando a queda d'água.

const RiverClass = preload("res://scripts/river_system.gd")

@export var fish_count: int = 18
@export var min_z: float = -24.0 # Começa logo na lagoa abaixo da cachoeira
@export var max_z: float = 65.0

const FISH_SHADER: Shader = preload("res://materials/fish_swim.gdshader")

const BODY_COLOR := Color(0.80, 0.90, 0.88)
const FIN_COLOR := Color(0.70, 0.84, 0.86)

class FishData:
	var node: MeshInstance3D
	var offset_x: float
	var z: float
	var speed: float
	var depth_offset: float
	var current_yaw: float

var fishes: Array[FishData] = []

func _ready() -> void:
	_create_fishes()

func _create_fishes() -> void:
	# Natação feita no vertex shader (fish_swim.gdshader); o script só move e orienta.
	var fish_mat: ShaderMaterial = ShaderMaterial.new()
	fish_mat.shader = FISH_SHADER
	fish_mat.set_shader_parameter("metallic", 0.45)
	fish_mat.set_shader_parameter("roughness", 0.25)

	var fish_mesh: ArrayMesh = _build_fish_mesh()

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 777

	for i in range(fish_count):
		var data: FishData = FishData.new()
		data.z = rng.randf_range(min_z, max_z)
		data.speed = rng.randf_range(1.0, 2.2)
		data.depth_offset = rng.randf_range(0.4, 1.2)
		data.current_yaw = 0.0

		var hw: float = RiverClass.get_water_half_width(data.z)
		data.offset_x = rng.randf_range(-hw * 0.55, hw * 0.55)

		var fish_node: MeshInstance3D = MeshInstance3D.new()
		fish_node.name = "Fish_%d" % i
		fish_node.mesh = fish_mesh
		fish_node.material_override = fish_mat
		fish_node.set_instance_shader_parameter("swim_phase", rng.randf_range(0.0, TAU))
		fish_node.set_instance_shader_parameter("swim_speed", data.speed * 0.8)

		data.node = fish_node
		add_child(fish_node)
		fishes.append(data)

## Corpo + cauda numa única malha com o eixo do corpo em Z (cabeça em +Z),
## que é o que o shader espera para mascarar a deformação da cabeça à cauda.
func _build_fish_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.38
	_append_primitive(st, sphere, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90.0)), Vector3.ZERO), BODY_COLOR)

	var prism: PrismMesh = PrismMesh.new()
	prism.size = Vector3(0.02, 0.15, 0.13)
	_append_primitive(st, prism, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.22)), FIN_COLOR)

	return st.commit()

func _append_primitive(st: SurfaceTool, mesh: PrimitiveMesh, xform: Transform3D, color: Color) -> void:
	var arrays: Array = mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for idx in indices:
		st.set_color(color)
		st.set_normal((xform.basis * normals[idx]).normalized())
		st.add_vertex(xform * verts[idx])

func _process(delta: float) -> void:
	for data in fishes:
		# Avança suavemente rio abaixo
		data.z += data.speed * delta
		if data.z > max_z:
			data.z = min_z

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
		data.node.rotation.y = data.current_yaw
