extends Node3D
class_name GrassAndFlowers

## Gramado Vivo e Flores Silvestres
# Espalha tufos de grama, trevos e flores do Stylized Nature Kit com MultiMeshInstance3D
# (uma MultiMesh por variante) para altíssima performance e beleza cênica.

const RiverClass = preload("res://scripts/river_system.gd")

const GRASS_SCENES: Array[PackedScene] = [
	preload("res://assets/models/nature/Grass_Common_Short.gltf"),
	preload("res://assets/models/nature/Grass_Wispy_Short.gltf"),
	preload("res://assets/models/nature/Grass_Common_Tall.gltf"),
	preload("res://assets/models/nature/Grass_Wispy_Tall.gltf"),
]
const FLOWER_SCENES: Array[PackedScene] = [
	preload("res://assets/models/nature/Flower_3_Group.gltf"),
	preload("res://assets/models/nature/Flower_4_Group.gltf"),
	preload("res://assets/models/nature/Clover_1.gltf"),
	preload("res://assets/models/nature/Clover_2.gltf"),
]

@export var landscape: MeshInstance3D
@export var grass_count: int = 11000
@export var flower_count: int = 900
@export var spawn_radius: float = WorldBounds.HALF * 0.85
## Os modelos do kit têm ~1,3 m de altura; a escala os traz para tufos de 40–60 cm.
@export var grass_scale: Vector2 = Vector2(0.32, 0.5)
@export var flower_scale: Vector2 = Vector2(0.22, 0.34)

func _ready() -> void:
	if landscape == null:
		landscape = get_parent().get_node_or_null("Landscape")

	_scatter("GrassMultiMesh", GRASS_SCENES, grass_count, grass_scale, 333, 14.0, 0.95)
	_scatter("FlowersMultiMesh", FLOWER_SCENES, flower_count, flower_scale, 444, 13.0, 0.95)

func _get_ground_y(x: float, z: float) -> float:
	if landscape and landscape.has_method("get_height_at"):
		return landscape.get_height_at(x, z)
	return 0.0

## Distribui `count` instâncias entre as variantes, fora do leito do rio e do topo rochoso.
func _scatter(group_name: String, scenes: Array[PackedScene], count: int, scale_range: Vector2, seed_value: int, max_y: float, river_margin: float) -> void:
	var group := Node3D.new()
	group.name = group_name
	add_child(group)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	# Sorteia todas as posições primeiro e reparte por variante
	var per_variant: Array = []
	for i in scenes.size():
		per_variant.append([])

	for i in count:
		var x: float = rng.randf_range(-spawn_radius, spawn_radius)
		var z: float = rng.randf_range(-spawn_radius, spawn_radius)

		# Não nasce no leito submerso
		var dist_river: float = RiverClass.get_distance_to_river(x, z)
		var water_hw: float = RiverClass.get_water_half_width(z)
		if dist_river < (water_hw * river_margin):
			continue

		var y: float = _get_ground_y(x, z)
		if y > max_y: # Topo rochoso
			continue

		var s: float = rng.randf_range(scale_range.x, scale_range.y)
		if dist_river < (water_hw * 1.8):
			s *= 1.25 # Mais alta e farta perto da água

		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * s)
		per_variant[rng.randi() % scenes.size()].append(Transform3D(basis, Vector3(x, y - 0.03, z)))

	for v in scenes.size():
		var mesh := _mesh_from_scene(scenes[v])
		var transforms: Array = per_variant[v]
		if mesh == null or transforms.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, transforms[i])

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d" % [group_name, v]
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(mmi)

## Pega a malha (com materiais) do primeiro MeshInstance3D de uma cena importada.
func _mesh_from_scene(scene: PackedScene) -> Mesh:
	var inst := scene.instantiate()
	var mesh: Mesh = null
	var found := inst.find_children("*", "MeshInstance3D", true, false)
	if inst is MeshInstance3D:
		mesh = (inst as MeshInstance3D).mesh
	elif not found.is_empty():
		mesh = (found[0] as MeshInstance3D).mesh
	inst.free()
	return mesh
