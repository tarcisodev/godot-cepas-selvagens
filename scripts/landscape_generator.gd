@tool
extends MeshInstance3D
class_name LandscapeGenerator

## Relevo com Pico Majestoso, Penhasco, Cachoeira e Vale
# Gera o relevo com montanha imponente, escarpa rochosa onde a água despenca,
# bacia da lagoa e rio sinuoso pelo vale.

const RiverClass = preload("res://scripts/river_system.gd")
const RIVER_SHADER: Shader = preload("res://materials/river_water.gdshader")
const WATERFALL_SHADER: Shader = preload("res://materials/waterfall.gdshader")

@export var terrain_size: Vector2 = Vector2(180.0, 180.0)
@export var subdivisions: Vector2i = Vector2i(120, 120)
@export var max_height: float = 7.5
@export var noise_frequency: float = 0.016

# Cores do bioma e relevo
@export var peak_rock_color: Color = Color(0.34, 0.33, 0.32)    # Rocha nua do pico
@export var cliff_rock_color: Color = Color(0.26, 0.26, 0.28)   # Paredão da cachoeira
@export var lush_bank_color: Color = Color(0.27, 0.44, 0.22)    # Margens úmidas da mata ciliar
@export var grass_color: Color = Color(0.32, 0.46, 0.28)        # Verde musgo natural
@export var earth_color: Color = Color(0.48, 0.38, 0.28)        # Terra avermelhada nos cumes secos
@export var riverbed_color: Color = Color(0.22, 0.21, 0.18)     # Seixos e cascalho do fundo

var noise: FastNoiseLite

func _ready() -> void:
	_init_noise()
	generate_landscape()

func _init_noise() -> void:
	if noise == null:
		noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = noise_frequency
		noise.fractal_octaves = 4
		noise.fractal_gain = 0.45

## Função pública para consultar a altura exata da superfície do terreno
func get_height_at(x: float, z: float) -> float:
	_init_noise()
	var half_size: Vector2 = terrain_size * 0.5
	if abs(x) > half_size.x or abs(z) > half_size.y:
		return 0.0

	# 1. Base procedural suave
	var dist_from_center: float = Vector2(x, z).length()
	var center_clearing_factor: float = clamp((dist_from_center - 6.0) / 22.0, 0.0, 1.0)
	var h: float = noise.get_noise_2d(x, z) * max_height * center_clearing_factor

	# 2. O Grande Pico (Noroeste: X ~ -28, Z ~ -52)
	var dist_to_peak: float = Vector2(x - (-28.0), z - (-52.0)).length()
	if dist_to_peak < 38.0:
		var peak_factor: float = clamp(1.0 - (dist_to_peak / 38.0), 0.0, 1.0)
		# Curva íngreme de cúpula montanhosa
		h += pow(peak_factor, 1.8) * 17.5

	# 3. Platô Norte e Penhasco da Cachoeira (Z < -28)
	var waterfall_z: float = RiverClass.WATERFALL_Z
	if z < waterfall_z:
		var plateau_factor: float = clamp((waterfall_z - z) / 8.0, 0.0, 1.0)
		h += plateau_factor * 8.2

	# 4. Leito do Rio e Cachoeira
	var river_center_x: float = RiverClass.get_river_center_x(z)
	var dist_river: float = abs(x - river_center_x)
	var water_half_w: float = RiverClass.get_water_half_width(z)
	var in_river_t: float = dist_river / (water_half_w * 1.35)

	if in_river_t < 1.0:
		var carve_factor: float = 0.5 * (1.0 + cos(in_river_t * PI))
		var bed_target_y: float = RiverClass.LOWER_BED_Y
		if z < (waterfall_z - 3.0):
			bed_target_y = RiverClass.UPPER_BED_Y
		elif z <= (waterfall_z + 8.0):
			# Bacia profunda da cachoeira onde a água cai
			bed_target_y = -3.2

		h = lerp(h, bed_target_y, carve_factor)

	return h

