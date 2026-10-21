extends Node3D
class_name GrassAndFlowers

## Gramado Vivo e Flores Silvestres
# Renderiza milhares de tufos de grama e flores coloridas usando MultiMeshInstance3D
# para altíssima performance e beleza cênica.

const RiverClass = preload("res://scripts/river_system.gd")

@export var landscape: MeshInstance3D
@export var grass_count: int = 1200
@export var flower_count: int = 240
@export var spawn_radius: float = 65.0

func _ready() -> void:
	if landscape == null:
		landscape = get_parent().get_node_or_null("Landscape")

	_create_grass_multimesh()
	_create_flowers_multimesh()

func _get_ground_y(x: float, z: float) -> float:
	if landscape and landscape.has_method("get_height_at"):
		return landscape.get_height_at(x, z)
	return 0.0

func _create_grass_multimesh() -> void:
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.name = "GrassMultiMesh"

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = grass_count

	# Malha simples de tufo de grama (2 planos cruzados em X)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h: float = 0.45
	var w: float = 0.28

	# Folha 1
	st.add_vertex(Vector3(-w, 0, 0))
	st.add_vertex(Vector3(w, 0, 0))
	st.add_vertex(Vector3(0, h, 0))

	# Folha 2 (cruzada)
	st.add_vertex(Vector3(0, 0, -w))
	st.add_vertex(Vector3(0, 0, w))
	st.add_vertex(Vector3(0, h, 0))

	st.generate_normals()
	mm.mesh = st.commit()

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	mmi.material_override = mat

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 333

	var placed: int = 0
	for i in range(grass_count):
		var x: float = rng.randf_range(-spawn_radius, spawn_radius)
		var z: float = rng.randf_range(-spawn_radius, spawn_radius)

		# Evita dentro d'água funda ou no topo pelado da montanha
		var dist_river: float = RiverClass.get_distance_to_river(x, z)
		var water_hw: float = RiverClass.get_water_half_width(z)
		if dist_river < (water_hw * 0.95):
			# Não nasce no leito submerso
			mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -999, 0)))
			continue

		var y: float = _get_ground_y(x, z)
		if y > 14.0: # Topo rochoso
			mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -999, 0)))
			continue

		var rot_y: float = rng.randf_range(0.0, TAU)
		var scale_val: float = rng.randf_range(0.8, 1.35)
		if dist_river < (water_hw * 1.8):
			scale_val *= 1.3 # Grama mais alta e farta perto da água

		var t: Transform3D = Transform3D()
		t = t.scaled(Vector3(scale_val, scale_val, scale_val))
		t = t.rotated(Vector3.UP, rot_y)
		t.origin = Vector3(x, y, z)

		# Cor: mais esmeralda perto da água, mais dourada nas colinas
		var grass_col: Color = Color(0.28, 0.48, 0.22)
		if dist_river < (water_hw * 2.0):
			grass_col = Color(0.20, 0.54, 0.24)
		else:
			grass_col = Color(0.35, 0.46, 0.24).lerp(Color(0.52, 0.46, 0.26), rng.randf_range(0.0, 0.4))

		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, grass_col)
		placed += 1

	mmi.multimesh = mm
	add_child(mmi)

func _create_flowers_multimesh() -> void:
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.name = "FlowersMultiMesh"

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = flower_count

	# Pequena corola / pétala estilizada
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.08
	mm.mesh = sphere

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.7
	mmi.material_override = mat

	var flower_palette: Array[Color] = [
		Color(0.98, 0.95, 0.88), # Margarida branca
		Color(0.98, 0.82, 0.25), # Dente-de-leão / flor dourada
		Color(0.72, 0.38, 0.78), # Lavanda / orquídea da serra
		Color(0.92, 0.42, 0.35), # Flor de fogo silvestre
		Color(0.45, 0.70, 0.95)  # Miosótis azul da beira d'água
	]

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 444

	for i in range(flower_count):
		var x: float = rng.randf_range(-spawn_radius * 0.85, spawn_radius * 0.85)
		var z: float = rng.randf_range(-spawn_radius * 0.85, spawn_radius * 0.85)

		var dist_river: float = RiverClass.get_distance_to_river(x, z)
		var water_hw: float = RiverClass.get_water_half_width(z)
		if dist_river < (water_hw * 0.95):
			mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -999, 0)))
			continue

		var y: float = _get_ground_y(x, z)
		if y > 13.0:
			mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -999, 0)))
			continue

		var t: Transform3D = Transform3D()
		var s: float = rng.randf_range(0.8, 1.4)
		t = t.scaled(Vector3(s, s, s))
		t.origin = Vector3(x, y + 0.28 * s, z)

		# Miosótis azul perto da água, outras cores nas colinas
		var chosen_color: Color
		if dist_river < (water_hw * 1.8) and rng.randf() > 0.4:
			chosen_color = flower_palette[4] # Azul da água
		else:
			chosen_color = flower_palette[rng.randi_range(0, 3)]

		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, chosen_color)

	mmi.multimesh = mm
	add_child(mmi)