func generate_landscape() -> void:
	_init_noise()

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_size: Vector2 = terrain_size * 0.5
	var step_x: float = terrain_size.x / float(subdivisions.x)
	var step_z: float = terrain_size.y / float(subdivisions.y)

	for z_idx in range(subdivisions.y):
		for x_idx in range(subdivisions.x):
			var x0: float = -half_size.x + x_idx * step_x
			var x1: float = x0 + step_x
			var z0: float = -half_size.y + z_idx * step_z
			var z1: float = z0 + step_z

			var y00: float = get_height_at(x0, z0)
			var y10: float = get_height_at(x1, z0)
			var y01: float = get_height_at(x0, z1)
			var y11: float = get_height_at(x1, z1)

			var v00: Vector3 = Vector3(x0, y00, z0)
			var v10: Vector3 = Vector3(x1, y10, z0)
			var v01: Vector3 = Vector3(x0, y01, z1)
			var v11: Vector3 = Vector3(x1, y11, z1)

			# Triângulo 1 (v00, v10, v01)
			_add_vertex_colored(st, v00)
			_add_vertex_colored(st, v10)
			_add_vertex_colored(st, v01)

			# Triângulo 2 (v10, v11, v01)
			_add_vertex_colored(st, v10)
			_add_vertex_colored(st, v11)
			_add_vertex_colored(st, v01)

	st.generate_normals()
	mesh = st.commit()

	# Configurar material natural
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true # as cores exportadas são sRGB; sem isso o verde sai lavado
	mat.roughness = 0.95
	mat.metallic_specular = 0.1
	material_override = mat

	_rebuild_collision()
	_build_river_and_waterfall()

func _add_vertex_colored(st: SurfaceTool, pos: Vector3) -> void:
	var col: Color = grass_color
	var dist_river: float = RiverClass.get_distance_to_river(pos.x, pos.z)
	var water_hw: float = RiverClass.get_water_half_width(pos.z)
	var water_y: float = RiverClass.get_water_height(pos.z)

	if pos.y > 11.0:
		# Rocha exposta do Pico Majestoso
		var t_rock: float = clamp((pos.y - 11.0) / 8.0, 0.0, 1.0)
		col = grass_color.lerp(peak_rock_color, t_rock)
	elif pos.z >= (RiverClass.WATERFALL_Z - 2.5) and pos.z <= (RiverClass.WATERFALL_Z + 3.0) and pos.y > 1.0:
		# Escarpa do penhasco da cachoeira
		col = cliff_rock_color
	elif dist_river < (water_hw * 0.9) and pos.y < (water_y + 0.1):
		# Fundo do leito submerso
		col = riverbed_color
	elif dist_river <= (water_hw * 1.6):
		# Margem fértil e úmida da mata ciliar
		col = lush_bank_color
	else:
		# Colinas e relevo geral
		var t_hill: float = clamp(pos.y / (max_height * 0.9), 0.0, 1.0)
		col = grass_color.lerp(earth_color, t_hill)

	st.set_color(col)
	st.set_uv(Vector2(pos.x * 0.1, pos.z * 0.1))
	st.add_vertex(pos)

func _rebuild_collision() -> void:
	for child in get_children():
		if child is StaticBody3D:
			child.queue_free()

	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.name = "TerrainCollision"
	static_body.collision_layer = 1
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	col_shape.shape = mesh.create_trimesh_shape()
	static_body.add_child(col_shape)

	# 1. Paredes invisíveis nos 4 limites do mapa para evitar queda no abismo/limbo
	var half_x: float = terrain_size.x * 0.5
	var half_z: float = terrain_size.y * 0.5
	var wall_height: float = 60.0
	var wall_thickness: float = 6.0
	var wall_y: float = 15.0

	# Norte (Z-) e Sul (Z+)
	_add_wall_shape(static_body, Vector3(0.0, wall_y, -half_z - wall_thickness * 0.5), Vector3(terrain_size.x + wall_thickness * 2.0, wall_height, wall_thickness))
	_add_wall_shape(static_body, Vector3(0.0, wall_y, half_z + wall_thickness * 0.5), Vector3(terrain_size.x + wall_thickness * 2.0, wall_height, wall_thickness))
	# Oeste (X-) e Leste (X+)
	_add_wall_shape(static_body, Vector3(-half_x - wall_thickness * 0.5, wall_y, 0.0), Vector3(wall_thickness, wall_height, terrain_size.y + wall_thickness * 2.0))
	_add_wall_shape(static_body, Vector3(half_x + wall_thickness * 0.5, wall_y, 0.0), Vector3(wall_thickness, wall_height, terrain_size.y + wall_thickness * 2.0))

	# 2. Piso de segurança inferior (rede que intercepta qualquer um que atravesse a malha)
	_add_wall_shape(static_body, Vector3(0.0, -10.0, 0.0), Vector3(terrain_size.x * 1.5, 2.0, terrain_size.y * 1.5))

	add_child(static_body)

func _add_wall_shape(parent: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	shape_node.position = center
	parent.add_child(shape_node)

func _build_river_and_waterfall() -> void:
	# Remover água antiga se houver
	for child in get_children():
		if child.name == "RiverWater" or child.name == "Waterfall":
			child.queue_free()

	# 1. Rio Horizontal (Superior, Lagoa e Inferior)
	var water_mesh_instance: MeshInstance3D = MeshInstance3D.new()
	water_mesh_instance.name = "RiverWater"

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_z: float = terrain_size.y * 0.5
	var segments_z: int = 140
	var step_z: float = terrain_size.y / float(segments_z)

	for i in range(segments_z):
		var z0: float = -half_z + i * step_z
		var z1: float = z0 + step_z

		# Pula a abertura exata da queda vertical (ela será a malha da cachoeira)
		if z0 >= (RiverClass.WATERFALL_Z - 1.0) and z1 <= (RiverClass.WATERFALL_Z + 1.0):
			continue

		var cx0: float = RiverClass.get_river_center_x(z0)
		var cx1: float = RiverClass.get_river_center_x(z1)
		var hw0: float = RiverClass.get_water_half_width(z0)
		var hw1: float = RiverClass.get_water_half_width(z1)
		var y0: float = RiverClass.get_water_height(z0)
		var y1: float = RiverClass.get_water_height(z1)

		var l0: Vector3 = Vector3(cx0 - hw0, y0, z0)
		var r0: Vector3 = Vector3(cx0 + hw0, y0, z0)
		var l1: Vector3 = Vector3(cx1 - hw1, y1, z1)
		var r1: Vector3 = Vector3(cx1 + hw1, y1, z1)

		st.set_uv(Vector2(0.0, float(i)))
		st.add_vertex(l0)
		st.set_uv(Vector2(1.0, float(i)))
		st.add_vertex(r0)
		st.set_uv(Vector2(0.0, float(i + 1)))
		st.add_vertex(l1)

		st.set_uv(Vector2(1.0, float(i)))
		st.add_vertex(r0)
		st.set_uv(Vector2(1.0, float(i + 1)))
		st.add_vertex(r1)
		st.set_uv(Vector2(0.0, float(i + 1)))
		st.add_vertex(l1)

	st.generate_normals()
	water_mesh_instance.mesh = st.commit()

	var water_mat := ShaderMaterial.new()
	water_mat.shader = RIVER_SHADER
	water_mesh_instance.material_override = water_mat
	water_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water_mesh_instance)

	# 2. Cortina Vertical da Cachoeira
	var waterfall_instance: MeshInstance3D = MeshInstance3D.new()
	waterfall_instance.name = "Waterfall"

	var st_wf: SurfaceTool = SurfaceTool.new()
	st_wf.begin(Mesh.PRIMITIVE_TRIANGLES)

	var wf_z: float = RiverClass.WATERFALL_Z
	var wf_x: float = RiverClass.get_river_center_x(wf_z)
	var wf_w: float = 4.8 # Largura da queda
	var top_y: float = RiverClass.UPPER_WATER_Y
	var bot_y: float = RiverClass.LOWER_WATER_Y

	# Lâmina d'água caindo com leve curva
	var wf_v0: Vector3 = Vector3(wf_x - wf_w * 0.5, top_y, wf_z - 0.8)
	var wf_v1: Vector3 = Vector3(wf_x + wf_w * 0.5, top_y, wf_z - 0.8)
	var wf_v2: Vector3 = Vector3(wf_x - wf_w * 0.6, bot_y, wf_z + 1.6)
	var wf_v3: Vector3 = Vector3(wf_x + wf_w * 0.6, bot_y, wf_z + 1.6)

	st_wf.set_uv(Vector2(0, 0))
	st_wf.add_vertex(wf_v0)
	st_wf.set_uv(Vector2(1, 0))
	st_wf.add_vertex(wf_v1)
	st_wf.set_uv(Vector2(0, 1))
	st_wf.add_vertex(wf_v2)

	st_wf.set_uv(Vector2(1, 0))
	st_wf.add_vertex(wf_v1)
	st_wf.set_uv(Vector2(1, 1))
	st_wf.add_vertex(wf_v3)
	st_wf.set_uv(Vector2(0, 1))
	st_wf.add_vertex(wf_v2)

	st_wf.generate_normals()
	waterfall_instance.mesh = st_wf.commit()

	# Material de espuma e queda espumante
	var wf_mat := ShaderMaterial.new()
	wf_mat.shader = WATERFALL_SHADER
	waterfall_instance.material_override = wf_mat
	waterfall_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Luz suave no spray da cachoeira
	var mist_light: OmniLight3D = OmniLight3D.new()
	mist_light.light_color = Color(0.65, 0.85, 1.0)
	mist_light.light_energy = 0.8
	mist_light.omni_range = 10.0
	mist_light.position = Vector3(wf_x, bot_y + 1.2, wf_z + 1.2)
	waterfall_instance.add_child(mist_light)

	add_child(waterfall_instance)
